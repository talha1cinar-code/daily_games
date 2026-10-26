import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:in_app_review/in_app_review.dart';
import 'daily_run_service.dart';
import 'notification_service.dart';
import 'analytics_service.dart';
import 'achievement_service.dart';

/// Duolingo benzeri seri (streak) sistemi.
///
/// - Günde en az 1 oyun bitirmek (Daily Run ya da biletli) seriyi uzatır.
/// - Bir gün kaçırılırsa, o gün için 1 donma hakkı harcanır ve seri korunur.
///   Donmuş günler seriyi artırmaz ama bozmaz.
/// - Kaçırılan gün sayısı donma hakkından fazlaysa seri sıfırlanır; sıfırlandıktan
///   sonra [restoreWindowDays] gün içinde reklam izleyerek geri getirilebilir.
/// - En fazla [maxFreezes] donma hakkı taşınır; her 7 günlük seride +1 kazanılır.
///
/// Tüm günler Türkiye saatine (TSİ) göredir.
class StreakService extends ChangeNotifier {
  static final StreakService _instance = StreakService._internal();
  factory StreakService() => _instance;
  StreakService._internal();

  SharedPreferences? _prefs;

  static const String _key = 'streak_data_v3';
  static const String _legacyKey = 'streak_data_v2';

  static const int maxFreezes = 2;
  static const int startingFreezes = 1;
  static const int freezeEveryDays = 7;
  static const int restoreWindowDays = 2;
  static const int _historyDays = 60;

  /// Kutlama ekranında özel mesaj gösterilen seri günleri
  static const List<int> milestones = [3, 7, 14, 30, 50, 100, 150, 200, 365];

  // ─── Durum ─────────────────────────────────────────────────────
  int _currentStreak = 0;
  int _bestStreak = 0;
  int _freezeCount = startingFreezes;

  /// Seriye sayılan son gün. Donma hakkı harcanınca dünün tarihine çekilir ki
  /// bir sonraki oyun seriyi kaldığı yerden uzatsın.
  String _lastPlayedDate = '';

  /// Donma hakkının en son devreye girdiği gün (geri dönüş günü)
  String _lastFreezeDate = '';

  /// En son 7 günlük ödülle donma hakkı kazanılan gün
  String _freezeEarnedDate = '';

  /// Kutlama ekranının en son gösterildiği gün
  String _celebratedDate = '';

  final List<String> _activeDays = [];
  final List<String> _frozenDays = [];

  /// Oyun bitirilen saatler (hatırlatma saatini kişiselleştirmek için)
  final List<int> _activityHours = [];

  int _lostStreak = 0;
  String _lostDate = '';
  bool _restored = false;
  bool _restorePromptShown = false;

  // ─── Getter'lar ────────────────────────────────────────────────
  int get currentStreak => _currentStreak;
  int get bestStreak => _bestStreak;
  int get freezeCount => _freezeCount;
  String get lastPlayedDate => _lastPlayedDate;
  String get lastFreezeDate => _lastFreezeDate;
  int get lostStreak => _lostStreak;
  bool get isFreezeAvailable => _freezeCount > 0;
  Set<String> get activeDays => _activeDays.toSet();
  Set<String> get frozenDays => _frozenDays.toSet();

  /// Bugün oyun bitirilip seri uzatıldı mı?
  bool get isPlayedToday => _lastPlayedDate == todayKey() && _activeDays.contains(todayKey());

  /// Bugün donma hakkı kazanıldı mı (7 günlük ödül)?
  bool get earnedFreezeToday => _freezeEarnedDate == todayKey();

  // Tamamlama ekranı uyumluluğu
  bool get lastRunExtendedStreak => isPlayedToday;
  bool get lastRunEarnedFreeze => earnedFreezeToday;

  /// Donma hakkı bugün devreye girdiyse ve henüz oynanmadıysa: seri "buz" görünümünde
  bool get isFrozenToday => _currentStreak > 0 && !isPlayedToday && _lastFreezeDate == todayKey();

  /// Bugün seri uzadı ama kutlama henüz gösterilmedi
  bool get shouldCelebrate => isPlayedToday && _celebratedDate != todayKey() && _currentStreak > 0;

  /// Kişinin genelde oynadığı saat (medyan, 10-20 arası); veri yoksa 19
  int get preferredHour {
    if (_activityHours.length < 3) return 19;
    final sorted = [..._activityHours]..sort();
    return sorted[sorted.length ~/ 2].clamp(10, 20);
  }

  bool get canRestoreStreak {
    if (_lostStreak <= 0 || _restored || _lostDate.isEmpty) return false;
    if (_currentStreak >= _lostStreak) return false;
    final lostDay = _parseDate(_lostDate);
    if (lostDay == null) return false;
    return _todayDate().difference(lostDay).inDays <= restoreWindowDays;
  }

  bool get shouldShowRestorePrompt => canRestoreStreak && !_restorePromptShown;

  Future<void> markRestorePromptShown() async {
    if (_restorePromptShown) return;
    _restorePromptShown = true;
    await _save();
  }

  Future<void> markCelebrated() async {
    _celebratedDate = todayKey();
    await _save(reschedule: false);
  }

  // ─── Init / kayıt ──────────────────────────────────────────────
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _load();
    await checkDayGap();
    await updateStreakNotifications();
  }

  void _load() {
    final raw = _prefs?.getString(_key) ?? _prefs?.getString(_legacyKey);
    if (raw == null) return;
    try {
      final d = jsonDecode(raw) as Map<String, dynamic>;
      List<String> strings(String k) => (d[k] as List<dynamic>? ?? []).map((e) => e as String).toList();
      _currentStreak = d['currentStreak'] as int? ?? 0;
      _bestStreak = d['bestStreak'] as int? ?? 0;
      // Eski sürümde 5'e kadar bedava hak vardı; yeni üst sınıra çekilir
      _freezeCount = (d['freezeCount'] as int? ?? startingFreezes).clamp(0, maxFreezes);
      _lastPlayedDate = d['lastPlayedDate'] as String? ?? '';
      _lastFreezeDate = d['lastFreezeDate'] as String? ?? '';
      _freezeEarnedDate = d['freezeEarnedDate'] as String? ?? '';
      _celebratedDate = d['celebratedDate'] as String? ?? '';
      _activeDays
        ..clear()
        ..addAll(strings('activeDays'));
      _frozenDays
        ..clear()
        ..addAll(strings('frozenDays'));
      _activityHours
        ..clear()
        ..addAll((d['activityHours'] as List<dynamic>? ?? []).map((e) => e as int));
      _lostStreak = d['lostStreak'] as int? ?? 0;
      _lostDate = d['lostDate'] as String? ?? '';
      _restored = d['restored'] as bool? ?? false;
      _restorePromptShown = d['restorePromptShown'] as bool? ?? false;
      // v2'den geçişte takvim boş gelir; son oynanan günü işaretle
      if (_activeDays.isEmpty && _lastPlayedDate.isNotEmpty && _currentStreak > 0) {
        _activeDays.add(_lastPlayedDate);
      }
    } catch (_) {}
  }

  Future<void> _save({bool reschedule = true}) async {
    void trim(List<String> l) {
      if (l.length > _historyDays) l.removeRange(0, l.length - _historyDays);
    }

    trim(_activeDays);
    trim(_frozenDays);
    if (_activityHours.length > 14) _activityHours.removeRange(0, _activityHours.length - 14);

    await _prefs?.setString(
      _key,
      jsonEncode({
        'currentStreak': _currentStreak,
        'bestStreak': _bestStreak,
        'freezeCount': _freezeCount,
        'lastPlayedDate': _lastPlayedDate,
        'lastFreezeDate': _lastFreezeDate,
        'freezeEarnedDate': _freezeEarnedDate,
        'celebratedDate': _celebratedDate,
        'activeDays': _activeDays,
        'frozenDays': _frozenDays,
        'activityHours': _activityHours,
        'lostStreak': _lostStreak,
        'lostDate': _lostDate,
        'restored': _restored,
        'restorePromptShown': _restorePromptShown,
      }),
    );
    if (reschedule) await updateStreakNotifications();
    notifyListeners();
  }

  Future<void> updateStreakNotifications() async {
    await NotificationService().scheduleStreakNotifications(
      currentStreak: _currentStreak,
      freezeCount: _freezeCount,
      isPlayedToday: isPlayedToday,
      preferredHour: preferredHour,
      canRestore: canRestoreStreak,
      lostStreak: _lostStreak,
    );
  }

  // ─── Tarih yardımcıları ────────────────────────────────────────
  static DateTime _todayDate() {
    final now = DailyRunService.turkeyNow;
    return DateTime.utc(now.year, now.month, now.day);
  }

  static String keyOf(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static String todayKey() => keyOf(_todayDate());

  static DateTime? _parseDate(String s) {
    final p = s.split('-');
    if (p.length != 3) return null;
    try {
      return DateTime.utc(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
    } catch (_) {
      return null;
    }
  }

  // ─── Gün boşluğu ───────────────────────────────────────────────
  /// Açılışta, arka plandan dönüşte ve oyun bitince çalışır. Kaçırılan günler
  /// için donma hakkı harcar ya da seriyi sıfırlar.
  Future<void> checkDayGap() async {
    if (_lastPlayedDate.isEmpty || _currentStreak == 0) return;
    final last = _parseDate(_lastPlayedDate);
    if (last == null) return;
    final today = _todayDate();
    final missed = today.difference(last).inDays - 1;
    if (missed <= 0) return;

    if (missed <= _freezeCount) {
      _freezeCount -= missed;
      for (var i = 1; i <= missed; i++) {
        _frozenDays.add(keyOf(last.add(Duration(days: i))));
      }
      _lastFreezeDate = todayKey();
      _lastPlayedDate = keyOf(today.subtract(const Duration(days: 1)));
      AnalyticsService().logCustomEvent('streak_freeze_used', {'count': missed, 'streak': _currentStreak});
    } else {
      _lostStreak = _currentStreak;
      _lostDate = todayKey();
      _restored = false;
      _restorePromptShown = false;
      _currentStreak = 0;
      _lastPlayedDate = '';
      _lastFreezeDate = '';
      AnalyticsService().logCustomEvent('streak_lost', {'streak': _lostStreak});
    }
    await _save();
  }

  // ─── Oyun bitirme ──────────────────────────────────────────────
  /// Herhangi bir oyun bitince çağrılır. Gün başına bir kez seriyi uzatır.
  Future<void> recordActivity() async {
    await checkDayGap();
    final today = todayKey();
    _activityHours.add(DailyRunService.turkeyNow.hour);
    if (_lastPlayedDate == today) {
      await _save(reschedule: false);
      return;
    }

    final last = _parseDate(_lastPlayedDate);
    final continues = last != null && _todayDate().difference(last).inDays == 1;
    _currentStreak = continues ? _currentStreak + 1 : 1;
    _lastPlayedDate = today;
    _lastFreezeDate = '';
    if (!_activeDays.contains(today)) _activeDays.add(today);
    if (_currentStreak > _bestStreak) _bestStreak = _currentStreak;

    if (_currentStreak % freezeEveryDays == 0 && _freezeCount < maxFreezes) {
      _freezeCount++;
      _freezeEarnedDate = today;
    }

    if (_lostStreak > 0 && _currentStreak >= _lostStreak) {
      _lostStreak = 0;
      _lostDate = '';
      _restorePromptShown = false;
    }

    AnalyticsService().logStreakAchieved(_currentStreak);
    AchievementService().onStreak(_currentStreak);
    if (_currentStreak == 7) {
      final review = InAppReview.instance;
      if (await review.isAvailable()) review.requestReview();
    }
    await _save();
  }

  /// Geriye dönük uyumluluk: Daily Run bitince de etkinlik sayılır.
  Future<void> onDailyRunCompleted() => recordActivity();

  // ─── Geri getirme ve donma hakkı ───────────────────────────────
  Future<bool> restoreStreakWithAd() async {
    if (!canRestoreStreak) return false;
    _currentStreak = _lostStreak;
    _lostStreak = 0;
    _lostDate = '';
    _restored = true;
    _restorePromptShown = false;
    _lastFreezeDate = '';
    _lastPlayedDate = keyOf(_todayDate().subtract(const Duration(days: 1)));
    if (_currentStreak > _bestStreak) _bestStreak = _currentStreak;
    await _save();
    return true;
  }

  /// Donma hakkı ekler (mağaza vb.). Üst sınırdaysa false döner.
  Future<bool> addFreeze([int count = 1]) async {
    if (_freezeCount >= maxFreezes) return false;
    _freezeCount = (_freezeCount + count).clamp(0, maxFreezes);
    await _save();
    return true;
  }
}
