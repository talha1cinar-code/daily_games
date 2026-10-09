import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _currentLanguage = prefs.getString('app_language') ?? 'tr';
    notifyListeners();
  }

  Future<void> setLanguage(String lang) async {
    if (_currentLanguage == lang) return;
    _currentLanguage = lang;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_language', lang);
    notifyListeners();
  }

  Future<void> toggleLanguage() async {
    await setLanguage(_currentLanguage == 'tr' ? 'en' : 'tr');
  }
}
