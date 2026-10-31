import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:daily_games/services/language_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<String> firstOpen(Map<String, Object> prefs, String device) async {
    SharedPreferences.setMockInitialValues(prefs);
    LanguageService.deviceLanguage = () => device;
    await LanguageService().init();
    return LanguageService().currentLanguage;
  }

  test('yeni kurulum telefon dilini izler, diğer diller İngilizce olur', () async {
    expect(await firstOpen({}, 'tr'), 'tr');
    expect(await firstOpen({}, 'en'), 'en');
    expect(await firstOpen({}, 'de'), 'en');
  });

  test('mevcut oyuncu güncellemeyle Türkçe kalır', () async {
    expect(await firstOpen({'leaderboard_user_id': 'x'}, 'en'), 'tr');
    expect(await firstOpen({'coins_balance': 10}, 'de'), 'tr');
    expect(await firstOpen({'onboarding_done': true}, 'en'), 'tr');
  });

  test('kullanıcının seçimi telefon dilinden önce gelir', () async {
    expect(await firstOpen({'app_language': 'en'}, 'tr'), 'en');
    expect(await firstOpen({'app_language': 'tr'}, 'en'), 'tr');
  });

  test('ilk karar kaydedilir, telefon dili değişince uygulama değişmez', () async {
    expect(await firstOpen({}, 'en'), 'en');
    LanguageService.deviceLanguage = () => 'tr';
    await LanguageService().init();
    expect(LanguageService().currentLanguage, 'en');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('app_language'), 'en');
  });
}
