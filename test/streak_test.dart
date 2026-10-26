import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:daily_games/services/daily_run_service.dart';
import 'package:daily_games/services/streak_service.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

String _daysAgo(int n) {
  final t = DailyRunService.turkeyNow;
  return StreakService.keyOf(DateTime.utc(t.year, t.month, t.day).subtract(Duration(days: n)));
}

Future<StreakService> _setup(Map<String, Object?> data, {String key = 'streak_data_v3'}) async {
  SharedPreferences.setMockInitialValues({key: jsonEncode(data)});
  await StreakService().init();
  return StreakService();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() {
    // Bildirim planlaması TSİ saat dilimini kullanır (uygulamada NotificationService.init kurar)
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Europe/Istanbul'));
  });

  test('dün oynandıysa bugünkü oyun seriyi 1 artırır, ikinci oyun artırmaz', () async {
    final s = await _setup({'currentStreak': 4, 'lastPlayedDate': _daysAgo(1), 'freezeCount': 1});
    await s.recordActivity();
    expect(s.currentStreak, 5);
    await s.recordActivity();
    expect(s.currentStreak, 5);
    expect(s.isPlayedToday, isTrue);
    expect(s.shouldCelebrate, isTrue);
  });

  test('1 gün kaçırıldı, hak varsa seri korunur ve hak düşer', () async {
    final s = await _setup({'currentStreak': 10, 'lastPlayedDate': _daysAgo(2), 'freezeCount': 1});
    expect(s.currentStreak, 10);
    expect(s.freezeCount, 0);
    expect(s.isFrozenToday, isTrue);
    expect(s.frozenDays, contains(_daysAgo(1)));
    await s.recordActivity();
    expect(s.currentStreak, 11);
    expect(s.isFrozenToday, isFalse);
  });

  test('kaçırılan gün haktan fazlaysa seri sıfırlanır, geri getirilebilir', () async {
    final s = await _setup({'currentStreak': 12, 'lastPlayedDate': _daysAgo(3), 'freezeCount': 1});
    expect(s.currentStreak, 0);
    expect(s.lostStreak, 12);
    expect(s.canRestoreStreak, isTrue);
    expect(await s.restoreStreakWithAd(), isTrue);
    expect(s.currentStreak, 12);
    expect(s.freezeCount, 1, reason: 'geri getirme bedava donma hakkı vermemeli');
  });

  test('7. günde donma hakkı kazanılır, üst sınır aşılmaz', () async {
    final s = await _setup({'currentStreak': 6, 'lastPlayedDate': _daysAgo(1), 'freezeCount': 1});
    await s.recordActivity();
    expect(s.currentStreak, 7);
    expect(s.freezeCount, 2);
    expect(s.earnedFreezeToday, isTrue);
    expect(await s.addFreeze(), isFalse);
    expect(s.freezeCount, StreakService.maxFreezes);
  });

  test('eski v2 verisindeki 5 donma hakkı yeni sınıra çekilir', () async {
    final s = await _setup({'currentStreak': 3, 'lastPlayedDate': _daysAgo(0), 'freezeCount': 5}, key: 'streak_data_v2');
    expect(s.freezeCount, StreakService.maxFreezes);
    expect(s.currentStreak, 3);
  });

  test('ilk oyun seriyi 1 yapar', () async {
    final s = await _setup({});
    await s.recordActivity();
    expect(s.currentStreak, 1);
    expect(s.activeDays, contains(_daysAgo(0)));
  });
}
