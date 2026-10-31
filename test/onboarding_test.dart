import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:daily_games/screens/onboarding_screen.dart';
import 'package:daily_games/services/language_service.dart';

/// Tanıtım ekranı telefonda denenemeden yayına çıkabilir; her boyutta ve iki dilde her sayfada
/// taşma ve görsel hatası olmadığını doğrular.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({});
    await LanguageService().init();
  });

  // (genişlik, yükseklik, yazı ölçeği): küçük telefon, büyütülmüş yazı, normal, büyük, tablet, yatay
  const sizes = [
    (320.0, 568.0, 1.0),
    (320.0, 568.0, 1.5),
    (360.0, 640.0, 1.3),
    (390.0, 844.0, 1.0),
    (412.0, 915.0, 2.0),
    (800.0, 1280.0, 1.0),
    (800.0, 360.0, 1.0),
  ];

  for (final lang in const ['tr', 'en']) {
    for (final (w, h, scale) in sizes) {
      testWidgets('$lang ${w.toInt()}x${h.toInt()} yazı $scale: üç sayfada da hata yok', (tester) async {
        await LanguageService().setLanguage(lang);
        tester.view.physicalSize = Size(w * 3, h * 3);
        tester.view.devicePixelRatio = 3;
        addTearDown(tester.view.reset);

        final errors = <String>[];
        final old = FlutterError.onError;
        FlutterError.onError = (d) {
          final text = d.exception.toString();
          // Fontlar testte indirilemez; onun dışındaki her hata gerçek bir sorundur
          if (!text.contains('google_fonts') && !text.contains('GoogleFonts')) errors.add(text);
        };
        addTearDown(() => FlutterError.onError = old);

        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(size: Size(w, h), textScaler: TextScaler.linear(scale)),
              child: const OnboardingScreen(),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 300));
        for (var page = 0; page < 3; page++) {
          expect(tester.takeException(), isNull, reason: 'sayfa ${page + 1}');
          if (page < 2) {
            await tester.drag(find.byType(PageView), Offset(-w, 0));
            await tester.pump(const Duration(milliseconds: 600));
          }
        }
        FlutterError.onError = old;
        expect(errors, isEmpty);

        // Son sayfaya gerçekten gelindi
        expect(find.text(lang == 'tr' ? 'İlk koşuya başla' : 'Start your first run'), findsOneWidget);
      });
    }
  }
}
