import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/duel.dart';
import 'analytics_service.dart';
import 'coin_service.dart';
import 'leaderboard_service.dart';
import 'notification_service.dart';

enum MatchState { idle, searching }

/// Sunucusuz düello sistemi (yalnızca Firestore):
///   - `duel_queue/{userId}`: rakip bekleyenler
///   - `duels/{id}`: maçlar (oyuncular, 3 oyun, seed, skorlar)
///   - `duel_profiles/{userId}`: kupa ligi
/// Kimlik, sıralamadaki gibi cihazdaki kullanıcı kimliğidir.
class DuelService extends ChangeNotifier {
  static final DuelService _instance = DuelService._internal();
  factory DuelService() => _instance;
  DuelService._internal();

  static const String _claimedKey = 'duel_claimed';
  static const String _trophyKey = 'duel_trophies';
  static const String _statsKey = 'duel_stats'; // wins,losses,draws

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  SharedPreferences? _prefs;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sub;

  List<Duel> _duels = [];
  MatchState _matchState = MatchState.idle;

  /// Biten ve ödülü yeni verilen düello (ekranda kutlamak için bir kez okunur)
  final List<(Duel, DuelResult)> _newResults = [];

  String get me => LeaderboardService().userId;
  List<Duel> get duels => _duels;
  MatchState get matchState => _matchState;
  int get trophies => _prefs?.getInt(_trophyKey) ?? 0;
  int get myTurnCount => _duels.where((d) => d.isMyTurn(me)).length;

  List<int> get _stats => (_prefs?.getString(_statsKey) ?? '0,0,0').split(',').map(int.parse).toList();
  int get wins => _stats[0];
  int get losses => _stats[1];
  int get draws => _stats[2];

  CollectionReference<Map<String, dynamic>> get _duelsRef => _db.collection('duels');
  CollectionReference<Map<String, dynamic>> get _queueRef => _db.collection('duel_queue');
  CollectionReference<Map<String, dynamic>> get _profilesRef => _db.collection('duel_profiles');

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _listen();
    // Daha önce aramaya başlanmışsa durum korunur
    try {
      final q = await _queueRef.doc(me).get();
      if (q.exists) _matchState = MatchState.searching;
    } catch (_) {}
  }

  void _listen() {
    _sub?.cancel();
    _sub = _duelsRef.where('players', arrayContains: me).limit(40).snapshots().listen(
      (snap) {
        _duels = snap.docs.map((d) => Duel.fromMap(d.id, d.data())).toList()
          ..sort((a, b) {
            // Sırası bende olanlar önce, sonra en yeni
            final t = (b.isMyTurn(me) ? 1 : 0) - (a.isMyTurn(me) ? 1 : 0);
            return t != 0 ? t : b.updatedAt.compareTo(a.updatedAt);
          });
        // Eşleşme bulunduysa arama durumu biter
        if (_matchState == MatchState.searching && _duels.any((d) => !d.isDone && d.playedBy(me) == 0)) {
          _queueRef.doc(me).get().then((q) {
            if (!q.exists) {
              _matchState = MatchState.idle;
              notifyListeners();
            }
          });
        }
        _handleFinished();
        _scheduleReminder();
        notifyListeners();
      },
      onError: (Object e) => debugPrint('DuelService stream error: $e'),
    );
  }

  Map<String, dynamic> get _myProfile => {
        'name': LeaderboardService().displayName,
        'avatar': LeaderboardService().avatar,
        'banner': LeaderboardService().banner,
      };

  // ─── Eşleştirme ──────────────────────────────────────────────────
  /// Bekleyen bir rakip varsa onunla maç kurar; yoksa kuyruğa girer.
  Future<void> findMatch() async {
    if (_matchState == MatchState.searching) return;
    _matchState = MatchState.searching;
    notifyListeners();
    try {
      final waiting = await _queueRef.orderBy('createdAt').limit(10).get();
      final cutoff = DateTime.now().subtract(const Duration(hours: 24));
      final candidates = waiting.docs.where((d) {
        if (d.id == me) return false;
        final ts = d.data()['createdAt'];
        return ts is Timestamp && ts.toDate().isAfter(cutoff);
      });
      for (final c in candidates) {
        final matched = await _db.runTransaction<bool>((tx) async {
          final fresh = await tx.get(c.reference);
          if (!fresh.exists) return false; // başkası kaptı
          final opp = fresh.data()!;
          tx.delete(c.reference);
          tx.set(_duelsRef.doc(), _newDuel(c.id, opp));
          return true;
        });
        if (matched) {
          _matchState = MatchState.idle;
          AnalyticsService().logCustomEvent('duel_matched', {'source': 'queue'});
          notifyListeners();
          return;
        }
      }
      await _queueRef.doc(me).set({
        'userId': me,
        ..._myProfile,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('DuelService findMatch error: $e');
      _matchState = MatchState.idle;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> cancelSearch() async {
    _matchState = MatchState.idle;
    notifyListeners();
    try {
      await _queueRef.doc(me).delete();
    } catch (_) {}
  }

  /// Arkadaşa doğrudan düello gönderir.
  Future<void> challengeFriend(String friendId, String friendName) async {
    await _duelsRef.doc().set(_newDuel(friendId, {'name': friendName, 'avatar': '🙂', 'banner': 'none'}));
    AnalyticsService().logCustomEvent('duel_matched', {'source': 'friend'});
  }

  Map<String, dynamic> _newDuel(String oppId, Map<String, dynamic> opp) {
    final rng = Random.secure();
    return {
      'players': [me, oppId],
      'games': Duel.pickGames(rng),
      'seed': rng.nextInt(1 << 30),
      'names': {me: _myProfile['name'], oppId: opp['name'] ?? '?'},
      'avatars': {me: _myProfile['avatar'], oppId: opp['avatar'] ?? '🙂'},
      'banners': {me: _myProfile['banner'], oppId: opp['banner'] ?? 'none'},
      'scores': {},
      'status': 'active',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  // ─── Tur sonucu ──────────────────────────────────────────────────
  /// Turu kaydeder; iki oyuncu da bitirdiyse maçı sonuçlandırır.
  Future<void> submitRound(Duel duel, int round, double normalizedScore) async {
    final ref = _duelsRef.doc(duel.id);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) return;
      final current = Duel.fromMap(snap.id, snap.data()!);
      if (current.isDone || (current.scores[me]?.containsKey(round) ?? false)) return;

      final scores = {
        for (final e in current.scores.entries) e.key: {for (final s in e.value.entries) '${s.key}': s.value},
      };
      scores.putIfAbsent(me, () => {})['$round'] = normalizedScore;

      final updates = <String, dynamic>{
        'scores': scores,
        'updatedAt': FieldValue.serverTimestamp(),
        // Davet edilen oyuncu kendi görünümünü ilk turda yazar
        'names': {...current.names, me: LeaderboardService().displayName},
        'avatars': {...current.avatars, me: LeaderboardService().avatar},
        'banners': {...current.banners, me: LeaderboardService().banner},
      };
      final after = Duel.fromMap(snap.id, {...snap.data()!, ...updates, 'updatedAt': DateTime.now()});
      final winner = Duel.decideWinner(after);
      if (winner != null) {
        updates['status'] = 'done';
        updates['winner'] = winner;
      }
      tx.update(ref, updates);
    });
  }

  /// Süresi dolan maçları kapatır, biten maçların ödülünü bir kez verir.
  void _handleFinished() {
    for (final d in _duels.where((d) => d.isExpired)) {
      _duelsRef.doc(d.id).update({'status': 'done', 'winner': Duel.decideExpired(d)}).catchError((Object e) {
        debugPrint('DuelService expire error: $e');
      });
    }
    final claimed = (_prefs?.getStringList(_claimedKey) ?? []).toSet();
    var changed = false;
    for (final d in _duels) {
      final r = d.resultFor(me);
      if (r == null || claimed.contains(d.id)) continue;
      claimed.add(d.id);
      changed = true;
      final (dt, coins) = DuelRewards.of(r);
      _prefs?.setInt(_trophyKey, max(0, trophies + dt));
      final s = _stats;
      s[r.index]++; // win, loss, draw sırası _statsKey ile aynı
      _prefs?.setString(_statsKey, s.join(','));
      CoinService().earn(coins, 'duel_${r.name}');
      AnalyticsService().logCustomEvent('duel_finished', {'result': r.name});
      _newResults.add((d, r));
    }
    if (changed) {
      _prefs?.setStringList(_claimedKey, claimed.toList());
      syncProfile();
    }
  }

  /// Ödülü yeni verilen sonuçları bir kez döndürür (kutlama için)
  List<(Duel, DuelResult)> takeNewResults() {
    final r = List.of(_newResults);
    _newResults.clear();
    return r;
  }

  Future<void> syncProfile() async {
    try {
      await _profilesRef.doc(me).set({
        ..._myProfile,
        'trophies': trophies,
        'wins': wins,
        'losses': losses,
        'draws': draws,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('DuelService syncProfile error: $e');
    }
  }

  /// Kupa ligi sıralaması
  Future<List<Map<String, dynamic>>> topProfiles() async {
    final snap = await _profilesRef.orderBy('trophies', descending: true).limit(50).get();
    return snap.docs.map((d) => {'userId': d.id, ...d.data()}).toList();
  }

  // ─── Hatırlatma ──────────────────────────────────────────────────
  void _scheduleReminder() {
    NotificationService().scheduleDuelReminder(pending: myTurnCount);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
