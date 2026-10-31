import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:daily_games/services/personal_best_service.dart';
import 'package:daily_games/services/score_scale.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('eski puan bitirilen seviyeye göre çevrilir', () {
    expect(ScoreScale.migrateLevelScore('huedle', 625), 100);
    expect(ScoreScale.migrateLevelScore('huedle', 150), 50);
    expect(ScoreScale.migrateLevelScore('huedle', 10), 10);
    expect(ScoreScale.migrateLevelScore('huedle', 0), 0);
    expect(ScoreScale.migrateLevelScore('huedle', 900), 110, reason: '10. seviyeyi geçenler de karşılığını alır');
    expect(ScoreScale.migrateLevelScore('memorle', 575), 100);
    expect(ScoreScale.migrateLevelScore('memorle', 261), 60);
    expect(ScoreScale.migrateLevelScore('memorle', 332), 70);
    expect(ScoreScale.migrateLevelScore('memorle', 30), 10);
  });

  test('Daily Run toplamında oyun başına en fazla 100 sayılır', () {
    expect(ScoreScale.normalize('huedle', 150), 100);
    expect(ScoreScale.normalize('memorle', 70), 70);
  });

  test('rekor ve geçmiş bir kez çevrilir, ikinci açılışta değişmez', () async {
    SharedPreferences.setMockInitialValues({
      'pb_huedle': 625.0,
      'pb_memorle': 332.0,
      'pb_wordle': 90.0,
      'stats_huedle': jsonEncode([
        {'date': '2026-10-27', 'isWin': true, 'score': 150.0},
      ]),
    });
    await PersonalBestService().init();
    final p = await SharedPreferences.getInstance();
    expect(PersonalBestService().best('huedle'), 100);
    expect(PersonalBestService().best('memorle'), 70);
    expect(PersonalBestService().best('wordle'), 90, reason: 'diğer oyunlara dokunulmaz');
    expect((jsonDecode(p.getString('stats_huedle')!) as List).single['score'], 50);

    await PersonalBestService().init();
    expect(PersonalBestService().best('memorle'), 70, reason: '70 tekrar çevrilip 30e düşmemeli');
    expect((jsonDecode(p.getString('stats_huedle')!) as List).single['score'], 50);
  });
}
