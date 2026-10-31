import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'leaderboard_service.dart';
import 'stats_service.dart';
import 'streak_service.dart';
import 'analytics_service.dart';
import 'achievement_service.dart';
import 'personal_best_service.dart';
import 'daily_challenge_service.dart';
import 'score_scale.dart';
import 'coin_service.dart';
import '../utils/network_utils.dart';

/// Daily Run oturumunu ve ilerlemesini yöneten servis.
///
/// Her gün 2 Daily Run hakkı var:
///   - Run 1: 00:00 - 16:59
///   - Run 2: 17:00 - 23:59
///
/// Her run'da havuzdan tarih+slot seed'iyle seçilen [gamesPerRun] oyun
/// sırayla oynanır; herkes aynı oyunları aynı sırayla görür. Her oyunun skoru
/// kaydedilir, toplam skor leaderboard'a yazılır.
class DailyRunService extends ChangeNotifier {
  static final DailyRunService _instance = DailyRunService._();
  factory DailyRunService() => _instance;
  DailyRunService._();

  SharedPreferences? _prefs;

  static const String _prefsKeyPrefix = 'daily_run_';

  static const int gamesPerRun = 7;

  /// Daily Run'a girebilecek oyunlar
  static const List<String> gamePool = [
    'wordle',
    'tempole',
    'rgble',
    'nerdle',
    'fitle',
    'sound',
    'memorle',
    'huedle',
    'timele',
    'reactle',
    'quickle',
    'slicele',
    'stackle',
    'mirrorle',
    'anglele',
    'dropple',
    'icele',
    'countle',
    'balancele',
    'centerle',
    'mazele',
    'echole',
    'shadowle',
    'rotatle',
  ];

  /// Belirli bir gün ve slot için oyun sırası.
  /// Her oyun kendi id'siyle ayrı bir puan alır ve en yüksek 7 seçilir; böylece havuza
  /// oyun eklemek/çıkarmak (uygulama güncellemesi) diğer oyunların sırasını bozmaz.
  static List<String> gameOrderFor(String dateKey, int slot) {
    int rank(String id) => DailyChallengeService.stableHash('run_${dateKey}_${slot}_$id');
    final sorted = List<String>.from(gamePool)..sort((a, b) => rank(a).compareTo(rank(b)));
    return sorted.take(gamesPerRun).toList();
  }

  /// Şu anki run'ın oyun sırası
  static List<String> get gameOrder => gameOrderFor(_todayKey(), currentRunSlot());

  /// Oyun isimlerinin görüntüleme adları
  static const Map<String, String> gameDisplayNames = {
    'wordle': 'Wordle',
    'tempole': 'Tempole',
    'rgble': 'RGBle',
    'nerdle': 'Nerdle',
    'fitle': 'Fitle',
    'sound': 'Sound',
    'memorle': 'Memorle',
    'huedle': 'Huedle',
    'timele': 'Timele',
    'reactle': 'Reactle',
    'quickle': 'Quickle',
    'slicele': 'Slicele',
    'stackle': 'Stackle',
    'mirrorle': 'Mirrorle',
    'anglele': 'Anglele',
    'dropple': 'Dropple',
    'icele': 'Icele',
    'countle': 'Countle',
    'balancele': 'Balancele',
    'centerle': 'Centerle',
    'mazele': 'Mazele',
    'echole': 'Echole',
    'shadowle': 'Shadowle',
    'rotatle': 'Rotatle',
  };

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    await _repairMisdatedRuns();
    _checkAndProcessActiveRun();
  }

  /// Eski sürümler süresi dolan yarım koşuyu kapandığı güne yazıyordu. Kayıtları
  /// koşunun kendi verisiyle eşleştirip gerçek gününe bir kez taşır.
  Future<void> _repairMisdatedRuns() async {
    const flag = 'run_dates_repaired_v1';
    if (_prefs!.getBool(flag) ?? false) return;

    final runKey = RegExp('^$_prefsKeyPrefix(\\d{4}-\\d{2}-\\d{2})_run([12])\$');
    final runs = <DailyRunProgress>[];
    for (final key in _prefs!.getKeys().where(runKey.hasMatch)) {
      try {
        runs.add(DailyRunProgress.fromJson(jsonDecode(_prefs!.getString(key)!)));
      } catch (_) {}
    }
    double total(DailyRunProgress p) => p.scores.values.fold(0.0, (a, b) => a + b);
    bool matches(DailyRunProgress p, GameStat s, int slot) =>
        p.isCompleted && p.runSlot == slot && (total(p) - s.score).abs() < 0.001;

    for (final stat in StatsService().getStats('daily_run')) {
      final slot = stat.targetValue == 'Sabah' ? 1 : 2;
      if (runs.any((p) => p.dateKey == stat.date && matches(p, stat, slot))) continue;
      // Koşu ancak kendi gününde ya da sonrasında kapanır; en yakın önceki günü al
      final earlier = runs.where((p) => p.dateKey.compareTo(stat.date) < 0 && matches(p, stat, slot)).toList()
        ..sort((a, b) => b.dateKey.compareTo(a.dateKey));
      if (earlier.isNotEmpty) {
        await StatsService().moveStatDate('daily_run', stat.date, earlier.first.dateKey, stat.targetValue);
      }
    }
    await _prefs!.setBool(flag, true);
  }

  // ─── Run Slot Hesaplama ────────────────────────────────────────

  /// Sabit Türkiye Saati (UTC+3) — cihaz saat diliminden ve tarih hilelerinden bağımsız.
  /// Tüm tarih ve slot hesapları bu referansa dayanır.
  static DateTime get turkeyNow =>
      DateTime.now().add(NetworkUtils.timeOffset).toUtc().add(const Duration(hours: 3));

  /// Şu anki run slot'u (1 veya 2)
  /// Türkiye saatine göre: 00:00-16:59 = Slot 1, 17:00-23:59 = Slot 2
  static int currentRunSlot() {
    return turkeyNow.hour < 17 ? 1 : 2;
  }

  /// Bugünün tarih anahtarı (TSİ — Türkiye Saati)
  static String _todayKey() {
    final now = turkeyNow;
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  /// Run'a özel anahtar
  static String _runKey(int slot) {
    return '${_todayKey()}_run$slot';
  }

  // ─── Run Durumu ────────────────────────────────────────────────

  void _checkAndProcessActiveRun() {
    final activeKey = _prefs?.getString('active_run_key');
    if (activeKey != null) {
      final activeStr = _prefs?.getString(activeKey);
      if (activeStr != null) {
        try {
          final activeProgress = DailyRunProgress.fromJson(jsonDecode(activeStr));
          if (activeProgress.isStarted && !activeProgress.isCompleted) {
            final liveSlot = currentRunSlot();
            final liveDateKey = _todayKey();
            if (activeProgress.runSlot != liveSlot || activeProgress.dateKey != liveDateKey) {
              activeProgress.isCompleted = true;
              _prefs?.setString(activeKey, jsonEncode(activeProgress.toJson()));
              _prefs?.remove('active_run_key');
              _submitScoreForProgress(activeProgress);
            }
          }
        } catch (_) {}
      } else {
        _prefs?.remove('active_run_key');
      }
    }
  }

  /// Mevcut run slot'unun durumunu yükle
  DailyRunProgress getProgress() {
    _checkAndProcessActiveRun();
    
    final slot = currentRunSlot();
    final key = '$_prefsKeyPrefix${_runKey(slot)}';
    final jsonStr = _prefs?.getString(key);

    if (jsonStr != null) {
      try {
        return DailyRunProgress.fromJson(jsonDecode(jsonStr));
      } catch (_) {}
    }

    return DailyRunProgress(
      runSlot: slot,
      dateKey: _todayKey(),
      currentGameIndex: 0,
      scores: {},
      isCompleted: false,
      isStarted: false,
    );
  }

  /// Mevcut run tamamlandı mı?
  bool isCurrentRunCompleted() {
    return getProgress().isCompleted;
  }

  /// Mevcut run başladı mı (ama tamamlanmadı)?
  bool isCurrentRunInProgress() {
    final progress = getProgress();
    return progress.isStarted && !progress.isCompleted;
  }

  /// Belirli bir slotun (1 veya 2) bugün için başlatılıp başlatılmadığını kontrol eder
  bool isRunStartedToday(int slot) {
    final key = '$_prefsKeyPrefix${_runKey(slot)}';
    final jsonStr = _prefs?.getString(key);
    if (jsonStr != null) {
      try {
        final progress = DailyRunProgress.fromJson(jsonDecode(jsonStr));
        return progress.isStarted;
      } catch (_) {}
    }
    return false;
  }

  Future<void> saveGameScore(String gameId, double score, [int durationMs = 0]) async {
    final activeKey = _prefs?.getString('active_run_key');
    DailyRunProgress progress;
    
    if (activeKey != null && _prefs!.containsKey(activeKey)) {
      progress = DailyRunProgress.fromJson(jsonDecode(_prefs!.getString(activeKey)!));
    } else {
      progress = getProgress();
    }

    // Oyun bittikten sonra çıkış onayıyla ikinci kez (0 puanla) gelirse yok say
    if (progress.scores.containsKey(gameId)) return;

    // Run toplamı için 0-100'e normalize; oyun sıralaması için ham puan saklanır
    progress.scores[gameId] = ScoreScale.normalize(gameId, score);
    progress.rawScores[gameId] = score;
    progress.durationsMs[gameId] = durationMs;
    progress.isStarted = true;
    PersonalBestService().submit(gameId, score, announce: false);

    final order = progress.gameOrder;
    progress.currentGameIndex = order.where(progress.scores.containsKey).length;

    final liveSlot = currentRunSlot();
    final liveDateKey = _todayKey();
    bool isExpired = (progress.runSlot != liveSlot) || (progress.dateKey != liveDateKey);

    if (progress.currentGameIndex >= order.length || isExpired) {
      progress.isCompleted = true;
      await _prefs?.remove('active_run_key');
    }

    final targetKey = '$_prefsKeyPrefix${progress.dateKey}_run${progress.runSlot}';
    await _prefs?.setString(targetKey, jsonEncode(progress.toJson()));

    if (progress.isCompleted) {
      await _submitScoreForProgress(progress);
      // Seri güncelle
      await StreakService().onDailyRunCompleted();
      await AchievementService().onDailyRunCompleted(progress.runSlot, progress.scores);
    }
    
    notifyListeners();
  }

  Future<void> markGameStarted(String gameId) async {
    final progress = getProgress();
    if (!progress.startedGames.contains(gameId)) {
      progress.startedGames.add(gameId);
      progress.isStarted = true;
      await _saveProgress(progress);
      
      final currentKey = '$_prefsKeyPrefix${_runKey(currentRunSlot())}';
      await _prefs?.setString('active_run_key', currentKey);
      
      notifyListeners();
    }
  }

  /// Toplam skoru hesapla
  double getTotalScore() {
    final progress = getProgress();
    double total = 0;
    for (final score in progress.scores.values) {
      total += score;
    }
    return total;
  }

  Future<void> submitDailyRunScore() async {
    final progress = getProgress();
    await _submitScoreForProgress(progress);
  }

  Future<void> _submitScoreForProgress(DailyRunProgress progress) async {
    if (!progress.isCompleted) return;
    if (progress.scores.isEmpty) return;

    final totalScore = progress.scores.values.fold(0.0, (a, b) => a + b);
    final totalDurationMs = progress.totalDurationMs;
    final slot = progress.runSlot;
    final gameId = 'daily_run_${slot == 1 ? "morning" : "evening"}';

    // Önce telefondaki geçmiş: internet yokken de kaybolmasın
    await StatsService().saveDailyStat(
      gameId: 'daily_run',
      isWin: true,
      score: totalScore,
      targetValue: slot == 1 ? 'Sabah' : 'Akşam',
      dateKey: progress.dateKey,
    );

    await LeaderboardService().submitScore(
      gameId: gameId,
      score: totalScore,
      durationMs: totalDurationMs,
      isWin: true,
      dateKeyOverride: progress.dateKey,
    );

    AnalyticsService().logDailyRunCompleted(totalScore.toInt());

    // Her oyunun bireysel skorunu da kaydet
    for (final entry in progress.scores.entries) {
      final raw = progress.rawScores[entry.key] ?? entry.value;
      await LeaderboardService().submitScore(
        gameId: entry.key,
        score: raw,
        isWin: raw > 0.0,
        durationMs: progress.durationsMs[entry.key],
        dateKeyOverride: progress.dateKey,
      );
    }
  }

  /// Progress'i kaydet
  Future<void> _saveProgress(DailyRunProgress progress) async {
    final slot = currentRunSlot();
    final key = '$_prefsKeyPrefix${_runKey(slot)}';
    await _prefs?.setString(key, jsonEncode(progress.toJson()));
  }

  // ─── Koşu sandığı ──────────────────────────────────────────────

  /// Skora göre sandık ödülü: 20 taban + her 10 puan için 1 coin
  static int chestReward(DailyRunProgress p) {
    final total = p.scores.values.fold(0.0, (a, b) => a + b);
    return 10 + total ~/ 25; // 700 puanlık koşuda en fazla 38
  }

  String _chestKey(DailyRunProgress p, String suffix) => 'chest_${p.dateKey}_${p.runSlot}_$suffix';

  bool isChestOpened(DailyRunProgress p) => _prefs?.getBool(_chestKey(p, 'open')) ?? false;
  bool isChestDoubled(DailyRunProgress p) => _prefs?.getBool(_chestKey(p, 'double')) ?? false;

  /// Sandığı açar ve coin verir; aynı run için ikinci kez vermez.
  Future<int> openChest(DailyRunProgress p) async {
    if (!p.isCompleted || isChestOpened(p)) return 0;
    await _prefs?.setBool(_chestKey(p, 'open'), true);
    final amount = chestReward(p);
    await CoinService().earn(amount, 'run_chest');
    return amount;
  }

  /// Reklam izlenince sandık ödülü bir kez daha verilir.
  Future<int> doubleChest(DailyRunProgress p) async {
    if (!isChestOpened(p) || isChestDoubled(p)) return 0;
    await _prefs?.setBool(_chestKey(p, 'double'), true);
    final amount = chestReward(p);
    await CoinService().earn(amount, 'run_chest_ad');
    return amount;
  }

  /// Sonraki oyunun ID'sini getir (null = tamamlandı)
  String? getNextGameId() {
    final progress = getProgress();
    for (final id in progress.gameOrder) {
      if (!progress.scores.containsKey(id)) return id;
    }
    return null;
  }

  /// Belirli bir oyunun display name'ini getir
  static String getGameDisplayName(String gameId) {
    return gameDisplayNames[gameId] ?? gameId;
  }
}

/// Daily Run ilerleme verisi
class DailyRunProgress {
  int runSlot;
  String dateKey;
  int currentGameIndex;
  /// Normalize (0-100) skorlar — run toplamı bunlardan oluşur
  Map<String, double> scores;

  /// Oyun sıralamasına giden ham puanlar
  Map<String, double> rawScores;
  Map<String, int> durationsMs;
  bool isCompleted;
  bool isStarted;
  List<String> startedGames;

  /// Kaydedilmiş sıra: run bir kez kaydedildikten sonra güncellemelerde değişmez
  final List<String>? _savedOrder;

  /// Bu run'ın oyun sırası (kayıtlıysa o, değilse tarih + slot'tan türetilir)
  List<String> get gameOrder {
    final saved = _savedOrder?.where(DailyRunService.gamePool.contains).toList();
    return saved != null && saved.isNotEmpty ? saved : DailyRunService.gameOrderFor(dateKey, runSlot);
  }

  /// Sıradaki oyunlardan tamamlananların sayısı
  int get completedCount => gameOrder.where(scores.containsKey).length;

  /// Toplam süre (ms)
  int get totalDurationMs => durationsMs.values.fold(0, (a, b) => a + b);

  DailyRunProgress({
    required this.runSlot,
    required this.dateKey,
    required this.currentGameIndex,
    required this.scores,
    required this.isCompleted,
    required this.isStarted,
    Map<String, int>? durationsMs,
    Map<String, double>? rawScores,
    List<String>? startedGames,
    List<String>? savedOrder,
  })  : _savedOrder = savedOrder,
        durationsMs = durationsMs ?? {},
        rawScores = rawScores ?? {},
        startedGames = startedGames ?? [];

  factory DailyRunProgress.fromJson(Map<String, dynamic> json) {
    return DailyRunProgress(
      runSlot: json['runSlot'] as int? ?? 1,
      dateKey: json['dateKey'] as String? ?? '',
      currentGameIndex: json['currentGameIndex'] as int? ?? 0,
      scores: (json['scores'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(k, (v as num).toDouble()),
          ) ??
          {},
      rawScores: (json['rawScores'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(k, (v as num).toDouble()),
          ),
      durationsMs: (json['durationsMs'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(k, (v as num).toInt()),
          ) ??
          {},
      isCompleted: json['isCompleted'] as bool? ?? false,
      isStarted: json['isStarted'] as bool? ?? false,
      startedGames: (json['startedGames'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      savedOrder: (json['gameOrder'] as List<dynamic>?)?.map((e) => e as String).toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'runSlot': runSlot,
        'dateKey': dateKey,
        'currentGameIndex': currentGameIndex,
        'scores': scores,
        'rawScores': rawScores,
        'durationsMs': durationsMs,
        'isCompleted': isCompleted,
        'isStarted': isStarted,
        'startedGames': startedGames,
        'gameOrder': gameOrder,
      };
}
