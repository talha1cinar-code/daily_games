import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:daily_games/games/quickle/quickle_game.dart';

void main() {
  group('Quickle', () {
    test('aynı seed aynı soru dizisini üretir', () {
      final a = QuickleGame(Random(3)).questions.map((q) => q.text).toList();
      final b = QuickleGame(Random(3)).questions.map((q) => q.text).toList();
      expect(a, b);
    });

    test('cevaplar pozitif tam sayı ve en fazla 4 basamak', () {
      for (var seed = 0; seed < 100; seed++) {
        for (final q in QuickleGame(Random(seed)).questions) {
          expect(q.answer, greaterThan(0), reason: q.text);
          expect(q.answer.toString().length, lessThanOrEqualTo(4), reason: q.text);
        }
      }
    });

    test('doğru cevap puan ve seri getirir, yanlış seriyi sıfırlar', () {
      final game = QuickleGame(Random(5));
      final first = game.current;
      expect(game.submit(first.answer), isTrue);
      expect(game.points, first.points);
      expect(game.streak, 1);
      expect(game.submit(-1), isFalse);
      expect(game.streak, 0);
      expect(game.wrong, 1);
    });

    test('yanlış yapan 100 alamaz', () {
      final game = QuickleGame(Random(5));
      game.points = QuickleGame.fullPoints;
      expect(game.score, 100);
      game.wrong = 1;
      expect(game.score, lessThan(100));
    });
  });
}

