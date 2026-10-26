import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:daily_games/games/countle/countle_game.dart';
import 'package:daily_games/games/balancele/balancele_game.dart';

void main() {
  group('Countle', () {
    test('noktalar üst üste binmez ve istenen sayıda üretilir', () {
      for (var seed = 0; seed < 20; seed++) {
        final game = CountleGame(Random(seed));
        expect(game.rounds.length, CountleGame.totalRounds);
        for (final r in game.rounds) {
          expect(r.answer, greaterThan(0));
          for (var i = 0; i < r.dots.length; i++) {
            for (var j = i + 1; j < r.dots.length; j++) {
              final a = r.dots[i], b = r.dots[j];
              expect(sqrt(pow(a.x - b.x, 2) + pow(a.y - b.y, 2)), greaterThan(a.r + b.r));
            }
          }
        }
      }
    });

    test('son turlarda yalnızca hedef renk sayılır', () {
      final r = CountleGame(Random(3)).rounds.last;
      expect(r.onlyTarget, isTrue);
      expect(r.answer, lessThan(r.dots.length));
    });

    test('puan: tam isabet 20, %30 sapma 0', () {
      expect(CountleGame.roundScore(20, 20), 20);
      expect(CountleGame.roundScore(20, 26), 0);
      expect(CountleGame.roundScore(20, 17), closeTo(10, 0.01));
    });
  });

  group('Balancele', () {
    test('her tur çözülebilir ve oyuncu ağırlıkları olmadan dengede değil', () {
      for (var seed = 0; seed < 40; seed++) {
        for (final r in BalanceleGame(Random(seed)).rounds) {
          expect(BalanceleGame.torqueOf(r.fixed), isNot(0));
          final sol = BalanceleGame.solve(r);
          expect(sol.length, r.tray.length, reason: 'seed $seed');
          expect(BalanceleGame.isBalanced(r, sol), isTrue);
          for (final w in r.fixed) {
            expect(w.kg, inInclusiveRange(1, 9));
            expect(w.pos.abs(), inInclusiveRange(1, BalanceleGame.maxDistance));
          }
        }
      }
    });

    test('aynı seed aynı bulmacayı üretir', () {
      final a = BalanceleGame(Random(9)).rounds.first;
      final b = BalanceleGame(Random(9)).rounds.first;
      expect(a.tray, b.tray);
      expect(a.fixed.map((w) => w.torque).toList(), b.fixed.map((w) => w.torque).toList());
    });
  });
}
