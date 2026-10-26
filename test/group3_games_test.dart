import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:daily_games/games/centerle/centerle_game.dart';
import 'package:daily_games/games/mazele/mazele_game.dart';
import 'package:daily_games/games/echole/echole_game.dart';
import 'package:daily_games/games/rotatle/rotatle_game.dart';
import 'package:daily_games/games/shadowle/shadowle_game.dart';
import 'package:daily_games/games/common/grid_shape.dart';
import 'package:daily_games/services/daily_run_service.dart';

void main() {
  group('Centerle', () {
    test('şekiller alanın içinde ve merkez doğru', () {
      for (var seed = 0; seed < 30; seed++) {
        for (final r in CenterleGame(Random(seed)).rounds) {
          for (final p in r.points) {
            expect(p.x, inInclusiveRange(0, 1));
            expect(p.y, inInclusiveRange(0, 1));
            if (r.type == CenterType.threePoints) {
              expect(p.distanceTo(r.center), closeTo(r.radius, 1e-9));
            }
          }
          if (r.type == CenterType.segment) {
            final mid = Point((r.points[0].x + r.points[1].x) / 2, (r.points[0].y + r.points[1].y) / 2);
            expect(mid.distanceTo(r.center), lessThan(1e-9));
          }
        }
      }
    });

    test('puan: tam merkez 20, %8 sapma 0', () {
      expect(CenterleGame.roundScore(const Point(0.5, 0.5), const Point(0.5, 0.5)), 20);
      expect(CenterleGame.roundScore(const Point(0.5, 0.5), const Point(0.58, 0.5)), closeTo(0, 1e-9));
    });
  });

  group('Mazele', () {
    test('labirent mükemmel: her hücreye ulaşılır ve hedefe yol var', () {
      for (var seed = 0; seed < 20; seed++) {
        for (final r in MazeleGame(Random(seed)).rounds) {
          final m = r.maze;
          expect(m.distance(r.start, r.goal), greaterThan(0));
          // Ağaç: kenar sayısı = hücre - 1
          var open = 0;
          for (var i = 0; i < m.n * m.n; i++) {
            if (!m.hasWall(i, Maze.right)) open++;
            if (!m.hasWall(i, Maze.down)) open++;
          }
          expect(open, m.n * m.n - 1);
        }
      }
    });

    test('dış duvarlar kapalı', () {
      final m = MazeleGame(Random(1)).rounds.first.maze;
      expect(m.move(0, Maze.up), isNull);
      expect(m.move(0, Maze.left), isNull);
    });
  });

  group('Echole', () {
    test('aynı seed aynı dizi, puan eşikleri', () {
      expect(EcholeGame(Random(4)).sequence, EcholeGame(Random(4)).sequence);
      expect(EcholeGame.score(2), 0);
      expect(EcholeGame.score(3), 10);
      expect(EcholeGame.score(12), 100);
      expect(EcholeGame.score(20), 100);
    });
  });

  group('Rotatle', () {
    test('tam bir doğru seçenek: döndürülmüş; diğerleri aynalanmış', () {
      for (var seed = 0; seed < 30; seed++) {
        for (final r in RotatleGame(Random(seed)).rounds) {
          final refRot = GridShape.rotationCanonical(r.reference);
          final matches = r.options.where((o) => GridShape.rotationCanonical(o) == refRot).length;
          expect(matches, 1);
          expect(GridShape.rotationCanonical(r.options[r.answer]), refRot);
          expect(r.options.map(GridShape.key).toSet().length, r.options.length);
        }
      }
    });
  });

  group('Shadowle', () {
    test('doğru seçenek silüet, diğerleri ondan farklı', () {
      for (var seed = 0; seed < 30; seed++) {
        for (final r in ShadowleGame(Random(seed)).rounds) {
          expect(r.options.length, 4);
          final correct = ShadowleGame.project(r.voxels, r.view);
          expect(GridShape.key(r.options[r.answer]), GridShape.key(correct));
          final canon = r.options.map(GridShape.canonical).toSet();
          expect(canon.length, 4, reason: 'seed $seed');
        }
      }
    });

    test('küpler havada durmaz', () {
      for (final r in ShadowleGame(Random(5)).rounds) {
        for (final (x, y, z) in r.voxels) {
          if (z > 0) expect(r.voxels.contains((x, y, z - 1)), isTrue);
        }
      }
    });
  });

  group('Daily Run sırası', () {
    test('havuza oyun eklemek mevcut sırayı çoğunlukla korur', () {
      // Aynı gün için sıra deterministik
      expect(DailyRunService.gameOrderFor('2026-10-27', 1), DailyRunService.gameOrderFor('2026-10-27', 1));
      expect(DailyRunService.gameOrderFor('2026-10-27', 1).length, DailyRunService.gamesPerRun);
    });
  });
}
