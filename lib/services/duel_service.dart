import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/duel.dart';
import 'achievement_service.dart';
import 'analytics_service.dart';
import 'coin_service.dart';
import 'friends_service.dart';
import 'leaderboard_service.dart';
import 'notification_service.dart';
import 'social_watcher.dart';

enum MatchState { idle, searching }

/// Sunucusuz düello sistemi (yalnızca Firestore):
///   - `duel_queue/{userId}`: şu an rakip arayanlar (lastSeen ile canlı tutulur)
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

  /// Oynanmış ama sunucuya henüz yazılamamış turlar: {duelId: {tur: skor}}
  static const String _pendingKey = 'duel_pending';

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  SharedPreferences? _prefs;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sub;

  List<Duel> _duels = [];
  List<Duel> _serverDuels = [];
  Map<String, Map<int, double>> _pending = {};
  final Set<String> _inflight = {};
  MatchState _matchState = MatchState.idle;
  Timer? _heartbeat;

  /// Kuyruktaki kayıt bu süre yenilenmezse o kişi artık aramıyor sayılır
  static const Duration _queueFresh = Duration(minutes: 2);
  static const Duration _heartbeatEvery = Duration(seconds: 30);

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
    _loadPending();
    _listen();
    // Uygulama kapanınca arama biter; eski kuyruk kaydı kalmışsa silinir
    _queueRef.doc(me).delete().catchError((Object _) {});
  }

  void _listen() {
    _sub?.cancel();
    _sub = _duelsRef.where('players', arrayContains: me).limit(40).snapshots().listen(
      (snap) {
        _serverDuels = snap.docs.map((d) => Duel.fromMap(d.id, d.data())).toList();
        // Yeni düello, rakip hamlesi, sonuç: uygulama arka plandaysa bildirim
        if (_prefs != null) {
          SocialWatcher.handleDuels(_prefs!, me, _serverDuels).then((_) => SocialWatcher.markChecked(_prefs!));
        }
        _reconcilePending();
        _rebuild();
        // Eşleşme bulunduysa arama durumu biter
        if (_matchState == MatchState.searching && _duels.any((d) => !d.isDone && d.playedBy(me) == 0)) {
          _queueRef.doc(me).get().then((q) {
            if (!q.exists) _stopSearching();
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
  /// Yalnızca şu an arayan biriyle eşleşir. Arayan yoksa kuyruğa girer ve uygulama
  /// açık kaldıkça kaydını tazeler; her tazelemede yeniden rakip arar.
  /// Uygulamadan çıkan ya da aramayı iptal eden kişi ~2 dakika içinde kuyruktan düşer.
  Future<void> findMatch() async {
    if (_matchState == MatchState.searching) return;
    _matchState = MatchState.searching;
    notifyListeners();
    try {
      await _queueRef.doc(me).set({
        'userId': me,
        ..._myProfile,
        'createdAt': FieldValue.serverTimestamp(),
        'lastSeen': FieldValue.serverTimestamp(),
      });
      if (await _tryMatch()) return;
      _heartbeat?.cancel();
      _heartbeat = Timer.periodic(_heartbeatEvery, (_) => _beat());
    } catch (e) {
      debugPrint('DuelService findMatch error: $e');
      _stopSearching();
      rethrow;
    }
  }

  Future<void> _beat() async {
    if (_matchState != MatchState.searching) return;
    // Uygulama arka plandayken kayıt tazelenmez; böylece kimse kapalı uygulamayla eşleşmez
    if (WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) return;
    try {
      final mine = await _queueRef.doc(me).get();
      if (!mine.exists) {
        // Bir rakip beni eşleştirip kuyruktan aldı; düello dinleyiciden gelir
        _stopSearching();
        return;
      }
      await _queueRef.doc(me).update({'lastSeen': FieldValue.serverTimestamp()});
      await _tryMatch();
    } catch (e) {
      debugPrint('DuelService heartbeat error: $e');
    }
  }

  /// Kuyrukta canlı bir rakip varsa ikimizi de kuyruktan alıp maçı kurar
  Future<bool> _tryMatch() async {
    final waiting = await _queueRef.orderBy('lastSeen', descending: true).limit(15).get();
    final cutoff = DateTime.now().subtract(_queueFresh);
    // Zaten sürmekte olan düellom varsa aynı kişiyle bir daha eşleşmeyelim
    final busyWith = {for (final d in _duels.where((d) => !d.isDone)) d.opponentOf(me)};
    final candidates = waiting.docs.where((d) {
      if (d.id == me || busyWith.contains(d.id)) return false;
      final ts = d.data()['lastSeen'];
      return ts is Timestamp && ts.toDate().isAfter(cutoff);
    });
    final myRef = _queueRef.doc(me);
    for (final c in candidates) {
      final matched = await _db.runTransaction<bool>((tx) async {
        final fresh = await tx.get(c.reference);
        final mine = await tx.get(myRef);
        // Rakip başkasıyla eşleşti ya da biri beni çoktan aldı
        if (!fresh.exists || !mine.exists) return false;
        tx.delete(c.reference);
        tx.delete(myRef);
        tx.set(_duelsRef.doc(), _newDuel(c.id, fresh.data()!));
        return true;
      });
      if (matched) {
        AnalyticsService().logCustomEvent('duel_matched', {'source': 'queue'});
        _stopSearching();
        return true;
      }
      if (!(await myRef.get()).exists) {
        _stopSearching();
        return true;
      }
    }
    return false;
  }

  void _stopSearching() {
    _heartbeat?.cancel();
    _heartbeat = null;
    if (_matchState == MatchState.idle) return;
    _matchState = MatchState.idle;
    notifyListeners();
  }

  Future<void> cancelSearch() async {
    _stopSearching();
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

  // ─── Bekleyen turlar ─────────────────────────────────────────────
  void _loadPending() {
    try {
      final raw = jsonDecode(_prefs?.getString(_pendingKey) ?? '{}') as Map<String, dynamic>;
      _pending = raw.map((id, v) => MapEntry(
            id,
            (v as Map<String, dynamic>).map((r, s) => MapEntry(int.parse(r), (s as num).toDouble())),
          ));
    } catch (_) {
      _pending = {};
    }
  }

  void _savePending() {
    _prefs?.setString(
      _pendingKey,
      jsonEncode(_pending.map((id, v) => MapEntry(id, v.map((r, s) => MapEntry('$r', s))))),
    );
  }

  /// Sunucuya ulaşan turları bekleyenlerden çıkarır, kalanları yeniden gönderir
  void _reconcilePending() {
    final byId = {for (final d in _serverDuels) d.id: d};
    var changed = false;
    for (final id in _pending.keys.toList()) {
      final d = byId[id];
      if (d == null) continue; // liste henüz gelmemiş olabilir
      final rounds = _pending[id]!;
      rounds.removeWhere((r, _) => d.isDone || (d.scores[me]?.containsKey(r) ?? false));
      if (rounds.isEmpty) {
        _pending.remove(id);
        changed = true;
        continue;
      }
      for (final e in rounds.entries) {
        _send(id, e.key, e.value);
      }
    }
    if (changed) _savePending();
  }

  /// Sunucu verisi + bekleyen turlar; sırası bende olanlar önce, sonra en yeni
  void _rebuild() {
    _duels = [
      for (final d in _serverDuels)
        if (_pending[d.id]?.isNotEmpty ?? false) d.withMyScores(me, _pending[d.id]!) else d,
    ]..sort((a, b) {
        final t = (b.isMyTurn(me) ? 1 : 0) - (a.isMyTurn(me) ? 1 : 0);
        return t != 0 ? t : b.updatedAt.compareTo(a.updatedAt);
      });
  }

  // ─── Tur sonucu ──────────────────────────────────────────────────
  /// Turu hemen "oynandı" sayar (aynı tur tekrar oynanamaz), sonra sunucuya yazar.
  /// Yazılamazsa skor cihazda bekler ve bir sonraki güncellemede yeniden denenir.
  Future<void> submitRound(Duel duel, int round, double normalizedScore) async {
    _pending.putIfAbsent(duel.id, () => {})[round] = normalizedScore;
    _savePending();
    _rebuild();
    notifyListeners();
    await _send(duel.id, round, normalizedScore);
  }

  Future<void> _send(String duelId, int round, double normalizedScore) async {
    final key = '$duelId:$round';
    if (!_inflight.add(key)) return;
    try {
      await _write(duelId, round, normalizedScore);
    } catch (e) {
      debugPrint('DuelService submit error: $e');
    } finally {
      _inflight.remove(key);
    }
  }

  Future<void> _write(String duelId, int round, double normalizedScore) async {
    final ref = _duelsRef.doc(duelId);
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
    for (final d in _serverDuels.where((d) => d.isExpired)) {
      _duelsRef.doc(d.id).update({'status': 'done', 'winner': Duel.decideExpired(d)}).catchError((Object e) {
        debugPrint('DuelService expire error: $e');
      });
    }
    final claimed = (_prefs?.getStringList(_claimedKey) ?? []).toSet();
    var changed = false;
    for (final d in _serverDuels) {
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
      final (myRounds, _) = d.roundWins(me);
      AchievementService().onDuelFinished(
        won: r == DuelResult.win,
        sweep: myRounds >= Duel.rounds,
        totalWins: wins,
        trophies: trophies,
        vsFriend: FriendsService().friendIds.contains(d.opponentOf(me)),
      );
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
