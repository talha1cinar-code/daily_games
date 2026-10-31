import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:daily_games/services/daily_run_service.dart';
import 'package:daily_games/services/leaderboard_service.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:daily_games/services/achievement_service.dart';
import 'package:daily_games/services/score_scale.dart';
import 'package:daily_games/services/stats_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Europe/Istanbul'));
  });

  String key(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String progress(String date, int slot, double score, {bool completed = false}) => jsonEncode({
    'runSlot': slot,
    'dateKey': date,
    'currentGameIndex': 1,
    'scores': {'wordle': score},
    'rawScores': {'wordle': score},
    'durationsMs': {'wordle': 1000},
    'isCompleted': completed,
    'isStarted': true,
    'startedGames': ['wordle'],
  });

  String stat(String date, double score, String slot) => jsonEncode([
    {'date': date, 'isWin': true, 'attempts': 0, 'maxAttempts': 0, 'score': score, 'targetValue': slot},
  ]);

  test('yarım kalan koşu kapanınca geçmişe kendi tarihiyle yazılır', () async {
    final runDate = key(DailyRunService.turkeyNow.subtract(const Duration(days: 2)));
    final runKey = 'daily_run_${runDate}_run1';
    SharedPreferences.setMockInitialValues({'active_run_key': runKey, runKey: progress(runDate, 1, 60)});
    await StatsService().init();
    await DailyRunService().init();
    await Future<void>.delayed(const Duration(milliseconds: 200));

    final runs = StatsService().getStats('daily_run');
    expect(runs.map((s) => s.date), [runDate]);
    expect(runs.single.score, 60);
  });

  test('aynı günün sabah ve akşam koşuları birbirini silmez', () async {
    SharedPreferences.setMockInitialValues({});
    await StatsService().init();
    const day = '2026-10-29';
    await StatsService().saveDailyStat(
      gameId: 'daily_run',
      isWin: true,
      score: 500,
      targetValue: 'Sabah',
      dateKey: day,
    );
    await StatsService().saveDailyStat(gameId: 'daily_run', isWin: true, score: 60, targetValue: 'Akşam', dateKey: day);
    await StatsService().saveDailyStat(gameId: 'daily_run', isWin: true, score: 70, targetValue: 'Akşam', dateKey: day);
    final runs = StatsService().getStats('daily_run');
    expect(runs.map((s) => s.score), [500, 70]);
  });

  test('yanlış tarihli eski kayıt gerçek gününe taşınır, doğrular değişmez', () async {
    const real = '2026-10-29', wrong = '2026-10-31';
    SharedPreferences.setMockInitialValues({
      'daily_run_${real}_run1': progress(real, 1, 60, completed: true),
      'stats_daily_run': stat(wrong, 60, 'Sabah'),
    });
    await StatsService().init();
    await DailyRunService().init();
    expect(StatsService().getStats('daily_run').single.date, real);

    SharedPreferences.setMockInitialValues({
      'daily_run_${wrong}_run1': progress(wrong, 1, 60, completed: true),
      'daily_run_${real}_run1': progress(real, 1, 60, completed: true),
      'stats_daily_run': stat(wrong, 60, 'Sabah'),
    });
    await StatsService().init();
    await DailyRunService().init();
    expect(StatsService().getStats('daily_run').single.date, wrong, reason: 'kendi gününde koşusu olan kayıt taşınmaz');
  });

  group('internet yokken (Firestore onayı hiç gelmez)', () {
    late List<List<String>> commits;

    setUp(() {
      commits = [];
      LeaderboardService.commitOverride = (writes) {
        commits.add([for (final (path, _) in writes) path]);
        return Completer<void>().future;
      };
    });
    tearDown(() => LeaderboardService.commitOverride = null);

    test('son oyun bitince kayıtlar tamamlanır, tüm puanlar kuyruğa girer', () async {
      final today = key(DailyRunService.turkeyNow);
      final slot = DailyRunService.currentRunSlot();
      final runKey = 'daily_run_${today}_run$slot';
      final order = DailyRunService.gameOrderFor(today, slot);
      SharedPreferences.setMockInitialValues({
        // Rozet sesi testte çalınamaz; koşu rozetleri baştan açık sayılır
        for (final id in ['first_run', 'early_bird', 'night_owl', 'no_zero']) 'ach_$id': 'x',
        'active_run_key': runKey,
        runKey: jsonEncode({
          'runSlot': slot,
          'dateKey': today,
          'scores': {for (final id in order.skip(1)) id: 50.0},
          'rawScores': {for (final id in order.skip(1)) id: 50.0},
          'isCompleted': false,
          'isStarted': true,
          'gameOrder': order,
        }),
      });
      await StatsService().init();
      await AchievementService().init();
      await DailyRunService().init();

      await DailyRunService().saveGameScore(order.first, 40, 1000).timeout(const Duration(seconds: 5));

      final expected = 50.0 * (order.length - 1) + ScoreScale.normalize(order.first, 40);
      expect(StatsService().getStats('daily_run').single.score, closeTo(expected, 0.001));
      expect(AchievementService().runsCompleted, 1);
      // Koşunun kendisi + her oyun; her işlem günlük ve haftalık kaydı birlikte taşır
      expect(commits.length, order.length + 1);
      for (final c in commits) {
        expect(c.first, startsWith('leaderboards/'));
        expect(c.last, startsWith('weekly_leaderboards/'));
      }
    });

    test('süresi dolan yarım koşu da takılmadan kaydedilir', () async {
      final runDate = key(DailyRunService.turkeyNow.subtract(const Duration(days: 2)));
      final runKey = 'daily_run_${runDate}_run1';
      SharedPreferences.setMockInitialValues({'active_run_key': runKey, runKey: progress(runDate, 1, 60)});
      await StatsService().init();
      await DailyRunService().init();
      await Future<void>.delayed(const Duration(milliseconds: 200));

      expect(StatsService().getStats('daily_run').single.date, runDate);
      expect(commits.length, 2);
      expect(commits.first.last, contains(LeaderboardService.weekIdFor('daily_run_morning', DateTime.parse(runDate))));
    });
  });

  test('haftalık puan koşunun kendi haftasına yazılır', () {
    expect(LeaderboardService.weekIdFor('x', DateTime.parse('2026-10-25')), 'x_2026_w43');
    expect(LeaderboardService.weekIdFor('x', DateTime.parse('2026-10-26')), 'x_2026_w44');
  });
}
