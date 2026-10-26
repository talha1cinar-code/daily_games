import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'firebase_options.dart';
import 'theme/app_theme.dart';
import 'screens/home_screen.dart';
import 'screens/onboarding_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'services/settings_service.dart';
import 'services/language_service.dart';
import 'services/ticket_service.dart';
import 'services/stats_service.dart';
import 'services/leaderboard_service.dart';
import 'services/sound_service.dart';
import 'services/daily_run_service.dart';
import 'services/notification_service.dart';
import 'services/streak_service.dart';
import 'services/ad_service.dart';
import 'services/analytics_service.dart';
import 'services/personal_best_service.dart';
import 'services/achievement_service.dart';
import 'services/friends_service.dart';
import 'services/coin_service.dart';
import 'services/daily_reward_service.dart';
import 'services/duel_service.dart';
import 'utils/app_messenger.dart';
import 'utils/network_utils.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light, // Android: açık ikonlar (koyu arka plan)
      statusBarBrightness: Brightness.dark, // iOS: açık ikonlar
    ),
  );
  
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };

  await LanguageService().init();
  await SettingsService().init();
  await TicketService().init();
  await StatsService().init();
  await LeaderboardService().init();
  await PersonalBestService().init();
  await AchievementService().init();
  await FriendsService().init();
  await DailyRunService().init();
  await NetworkUtils.syncTime();
  await NotificationService().init();
  await StreakService().init();
  await AnalyticsService().init();
  
  await CoinService().init();
  await DailyRewardService().init();
  await DuelService().init();
  await MobileAds.instance.initialize();
  AdService().init();
  
  // Tanıtım yalnızca gerçekten yeni kullanıcılara (güncelleme alanlara değil)
  final prefs = await SharedPreferences.getInstance();
  final isNewUser = StatsService().getStats('daily_run').isEmpty && StreakService().bestStreak == 0;
  final showOnboarding = !(prefs.getBool(OnboardingScreen.doneKey) ?? false) && isNewUser;

  runApp(DailyGamesApp(showOnboarding: showOnboarding));
}

class DailyGamesApp extends StatefulWidget {
  final bool showOnboarding;
  const DailyGamesApp({super.key, this.showOnboarding = false});

  @override
  State<DailyGamesApp> createState() => _DailyGamesAppState();
}

class _DailyGamesAppState extends State<DailyGamesApp> with WidgetsBindingObserver {
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Start background music after a short delay to ensure audio engine is ready
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        SoundService().updateBgmState();
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await NotificationService().requestPermissions();
      await NotificationService().scheduleDailyNotifications();
      await StreakService().updateStreakNotifications();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      SoundService().pauseBgm();
    } else if (state == AppLifecycleState.resumed) {
      // Delay before resuming audio to avoid platform thread deadlocks on Android
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted && !SoundService().isInMiniGame) {
          SoundService().updateBgmState();
        }
      });
      // Arka plandan öne gelindiğinde gün kontrolü ve NTP saat senkronizasyonu
      StreakService().checkDayGap();
      NetworkUtils.syncTime().then((_) {
        StreakService().checkDayGap();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Daily Run',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: rootMessengerKey,
      theme: AppTheme.lightTheme,
      home: widget.showOnboarding ? const OnboardingScreen() : const HomeScreen(),
      navigatorObservers: [
        if (AnalyticsService().observer != null) AnalyticsService().observer!,
      ],
    );
  }
}
