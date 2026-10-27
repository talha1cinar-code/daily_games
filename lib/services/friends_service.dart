import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import '../utils/app_links.dart';
import '../utils/app_messenger.dart';
import 'achievement_service.dart';
import 'app_strings.dart';
import 'language_service.dart';
import 'leaderboard_service.dart';
import 'social_watcher.dart';

/// Arkadaş listesi. Arkadaşlar sıralamadaki kimlikleriyle (UUID) tutulur; böylece
/// mevcut sıralama kayıtlarından skorları okunur.
///
/// Firestore:
///   - `friend_codes/{KOD}`: 6 karakterlik paylaşılabilir kod → userId
///   - `friend_requests/{alıcı_gönderen}`: biri seni eklediğinde yazılır; uygulaman
///     onu görünce seni de otomatik ekler (arkadaşlık iki yönlü olur) ve kaydı siler.
class FriendsService extends ChangeNotifier {
  static final FriendsService _instance = FriendsService._internal();
  factory FriendsService() => _instance;
  FriendsService._internal();

  static const String _key = 'friend_ids';
  static const String _namesKey = 'friend_names';
  static const String _codeKey = 'friend_short_code';
  static const String _codeRegisteredKey = 'friend_short_code_ok';
  static const int maxFriends = 29; // kendimizle birlikte tek whereIn sorgusu
  static const int codeLength = 6;

  /// Karışan karakterler (0/O, 1/I/L) yok
  static const String _alphabet = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
  static final RegExp _uuid = RegExp(
    r'[0-9a-f]{8}-?[0-9a-f]{4}-?[0-9a-f]{4}-?[0-9a-f]{4}-?[0-9a-f]{12}',
    caseSensitive: false,
  );
  static final RegExp _short = RegExp('^[$_alphabet]{$codeLength}\$');

  SharedPreferences? _prefs;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sub;

  FirebaseFirestore get _db => FirebaseFirestore.instance;
  String get _me => LeaderboardService().userId;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    if (_prefs!.getString(_codeKey) == null) {
      await _prefs!.setString(_codeKey, _randomCode());
    }
    _registerCode();
    _listenRequests();
  }

  List<String> get friendIds => _prefs?.getStringList(_key) ?? [];

  /// Paylaşılan kısa kod (ör. K7M2QX)
  String get myCode => _prefs?.getString(_codeKey) ?? '';

  String _randomCode() {
    final rng = Random.secure();
    return List.generate(codeLength, (_) => _alphabet[rng.nextInt(_alphabet.length)]).join();
  }

  /// Kodu Firestore'a kaydeder; başkasında varsa yeni kod üretir
  Future<void> _registerCode() async {
    if (_prefs?.getBool(_codeRegisteredKey) ?? false) return;
    for (var attempt = 0; attempt < 5; attempt++) {
      final code = myCode;
      try {
        final ref = _db.collection('friend_codes').doc(code);
        final taken = await _db.runTransaction<bool>((tx) async {
          final snap = await tx.get(ref);
          if (snap.exists) return snap.data()?['userId'] != _me;
          tx.set(ref, {'userId': _me, 'createdAt': FieldValue.serverTimestamp()});
          return false;
        });
        if (!taken) {
          await _prefs?.setBool(_codeRegisteredKey, true);
          notifyListeners();
          return;
        }
        await _prefs?.setString(_codeKey, _randomCode());
      } catch (e) {
        debugPrint('FriendsService code register error: $e');
        return; // çevrimdışı: bir sonraki açılışta tekrar denenir
      }
    }
  }

  /// Daha önce sıralamada görülen arkadaş adları (bugün oynamamışlar için)
  String? nameOf(String id) {
    final list = _prefs?.getStringList(_namesKey) ?? [];
    for (final e in list) {
      final i = e.indexOf('|');
      if (i > 0 && e.substring(0, i) == id) return e.substring(i + 1);
    }
    return null;
  }

  void _rememberName(String id, String name) {
    final list = (_prefs?.getStringList(_namesKey) ?? []).where((e) => !e.startsWith('$id|')).toList();
    _prefs?.setStringList(_namesKey, [...list, '$id|$name']);
  }

  void rememberNames(Iterable<LeaderboardEntry> entries) {
    final map = {
      for (final e in _prefs?.getStringList(_namesKey) ?? <String>[])
        if (e.contains('|')) e.substring(0, e.indexOf('|')): e.substring(e.indexOf('|') + 1),
    };
    for (final e in entries) {
      if (friendIds.contains(e.userId)) map[e.userId] = e.displayName;
    }
    _prefs?.setStringList(_namesKey, [for (final m in map.entries) '${m.key}|${m.value}']);
  }

  /// Girilen koddan arkadaş ekler: 6 karakterlik kısa kod ya da eski uzun kod.
  Future<AddFriendResult> addFromText(String text) async {
    final input = text.trim().toUpperCase().replaceAll(RegExp(r'[\s-]'), '');
    String? id;
    final shortMatch = RegExp('[$_alphabet]{$codeLength}').firstMatch(input);
    final uuidMatch = _uuid.firstMatch(text);
    if (uuidMatch != null) {
      final hex = uuidMatch.group(0)!.replaceAll('-', '').toLowerCase();
      id = '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-'
          '${hex.substring(16, 20)}-${hex.substring(20)}';
    } else if (shortMatch != null && _short.hasMatch(shortMatch.group(0)!)) {
      final code = shortMatch.group(0)!;
      if (code == myCode) return AddFriendResult.self;
      try {
        final doc = await _db.collection('friend_codes').doc(code).get();
        id = doc.data()?['userId'] as String?;
      } catch (_) {
        return AddFriendResult.offline;
      }
      if (id == null) return AddFriendResult.notFound;
    } else {
      return AddFriendResult.invalid;
    }

    if (id == _me) return AddFriendResult.self;
    final ids = friendIds;
    if (ids.contains(id)) return AddFriendResult.duplicate;
    if (ids.length >= maxFriends) return AddFriendResult.full;
    await _prefs?.setStringList(_key, [...ids, id]);
    AchievementService().onFriendAdded();
    notifyListeners();
    _sendRequest(id);
    return AddFriendResult.added;
  }

  /// Karşı tarafa "seni ekledim" kaydı bırakır; onun uygulaması da beni ekler
  Future<void> _sendRequest(String to) async {
    try {
      await _db.collection('friend_requests').doc('${to}_$_me').set({
        'to': to,
        'from': _me,
        'name': LeaderboardService().displayName,
        'avatar': LeaderboardService().avatar,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('FriendsService request error: $e');
    }
  }

  /// Beni ekleyenleri dinler: listeme ekler, haber verir, kaydı siler
  void _listenRequests() {
    _sub?.cancel();
    _sub = _db.collection('friend_requests').where('to', isEqualTo: _me).limit(20).snapshots().listen(
      (snap) async {
        final fresh = <(String, String)>[];
        for (final doc in snap.docs) {
          final from = doc.data()['from'] as String?;
          final name = (doc.data()['name'] as String?) ?? '?';
          if (from == null || from == _me) continue;
          final ids = friendIds;
          if (!ids.contains(from) && ids.length < maxFriends) {
            await _prefs?.setStringList(_key, [...ids, from]);
            _rememberName(from, name);
            AchievementService().onFriendAdded();
            fresh.add((doc.id, name));
          }
          doc.reference.delete().catchError((Object _) {});
        }
        if (fresh.isEmpty) return;
        notifyListeners();
        if (_prefs != null) await SocialWatcher.handleFriendRequests(_prefs!, fresh);
        // Uygulama açıksa ekranda da göster
        for (final (_, name) in fresh) {
          rootMessengerKey.currentState?.showSnackBar(SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text(AppStrings.friendAddedYou(name)),
          ));
        }
      },
      onError: (Object e) => debugPrint('FriendsService listen error: $e'),
    );
  }

  Future<void> remove(String id) async {
    await _prefs?.setStringList(_key, friendIds.where((f) => f != id).toList());
    notifyListeners();
  }

  Future<void> shareMyCode() {
    final tr = LanguageService().isTurkish;
    final text = tr
        ? 'Daily Run\'da benimle yarış! Arkadaş kodum: $myCode\n\n${AppLinks.playStore}'
        : 'Race me on Daily Run! My friend code: $myCode\n\n${AppLinks.playStore}';
    return SharePlus.instance.share(ShareParams(text: text));
  }
}

enum AddFriendResult { added, invalid, notFound, offline, self, duplicate, full }
