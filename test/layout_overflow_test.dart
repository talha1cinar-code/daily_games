import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:daily_games/screens/store_screen.dart';
import 'package:daily_games/services/coin_service.dart';
import 'package:daily_games/services/leaderboard_service.dart';
import 'package:daily_games/services/streak_service.dart';
import 'package:daily_games/widgets/avatar_picker_sheet.dart';
import 'package:daily_games/games/countle/countle_screen.dart';
import 'package:daily_games/games/balancele/balancele_screen.dart';
import 'package:daily_games/games/centerle/centerle_screen.dart';
import 'package:daily_games/games/mazele/mazele_screen.dart';
import 'package:daily_games/games/echole/echole_screen.dart';
import 'package:daily_games/games/shadowle/shadowle_screen.dart';
import 'package:daily_games/games/rotatle/rotatle_screen.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

/// Dar ekran + büyütülmüş yazı boyutuyla taşma (overflow) olmadığını doğrular.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Europe/Istanbul'));
    SharedPreferences.setMockInitialValues({});
    await CoinService().init();
    await LeaderboardService().init();
    await StreakService().init();
  });

  Future<void> pump(WidgetTester tester, Widget child, {double width = 360, double textScale = 1.3}) async {
    tester.view.physicalSize = Size(width * 3, 800 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(size: Size(width, 800), textScaler: TextScaler.linear(textScale)),
        child: child,
      ),
    ));
    await tester.pump(const Duration(milliseconds: 100));
  }

  // Fontlar testte indirilemez; yalnızca taşma hatalarını sayarız
  bool isOverflow(Object e) => e.toString().contains('overflowed');

  /// Taşmaları toplar ve hangi widget'tan geldiğini yazdırır
  Future<List<String>> overflowsOf(WidgetTester tester, Widget child) async {
    final found = <String>[];
    final old = FlutterError.onError;
    FlutterError.onError = (d) {
      if (!isOverflow(d.exception)) return;
      final where = d.toString().split('\n').where((l) => l.contains('lib/')).take(2).join(' | ');
      found.add('${d.exception} @ $where');
    };
    await pump(tester, child);
    FlutterError.onError = old;
    for (final f in found) {
      debugPrint('OVERFLOW $f');
    }
    return found;
  }

  testWidgets('mağaza vitrininde taşma yok', (tester) async {
    expect(await overflowsOf(tester, const StoreScreen()), isEmpty);
  });

  testWidgets('banner ve avatar seçicide taşma yok', (tester) async {
    expect(await overflowsOf(tester, const Scaffold(body: AvatarPickerSheet())), isEmpty);
  });

  testWidgets('yeni oyun ekranlarında taşma yok', (tester) async {
    expect(await overflowsOf(tester, const CountleScreen(isDailyMode: false)), isEmpty);
    expect(await overflowsOf(tester, const BalanceleScreen(isDailyMode: false)), isEmpty);
    expect(await overflowsOf(tester, const CenterleScreen(isDailyMode: false)), isEmpty);
    expect(await overflowsOf(tester, const MazeleScreen(isDailyMode: false)), isEmpty);
    expect(await overflowsOf(tester, const EcholeScreen(isDailyMode: false)), isEmpty);
    expect(await overflowsOf(tester, const ShadowleScreen(isDailyMode: false)), isEmpty);
    expect(await overflowsOf(tester, const RotatleScreen(isDailyMode: false)), isEmpty);
  });
}
