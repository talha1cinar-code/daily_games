import 'dart:ui' show PlatformDispatcher;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'analytics_service.dart';

/// Uygulama dil yönetimi servisi.
/// Desteklenen diller: 'tr' (Türkçe) ve 'en' (English).
class LanguageService extends ChangeNotifier {
  static final LanguageService _instance = LanguageService._internal();
  factory LanguageService() => _instance;
  LanguageService._internal();

  String _currentLanguage = 'tr';

  String get currentLanguage => _currentLanguage;
  bool get isTurkish => _currentLanguage == 'tr';
  bool get isEnglish => _currentLanguage == 'en';

  /// Testlerde telefon dilini taklit eder
  @visibleForTesting
  static String Function() deviceLanguage = () => PlatformDispatcher.instance.locale.languageCode;

  /// Bu anahtarlardan biri varsa uygulama daha önce kurulmuştur
  static const List<String> _existingInstallKeys = ['leaderboard_user_id', 'coins_balance', 'onboarding_done'];

  /// Yeni kurulumda telefon Türkçeyse Türkçe, değilse İngilizce
  static String languageForDevice(String languageCode) => languageCode == 'tr' ? 'tr' : 'en';

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    var language = prefs.getString('app_language');
    if (language == null) {
      // Eski sürümlerde varsayılan Türkçeydi; mevcut oyuncunun dili güncellemeyle değişmesin
      final existing = _existingInstallKeys.any(prefs.containsKey);
      language = existing ? 'tr' : languageForDevice(deviceLanguage());
      // Kaydedilir: telefonun dili sonradan değişse de uygulama kendiliğinden değişmez
      await prefs.setString('app_language', language);
    }
    _currentLanguage = language;
    notifyListeners();
  }

  Future<void> setLanguage(String lang) async {
    if (_currentLanguage == lang) return;
    _currentLanguage = lang;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_language', lang);
    AnalyticsService().logLanguageChanged(lang);
    notifyListeners();
  }

  Future<void> toggleLanguage() async {
    await setLanguage(_currentLanguage == 'tr' ? 'en' : 'tr');
  }
}
