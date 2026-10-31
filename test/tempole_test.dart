import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:daily_games/games/tempole/tempole_game.dart';

void main() {
  group('Tempole', () {
    test('aynı seed aynı ritimleri, 5 turu ve hedefi üretir', () {
      final a = TempoleGame(Random(7)), b = TempoleGame(Random(7));
      expect(a.rounds.length, TempoleGame.totalRounds);
      for (var i = 0; i < a.rounds.length; i++) {
        expect(a.rounds[i].target, b.rounds[i].target);
        expect(a.rounds[i].target.first, 0);
      }
    });

    test('tekrar turlarında ritim sabit tempo değildir, süre makul', () {
      for (var seed = 0; seed < 100; seed++) {
        for (final r in TempoleGame(Random(seed)).rounds.where((r) => r.type == TempoRoundType.repeat)) {
          final gaps = [for (var i = 1; i < r.target.length; i++) r.target[i] - r.target[i - 1]];
          expect(gaps.toSet().length, greaterThan(1));
          expect(gaps.every((g) => g > 0), isTrue);
          expect(r.target.last, lessThan(6000));
        }
      }
    });

    test('tempo koruma turunda dinlenenden fazla vuruş istenir', () {
      final r = TempoleGame(Random(1)).rounds.first;
      expect(r.type, TempoRoundType.keep);
      expect(r.target.length, greaterThan(r.listen.length));
      expect(r.target.sublist(0, r.listen.length), r.listen);
    });

    const round = TempoRound(TempoRoundType.repeat, [0, 300, 600], [0, 300, 600]);

    test('kusursuz dokunuş tam puan; geç başlamak puanı etkilemez', () {
      expect(TempoleGame.roundScore(round, [5000, 5300, 5600]), TempoleGame.maxRoundScore);
      expect(TempoleGame.roundScore(round, [90000, 90330, 90620]), TempoleGame.maxRoundScore);
    });

    test('sapma arttıkça puan düşer, sınırda biter', () {
      final mid = TempoleGame.roundScore(round, [0, 400, 700]);
      expect(mid, greaterThan(0));
      expect(mid, lessThan(TempoleGame.maxRoundScore));
      expect(TempoleGame.roundScore(round, [0, 600, 1000]), 0);
    });

    test('eksik vuruş cezalıdır, hiç dokunmamak sıfırdır', () {
      expect(TempoleGame.roundScore(round, [0, 300]), lessThan(TempoleGame.maxRoundScore));
      expect(TempoleGame.roundScore(round, [0]), 0);
      expect(TempoleGame.roundScore(round, []), 0);
      expect(TempoleGame.averageError(round, []), isNull);
    });

    test('küçük insan hatası tam puan, 100 ms sapma hâlâ iyi puan', () {
      expect(TempoleGame.roundScore(round, [0, 350, 650]), TempoleGame.maxRoundScore);
      expect(TempoleGame.roundScore(round, [0, 400, 700]), greaterThan(14));
    });

    test('tempo koruma daha toleranslıdır', () {
      const keep = TempoRound(TempoRoundType.keep, [0, 300], [0, 300, 600]);
      expect(TempoleGame.roundScore(keep, [0, 500, 800]), greaterThan(TempoleGame.roundScore(round, [0, 500, 800])));
    });
  });
}
