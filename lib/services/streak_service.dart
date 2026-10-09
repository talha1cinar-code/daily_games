import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'daily_run_service.dart';
import 'notification_service.dart';

/// Duolingo benzeri seri (streak) sistemi.
///
/// - Kullanıcı günde en az 1 Daily Run tamamlarsa seri artar.
/// - 1 gün atlarsa önce donma hakkı (freeze) kullanılır.
/// - Donma hakkı bittiyse seri sıfırlanır.
/// - Seri sıfırlandıktan sonra 7 gün içinde reklam izleyerek geri getirilebilir.
class StreakService extends ChangeNotifier {
  static final StreakService _instance = StreakService._internal();
  factory StreakService() => _instance;
  StreakService._internal();

  SharedPreferences? _prefs;

  static const String _key = 'streak_data_v2';

  // Varsayılan donma hakkı
  static const int defaultFreezeCount = 2;

  // Seri geri getirme penceresi (gün)
  static const int restoreWindowDays = 7;

  // ─── Durum değişkenleri ────────────────────────────────────────
  int _currentStreak = 0;
  int _bestStreak = 0;
  int _freezeCount = defaultFreezeCount;
  String _lastPlayedDate = ''; // Son oynanan gün (yyyy-MM-dd)
  
  // Seri sıfırlandıysa geri getirme bilgileri
  int _lostStreak = 0; // Kaybedilen seri değeri
  String _lostDate = ''; // Serinin kaybolduğu tarih
  bool _restored = false; // Bu kayıp zaten geri getirildi mi

  // ─── Getter'lar ────────────────────────────────────────────────
  int get currentStreak => _currentStreak;
  int get bestStreak => _bestStreak;
  int get freezeCount => _freezeCount;
  String get lastPlayedDate => _lastPlayedDate;
  int get lostStreak => _lostStreak;
  bool get canRestoreStreak {
    if (_lostStreak <= 0 || _restored) return false;
    if (_lostDate.isEmpty) return false;
    
    final lostDay = _parseDate(_lostDate);
    if (lostDay == null) return false;
    
    final today = _todayDate();
    final diff = today.difference(lostDay).inDays;
    return diff <= restoreWindowDays;
  }

  bool get isFreezeAvailable => _freezeCount > 0;
  
  /// Bugün henüz oynanmadıysa ve donma hakkı varsa seri donmuş (koruma altında) sayılır.
  bool get isFrozenToday {
    if (_currentStreak == 0) return false;
    final today = _todayKey();
    return _lastPlayedDate != today && _freezeCount > 0;
  }

  // ─── Init ──────────────────────────────────────────────────────
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _load();
    // Her açılışta gün kontrolü yap
    _checkDayGap();
  }

  void _load() {
    final jsonStr = _prefs?.getString(_key);
    if (jsonStr == null) return;
    
    try {
      final data = jsonDecode(jsonStr) as Map<String, dynamic>;
      _currentStreak = data['currentStreak'] as int? ?? 0;
      _bestStreak = data['bestStreak'] as int? ?? 0;
      _freezeCount = data['freezeCount'] as int? ?? defaultFreezeCount;
      _lastPlayedDate = data['lastPlayedDate'] as String? ?? '';
      _lostStreak = data['lostStreak'] as int? ?? 0;
      _lostDate = data['lostDate'] as String? ?? '';
      _restored = data['restored'] as bool? ?? false;
    } catch (_) {}
  }

  Future<void> _save() async {
    final data = {
      'currentStreak': _currentStreak,
      'bestStreak': _bestStreak,
      'freezeCount': _freezeCount,
      'lastPlayedDate': _lastPlayedDate,
      'lostStreak': _lostStreak,
      'lostDate': _lostDate,
      'restored': _restored,
    };
    await _prefs?.setString(_key, jsonEncode(data));
    
    // Seri bildirimlerini güncelle
    await NotificationService().scheduleStreakNotifications(_freezeCount);
    
    notifyListeners();
  }

  // ─── Gün hesaplama ─────────────────────────────────────────────
  static DateTime _todayDate() {
    final now = DailyRunService.turkeyNow;
    return DateTime(now.year, now.month, now.day);
  }

  static String _todayKey() {
    final now = DailyRunService.turkeyNow;
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  static DateTime? _parseDate(String dateStr) {
    try {
      final parts = dateStr.split('-');
      if (parts.length != 3) return null;
      return DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
    } catch (_) {
      return null;
    }
  }

  // ─── Gün boşluğu kontrolü ─────────────────────────────────────
  /// Uygulama her açıldığında çalışır.
  /// Son oynanan gün ile bugün arasındaki farkı kontrol eder.
  void _checkDayGap() {
    if (_lastPlayedDate.isEmpty || _currentStreak == 0) return;

    final lastPlayed = _parseDate(_lastPlayedDate);
    if (lastPlayed == null) return;

    final today = _todayDate();
    final diff = today.difference(lastPlayed).inDays;

    if (diff <= 1) {
      // Bugün veya dün oynanmış, seri güvende
      return;
    }

    // Atlanan gün sayısı
    final missedDays = diff - 1;

    if (missedDays <= _freezeCount) {
      // Donma hakları ile kurtarılabilir
      _freezeCount -= missedDays;
      // lastPlayedDate'i dünle güncelle ki bugün oynandığında seri artsın
      final yesterday = today.subtract(const Duration(days: 1));
      _lastPlayedDate = '${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}';
      _save();
    } else {
      // Seri kaybedildi
      _lostStreak = _currentStreak;
      _lostDate = _todayKey();
      _restored = false;
      _currentStreak = 0;
      _freezeCount = defaultFreezeCount; // Freeze'leri sıfırla
      _lastPlayedDate = '';
      _save();
    }
  }

  // ─── Daily Run tamamlandığında çağır ───────────────────────────
  /// Kullanıcı bir Daily Run tamamladığında bu metod çağrılır.
  /// Gün başına 1 kez seriyi artırır.
  Future<void> onDailyRunCompleted() async {
    final today = _todayKey();

    if (_lastPlayedDate == today) {
      // Bugün zaten oynanmış (sabah/akşam farketmez), seri zaten artmış
      return;
    }

    final lastPlayed = _parseDate(_lastPlayedDate);
    final todayDate = _todayDate();

    if (lastPlayed != null) {
      final diff = todayDate.difference(lastPlayed).inDays;
      
      if (diff == 1) {
        // Ardışık gün, seri devam ediyor
        _currentStreak++;
      } else if (diff == 0) {
        // Aynı gün (zaten yukarıda yakalandı ama safety check)
        return;
      } else {
        // Gün atlanmış - _checkDayGap zaten handle etti ama fallback
        _currentStreak = 1;
      }
    } else {
      // İlk kez oynuyor
      _currentStreak = 1;
    }

    _lastPlayedDate = today;
    
    if (_currentStreak > _bestStreak) {
      _bestStreak = _currentStreak;
    }

    await _save();
  }

  // ─── Seri geri getirme (reklam ile) ────────────────────────────
  /// Reklam izlendikten sonra seriyi geri getirir.
  Future<bool> restoreStreakWithAd() async {
    if (!canRestoreStreak) return false;

    _currentStreak = _lostStreak;
    _lostStreak = 0;
    _lostDate = '';
    _restored = true;
    _freezeCount = defaultFreezeCount; // Freeze'leri de yenile
    
    // lastPlayedDate'i dün olarak ayarla ki bugün oynandığında +1 olsun
    final yesterday = _todayDate().subtract(const Duration(days: 1));
    _lastPlayedDate = '${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}';
    
    if (_currentStreak > _bestStreak) {
      _bestStreak = _currentStreak;
    }

    await _save();
    return true;
  }

  // ─── Donma hakkı ekleme (ödül olarak) ──────────────────────────
  /// Ekstra donma hakkı ekler (reklam izleme, ödül vs.)
  Future<void> addFreeze([int count = 1]) async {
    _freezeCount += count;
    await _save();
  }
}
