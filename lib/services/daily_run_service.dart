import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'leaderboard_service.dart';
import 'stats_service.dart';
import 'notification_service.dart';
import '../utils/network_utils.dart';

/// Daily Run oturumunu ve ilerlemesini yöneten servis.
///
/// Her gün 2 Daily Run hakkı var:
///   - Run 1: 00:00 - 16:59
///   - Run 2: 17:00 - 23:59
///
/// Her run'da 12 oyun sırayla oynanır, her oyunun skoru kaydedilir,
/// toplam skor leaderboard'a yazılır.
class DailyRunService extends ChangeNotifier {
  static final DailyRunService _instance = DailyRunService._();
  factory DailyRunService() => _instance;
  DailyRunService._();

  SharedPreferences? _prefs;

  static const String _prefsKeyPrefix = 'daily_run_';

  /// Daily Run'daki oyun sırası
  static const List<String> gameOrder = [
    'wordle',
    'wikitrivia',
    'rgble',
    'nerdle',
    'linele',
    'worldle',
    'sound',
    'memorle',
    'huedle',
    'fille',
    'timele',
    'reactle',
  ];

  /// Oyun isimlerinin görüntüleme adları
  static const Map<String, String> gameDisplayNames = {
    'wordle': 'Wordle',
    'wikitrivia': 'Wikitrivia',
    'rgble': 'RGBle',
    'nerdle': 'Nerdle',
    'linele': 'Linele',
    'worldle': 'Worldle',
    'sound': 'Sound',
    'memorle': 'Memorle',
    'huedle': 'Huedle',
    'fille': 'Fille',
    'timele': 'Timele',
    'reactle': 'Reactle',
  };

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _checkAndProcessActiveRun();
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

  Future<void> saveGameScore(String gameId, double score, [int durationMs = 0]) async {
    final activeKey = _prefs?.getString('active_run_key');
    DailyRunProgress progress;
    
    if (activeKey != null && _prefs!.containsKey(activeKey)) {
      progress = DailyRunProgress.fromJson(jsonDecode(_prefs!.getString(activeKey)!));
    } else {
      progress = getProgress();
    }
    
    progress.scores[gameId] = score;
    progress.durationsMs[gameId] = durationMs;
    progress.currentGameIndex++;
    progress.isStarted = true;

    final liveSlot = currentRunSlot();
    final liveDateKey = _todayKey();
    bool isExpired = (progress.runSlot != liveSlot) || (progress.dateKey != liveDateKey);

    if (progress.currentGameIndex >= gameOrder.length || isExpired) {
      progress.isCompleted = true;
      await _prefs?.remove('active_run_key');
    }

    final targetKey = '$_prefsKeyPrefix${progress.dateKey}_run${progress.runSlot}';
    await _prefs?.setString(targetKey, jsonEncode(progress.toJson()));

    if (progress.isCompleted) {
      await _submitScoreForProgress(progress);
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
      
      final slot = currentRunSlot();
      if (slot == 1) {
        NotificationService().cancelMorningReminder();
      } else {
        NotificationService().cancelEveningReminder();
      }
      
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

    await LeaderboardService().submitScore(
      gameId: gameId,
      score: totalScore,
      durationMs: totalDurationMs,
      isWin: true,
      dateKeyOverride: progress.dateKey,
    );

    // Daily Run sonucunu StatsService ile yerel geçmişe kaydet
    await StatsService().saveDailyStat(
      gameId: 'daily_run',
      isWin: true,
      score: totalScore,
      targetValue: slot == 1 ? 'Sabah' : 'Akşam',
    );

    // Her oyunun bireysel skorunu da kaydet
    for (final entry in progress.scores.entries) {
      await LeaderboardService().submitScore(
        gameId: entry.key,
        score: entry.value,
        isWin: entry.value > 0.0,
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

  /// Sonraki oyunun ID'sini getir (null = tamamlandı)
  String? getNextGameId() {
    final progress = getProgress();
    if (progress.currentGameIndex >= gameOrder.length) return null;
    return gameOrder[progress.currentGameIndex];
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
  Map<String, double> scores;
  Map<String, int> durationsMs;
  bool isCompleted;
  bool isStarted;
  List<String> startedGames;

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
    List<String>? startedGames,
  })  : durationsMs = durationsMs ?? {},
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
    );
  }

  Map<String, dynamic> toJson() => {
        'runSlot': runSlot,
        'dateKey': dateKey,
        'currentGameIndex': currentGameIndex,
        'scores': scores,
        'durationsMs': durationsMs,
        'isCompleted': isCompleted,
        'isStarted': isStarted,
        'startedGames': startedGames,
      };
}
