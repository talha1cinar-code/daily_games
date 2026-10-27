import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:daily_games/games/wikitrivia/wikitrivia_data.dart';
import 'package:daily_games/games/wikitrivia/wikitrivia_game.dart';

void main() {
  group('Wikitrivia', () {
    test('deste aralıklı yıllardan oluşur', () {
      for (var seed = 0; seed < 30; seed++) {
        final g = WikitriviaGame(defaultHistoricalEventsTr, Random(seed));
        expect(g.deckTotal, WikitriviaGame.deckSize);
        expect(g.timeline.length, 1);
        final years = <int>[g.timeline.first.year];
        while (g.currentCard != null) {
          years.add(g.currentCard!.year);
          g.place(g.correctSlotFor(g.currentCard!));
        }
        for (var i = 0; i < years.length; i++) {
          for (var j = i + 1; j < years.length; j++) {
            expect((years[i] - years[j]).abs(), greaterThanOrEqualTo(WikitriviaGame.minGapYears));
          }
        }
        expect(g.score, 100);
        expect(g.isPerfect, isTrue);
      }
    });

    test('aynı yıl iki yanda da doğru, zaman çizelgesi sıralı kalır', () {
      final g = WikitriviaGame(const [
        HistoricalEvent(title: 'a', year: 1900),
        HistoricalEvent(title: 'b', year: 1950),
      ], Random(1));
      final t = g.timeline.first;
      expect(g.fitsSlot(HistoricalEvent(title: 'x', year: t.year), 0), isTrue);
      expect(g.fitsSlot(HistoricalEvent(title: 'x', year: t.year), 1), isTrue);
    });

    test('3 yanlışta oyun biter, yanlış kart doğru yere konur', () {
      final g = WikitriviaGame(defaultHistoricalEventsTr, Random(3));
      while (!g.isGameOver) {
        final c = g.currentCard!;
        final good = g.correctSlotFor(c);
        final bad = good == 0 ? g.timeline.length : 0;
        final info = g.place(bad);
        expect(info.isCorrect, isFalse);
        expect(info.index, good);
      }
      expect(g.wrong, WikitriviaGame.maxLives);
      expect(g.score, 0);
      final ys = g.timeline.map((e) => e.year).toList();
      expect(ys, [...ys]..sort());
    });

    test('İngilizce havuz da deste kurmaya yeter', () {
      expect(defaultHistoricalEventsEn.length, greaterThan(100));
      final g = WikitriviaGame(defaultHistoricalEventsEn, Random(7));
      expect(g.deckTotal, WikitriviaGame.deckSize);
    });

    test('MÖ yılları', () {
      expect(WikitriviaGame.formatYear(-500, true), 'MÖ 500');
      expect(WikitriviaGame.formatYear(1453, false), '1453');
    });
  });
}
