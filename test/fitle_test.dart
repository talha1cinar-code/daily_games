import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:daily_games/games/fitle/fitle_game.dart';

void main() {
  group('Fitle', () {
    test('aynı seed aynı turları ve cevapları üretir', () {
      final a = FitleGame(Random(3)), b = FitleGame(Random(3));
      expect(a.rounds.length, FitleGame.totalRounds);
      for (var i = 0; i < a.rounds.length; i++) {
        expect(a.rounds[i].shape, b.rounds[i].shape);
        expect(a.rounds[i].answer, b.rounds[i].answer);
      }
    });

    test('cevabın dizilimi geçerlidir: taşma ve üst üste binme yok', () {
      for (var seed = 0; seed < 25; seed++) {
        for (final r in FitleGame(Random(seed)).rounds) {
          expect(r.answer, inInclusiveRange(3, 45), reason: 'seed $seed');
          for (var i = 0; i < r.answer; i++) {
            expect(FitleGame.fits(r.shape, r.packing[i], r.radius), isTrue);
            expect(FitleGame.isFree(r.packing.sublist(0, i), r.packing[i], r.radius), isTrue);
          }
          for (final p in r.shape) {
            expect(p.x, inInclusiveRange(0, 1));
            expect(p.y, inInclusiveRange(0, 1));
          }
        }
      }
    });

    test('ölçek çemberi şeklin içindedir', () {
      for (var seed = 0; seed < 25; seed++) {
        for (final r in FitleGame(Random(seed)).rounds) {
          expect(FitleGame.fits(r.shape, r.sample, r.radius), isTrue);
        }
      }
    });

    const square = <Pt>[Point(0, 0), Point(1, 0), Point(1, 1), Point(0, 1)];

    test('taşan çember sığmaz, içerideki sığar', () {
      expect(FitleGame.fits(square, const Point(0.5, 0.5), 0.1), isTrue);
      expect(FitleGame.fits(square, const Point(0.05, 0.5), 0.1), isFalse);
      expect(FitleGame.fits(square, const Point(1.5, 0.5), 0.1), isFalse);
    });

    // Birim kareye çember yerleştirmede bilinen en büyük yarıçaplar (n: r). Arama sezgisel:
    // çember bu sınırdan %1 küçükken en az n çember bulmalı. Sınıra daha yakın sıkışık
    // durumlarda bir eksik bulabilir (örn. 8 çember, %0,5 payla 7 buluyor).
    const known = {
      1: 0.5,
      2: 0.2929,
      3: 0.2543,
      4: 0.25,
      5: 0.2071,
      6: 0.1876,
      7: 0.1745,
      8: 0.1705,
      9: 0.1667,
      10: 0.1482,
      12: 0.1399,
      16: 0.125,
    };
    for (final e in known.entries) {
      test('karede bilinen sonuç: ${e.key} çember', () {
        final r = e.value * 0.99;
        final found = FitleGame.bestPacking(square, r);
        expect(found.length, greaterThanOrEqualTo(e.key));
        for (var i = 0; i < found.length; i++) {
          expect(FitleGame.fits(square, found[i], r), isTrue);
          expect(FitleGame.isFree(found.sublist(0, i), found[i], r), isTrue);
        }
      });
    }

    test('arka planda üretilen oyun aynı seed ile aynıdır', () {
      expect(FitleGame.fromSeed(5).rounds.first.answer, FitleGame(Random(5)).rounds.first.answer);
    });

    test('sığmayan çember için cevap sıfırdır', () {
      expect(FitleGame.bestPacking(square, 0.6), isEmpty);
    });

    test('puan: tam isabet tam puan, yakınlık arttıkça artar, iki yön de aynı', () {
      expect(FitleGame.roundScore(20, 20), FitleGame.maxRoundScore);
      expect(FitleGame.roundScore(18, 20), FitleGame.roundScore(22, 20));
      expect(FitleGame.roundScore(19, 20), greaterThan(FitleGame.roundScore(17, 20)));
      expect(FitleGame.roundScore(15, 20), closeTo(10, 0.001));
      expect(FitleGame.roundScore(10, 20), 0);
      expect(FitleGame.roundScore(999, 20), 0);
      expect(FitleGame.roundScore(5, 0), 0);
    });
  });
}
