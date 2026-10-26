import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import '../utils/app_links.dart';
import 'achievement_service.dart';
import 'language_service.dart';
import 'leaderboard_service.dart';

/// Arkadaş listesi. Arkadaş kodu, kullanıcının sıralamadaki kimliğidir (UUID);
/// böylece yeni bir Firestore koleksiyonu gerekmeden mevcut sıralama
/// kayıtlarından arkadaşların skoru okunur. Takip tek yönlüdür.
class FriendsService extends ChangeNotifier {
  static final FriendsService _instance = FriendsService._internal();
  factory FriendsService() => _instance;
  FriendsService._internal();

  static const String _key = 'friend_ids';
  static const String _namesKey = 'friend_names';
  static const int maxFriends = 29; // kendimizle birlikte tek whereIn sorgusu
  static final RegExp _uuid = RegExp(
    r'[0-9a-f]{8}-?[0-9a-f]{4}-?[0-9a-f]{4}-?[0-9a-f]{4}-?[0-9a-f]{12}',
    caseSensitive: false,
  );

  SharedPreferences? _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  List<String> get friendIds => _prefs?.getStringList(_key) ?? [];

  String get myCode => LeaderboardService().userId.toUpperCase();

  /// Daha önce sıralamada görülen arkadaş adları (bugün oynamamışlar için)
  String? nameOf(String id) {
    final list = _prefs?.getStringList(_namesKey) ?? [];
    for (final e in list) {
      final i = e.indexOf('|');
      if (i > 0 && e.substring(0, i) == id) return e.substring(i + 1);
    }
    return null;
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

  /// Yapıştırılan metinden kodu ayıklar. Başarı durumunu döndürür.
  Future<AddFriendResult> addFromText(String text) async {
    final m = _uuid.firstMatch(text.trim());
    if (m == null) return AddFriendResult.invalid;
    final hex = m.group(0)!.replaceAll('-', '').toLowerCase();
    final id = '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-'
        '${hex.substring(16, 20)}-${hex.substring(20)}';
    if (id == LeaderboardService().userId) return AddFriendResult.self;
    final ids = friendIds;
    if (ids.contains(id)) return AddFriendResult.duplicate;
    if (ids.length >= maxFriends) return AddFriendResult.full;
    await _prefs?.setStringList(_key, [...ids, id]);
    AchievementService().onFriendAdded();
    notifyListeners();
    return AddFriendResult.added;
  }

  Future<void> remove(String id) async {
    await _prefs?.setStringList(_key, friendIds.where((f) => f != id).toList());
    notifyListeners();
  }

  Future<void> shareMyCode() {
    final tr = LanguageService().isTurkish;
    final text = tr
        ? 'Daily Run\'da benimle yarış! Arkadaş kodum:\n$myCode\n\n${AppLinks.playStore}'
        : 'Race me on Daily Run! My friend code:\n$myCode\n\n${AppLinks.playStore}';
    return SharePlus.instance.share(ShareParams(text: text));
  }
}

enum AddFriendResult { added, invalid, self, duplicate, full }
