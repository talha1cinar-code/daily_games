import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:daily_games/games/anglele/anglele_game.dart';
import 'package:daily_games/games/dropple/dropple_game.dart';
import 'package:daily_games/games/icele/icele_game.dart';

void main() {
  group('Anglele', () {
    test('açılar beklenen aralıklarda, son tur içbükey', () {
      for (var seed = 0; seed < 50; seed++) {
        final r = AngleleGame(Random(seed)).rounds;
        expect(r[0].angle, inInclusiveRange(15, 84));
        expect(r[4].angle, greaterThan(180));
      }
    });

    test('puan: tam isabet 20, 30 derece sapma 0', () {
      expect(AngleleGame.roundScore(90, 90), 20);
      expect(AngleleGame.roundScore(90, 120), 0);
      expect(AngleleGame.roundScore(90, 75), 10);
    });
  });

  group('Icele', () {
    test('üretilen bulmacalar BFS ile tam par hamlede çözülür', () {
      for (var seed = 0; seed < 20; seed++) {
        for (final p in IceleGame(Random(seed)).puzzles) {
          final d = IcePuzzle.distances(p.size, p.rocks, p.start);
          expect(d[p.goal], p.par);
          expect(p.rocks.contains(p.start) || p.rocks.contains(p.goal), isFalse);
        }
      }
    });

    test('kayma kayaya çarpınca durur', () {
      const p = IcePuzzle(5, {12}, 10, 0, 0); // satır 2: kaya (2,2)
      expect(p.slide(10, Slide.right), 11);
      expect(p.slide(10, Slide.up), 0);
    });
  });

  group('Dropple', () {
    test('turlar deterministik ve iniş noktası ekranın içinde', () {
      final a = DroppleGame(Random(3)).rounds;
      final b = DroppleGame(Random(3)).rounds;
      for (var i = 0; i < a.length; i++) {
        expect(a[i].landingX, b[i].landingX);
        expect(a[i].landingX, inInclusiveRange(0.08, 0.92));
      }
    });

    test('rampalı turlar en az bir rampaya çarpar', () {
      for (var seed = 0; seed < 10; seed++) {
        final rounds = DroppleGame(Random(seed)).rounds;
        for (final r in rounds.where((r) => r.ramps.isNotEmpty)) {
          final sim = DroppleGame.simulate(r.launch, r.velocity, r.ramps)!;
          expect(sim.$3, greaterThan(0));
        }
      }
    });

    test('puan: tam isabet 20, genişliğin %30u kadar sapma 0', () {
      expect(DroppleGame.roundScore(0.5, 0.5), 20);
      expect(DroppleGame.roundScore(0.5, 0.8), closeTo(0, 1e-9));
    });
  });
}
