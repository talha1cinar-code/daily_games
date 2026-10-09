import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'theme/app_theme.dart';
import 'screens/home_screen.dart';

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
      statusBarIconBrightness: Brightness.dark,
    ),
  );
  
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  await LanguageService().init();
  await SettingsService().init();
  await TicketService().init();
  await StatsService().init();
  await LeaderboardService().init();
  await DailyRunService().init();
  await NetworkUtils.syncTime();
  await StreakService().init();
  
  await NotificationService().init();
  
  await MobileAds.instance.initialize();
  AdService().init();
  
  runApp(const DailyGamesApp());
}

class DailyGamesApp extends StatefulWidget {
  const DailyGamesApp({super.key});

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
      await NotificationService().scheduleDailyNotifications();
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
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Daily Run',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const HomeScreen(),
    );
  }
}
