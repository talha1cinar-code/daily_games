import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';

class AnalyticsService {
  static final AnalyticsService _instance = AnalyticsService._internal();
  factory AnalyticsService() => _instance;
  AnalyticsService._internal();

  FirebaseAnalytics? _analytics;
  FirebaseAnalyticsObserver? _observer;

  FirebaseAnalytics? get analytics => _analytics;
  FirebaseAnalyticsObserver? get observer => _observer;

  Future<void> init() async {
    try {
      _analytics = FirebaseAnalytics.instance;
      _observer = FirebaseAnalyticsObserver(analytics: _analytics!);
      
      // Log app open
      await _analytics?.logAppOpen();
    } catch (e) {
      debugPrint('Error initializing Firebase Analytics: $e');
    }
  }

  /// Use this to log when a user starts a mini-game
  Future<void> logGameStarted(String gameName) async {
    await _analytics?.logEvent(
      name: 'game_started',
      parameters: {'game_name': gameName},
    );
  }

  /// Use this to log when a user finishes a mini-game
  Future<void> logGameCompleted(String gameName, int score, bool won) async {
    await _analytics?.logEvent(
      name: 'game_completed',
      parameters: {
        'game_name': gameName,
        'score': score,
        'won': won.toString(),
      },
    );
  }

  /// General method for any other custom events
  Future<void> logCustomEvent(String eventName, [Map<String, Object>? parameters]) async {
    await _analytics?.logEvent(
      name: eventName,
      parameters: parameters,
    );
  }

  // --- Economy ---
  Future<void> logTicketEarned(int amount, String source) async {
    await logCustomEvent('ticket_earned', {'amount': amount, 'source': source});
  }

  Future<void> logTicketSpent(int amount, String item) async {
    await logCustomEvent('ticket_spent', {'amount': amount, 'item': item});
  }

  // --- Engagement ---
  Future<void> logStreakAchieved(int streakDays) async {
    await logCustomEvent('streak_achieved', {'days': streakDays});
  }

  Future<void> logDailyRunCompleted(int score) async {
    await logCustomEvent('daily_run_completed', {'score': score});
  }

  // --- Ads ---
  Future<void> logAdWatched(String adType, String reward) async {
    await logCustomEvent('ad_watched_for_reward', {'ad_type': adType, 'reward': reward});
  }

  // --- Settings ---
  Future<void> logLanguageChanged(String languageCode) async {
    await logCustomEvent('language_changed', {'language': languageCode});
  }
}

