import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:daily_games/games/slicele/slicele_game.dart';
import 'package:daily_games/games/stackle/stackle_game.dart';
import 'package:daily_games/games/mirrorle/mirrorle_game.dart';
import 'package:daily_games/models/game_model.dart';
import 'package:daily_games/services/daily_challenge_service.dart';
import 'package:daily_games/services/daily_run_service.dart';
import 'package:daily_games/services/score_scale.dart';

void main() {
  group('Slicele', () {
    const square = [Offset(-1, -1), Offset(1, -1), Offset(1, 1), Offset(-1, 1)];

    test('kareyi ortadan dikey kesmek %50 verir', () {
      final r = SliceleGame.slice(square, const Offset(0, -5), const Offset(0, 5))!;
      expect(r.percentA, closeTo(50, 1e-9));
    });

    test('çeyrek kesim %25 verir', () {
      final r = SliceleGame.slice(square, const Offset(-0.5, -5), const Offset(-0.5, 5))!;
      expect(r.smallerPercent, closeTo(25, 1e-9));
    });

    test('şekli ıskalayan çizgi null döner', () {
      expect(SliceleGame.slice(square, const Offset(3, -5), const Offset(3, 5)), isNull);
    });

    test('içbükey yıldızda iki parçanın alanı toplamı tüm alana eşit', () {
      final star = SliceleGame(Random(9)).rounds[1].shape;
      final r = SliceleGame.slice(star, const Offset(-2, 0.1), const Offset(2, -0.2))!;
      final total = SliceleGame.area(star);
      expect(SliceleGame.area(r.pieceA) + SliceleGame.area(r.pieceB), closeTo(total, 1e-9));
    });

    test('puanlama: tam isabet 20, 10 puan sapma 0', () {
      expect(SliceleGame.roundScore(50, 50), 20);
      expect(SliceleGame.roundScore(40, 50), 0);
      expect(SliceleGame.roundScore(24, 25), 18);
    });

    test('aynı seed aynı şekilleri üretir', () {
      expect(SliceleGame(Random(4)).rounds[2].shape, SliceleGame(Random(4)).rounds[2].shape);
    });
  });

  group('Stackle', () {
    test('mükemmel yerleşim genişliği korur', () {
      final g = StackleGame();
      final r = g.place(g.top.left + 0.005);
      expect(r.outcome, PlaceOutcome.perfect);
      expect(g.top.width, StackleGame.baseWidth);
      expect(g.floors, 1);
    });

    test('kaydırılmış yerleşim taşan kısmı keser', () {
      final g = StackleGame();
      final left = g.top.left;
      final r = g.place(left + 0.1);
      expect(r.outcome, PlaceOutcome.placed);
      expect(g.top.width, closeTo(StackleGame.baseWidth - 0.1, 1e-9));
      expect(r.chunk!.left, closeTo(left + StackleGame.baseWidth, 1e-9));
      expect(r.chunk!.width, closeTo(0.1, 1e-9));
    });

    test('tamamen ıskalamak oyunu bitirir', () {
      final g = StackleGame();
      expect(g.place(0.95).outcome, PlaceOutcome.miss);
      expect(g.isOver, isTrue);
    });

    test('3 mükemmel üst üste bloğu büyütür', () {
      final g = StackleGame();
      g.place(g.top.left + 0.1); // daralt
      final narrow = g.top.width;
      for (var i = 0; i < 3; i++) {
        g.place(g.top.left);
      }
      expect(g.top.width, greaterThan(narrow));
    });
  });

  group('Mirrorle', () {
    test('ayna eşlemesi kaynaktan hedefe gider ve kendi tersidir', () {
      for (final type in MirrorType.values) {
        for (var i = 0; i < MirrorleGame.n * MirrorleGame.n; i++) {
          if (!MirrorleGame.isSource(type, i)) continue;
          final m = MirrorleGame.mirror(type, i);
          expect(MirrorleGame.isTarget(type, m), isTrue, reason: '$type $i');
          expect(MirrorleGame.mirror(type, m), i, reason: '$type $i');
        }
      }
    });

    test('doğru cevap tam puan, boş cevap 0 puan', () {
      for (final round in MirrorleGame(Random(2)).rounds) {
        expect(MirrorleGame.roundScore(round, MirrorleGame.expected(round)), MirrorleGame.maxRoundScore);
        expect(MirrorleGame.roundScore(round, {}), 0);
      }
    });
  });

  group('Daily Run', () {
    test('sabit hash platformdan bağımsız bilinen değeri verir', () {
      expect(DailyChallengeService.stableHash('a'), 0xe40c292c);
    });

    test('rotasyon deterministik, tekrarsız ve havuzdan', () {
      final a = DailyRunService.gameOrderFor('2026-10-25', 1);
      expect(a, DailyRunService.gameOrderFor('2026-10-25', 1));
      expect(a.length, DailyRunService.gamesPerRun);
      expect(a.toSet().length, a.length);
      expect(DailyRunService.gamePool, containsAll(a));
      expect(a, isNot(DailyRunService.gameOrderFor('2026-10-25', 2)));
    });

    test('havuzdaki her oyun listede ve ad haritasında var', () {
      final ids = games.map((g) => g.id).toSet();
      for (final id in DailyRunService.gamePool) {
        expect(ids, contains(id));
        expect(DailyRunService.gameDisplayNames, contains(id));
      }
      expect(DailyRunService.gamePool.toSet(), ids);
    });

    test('normalize puan 0-100 aralığında', () {
      expect(ScoreScale.normalize('wikitrivia', 100), 100);
      expect(ScoreScale.normalize('huedle', 5000), 100);
      expect(ScoreScale.normalize('rgble', 15), 50);
      expect(ScoreScale.normalize('slicele', -3), 0);
    });
  });
}
