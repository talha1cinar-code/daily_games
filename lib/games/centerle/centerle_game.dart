import 'dart:math';

enum CenterType { segment, circle, square, arc, threePoints }

/// Bir tur: alan 0-1 koordinatlı bir karedir. [center] bulunması gereken nokta.
class CenterRound {
  final CenterType type;
  final Point<double> center;

  /// segment: iki uç; square: dört köşe; threePoints: üç nokta
  final List<Point<double>> points;
  final double radius;

  /// arc: yayın başlangıç açısı ve süpürme açısı (radyan)
  final double arcStart, arcSweep;

  const CenterRound(this.type, this.center, {this.points = const [], this.radius = 0, this.arcStart = 0, this.arcSweep = 0});
}

/// Centerle: gözle tam merkezi bul. 5 tur, tur başına en fazla 20 puan.
/// Sapma alan kenarının %8'ine ulaşınca tur puanı sıfırlanır.
class CenterleGame {
  static const int totalRounds = 5;
  static const double maxRoundScore = 20;
  static const double zeroAt = 0.08;

  static const _plan = [CenterType.segment, CenterType.circle, CenterType.square, CenterType.arc, CenterType.threePoints];

  final List<CenterRound> rounds;

  CenterleGame(Random rng) : rounds = [for (final t in _plan) _make(rng, t)];

  static double _in(Random rng, double lo, double hi) => lo + rng.nextDouble() * (hi - lo);

  static CenterRound _make(Random rng, CenterType type) {
    switch (type) {
      case CenterType.segment:
        // Yarım uzunluk en fazla 0.3: uçlar alanın içinde kalır
        final c = Point(_in(rng, 0.32, 0.68), _in(rng, 0.32, 0.68));
        final len = _in(rng, 0.18, 0.3);
        final a = rng.nextDouble() * pi;
        final d = Point(cos(a) * len, sin(a) * len);
        return CenterRound(type, c, points: [c + d, c - d]);
      case CenterType.circle:
        final r = _in(rng, 0.15, 0.3);
        final c = Point(_in(rng, r + 0.05, 0.95 - r), _in(rng, r + 0.05, 0.95 - r));
        return CenterRound(type, c, radius: r);
      case CenterType.square:
        final h = _in(rng, 0.14, 0.24);
        final m = h * sqrt2 + 0.04;
        final c = Point(_in(rng, m, 1 - m), _in(rng, m, 1 - m));
        final a = rng.nextDouble() * pi / 2;
        return CenterRound(type, c, points: [
          for (var k = 0; k < 4; k++) c + Point(cos(a + k * pi / 2) * h * sqrt2, sin(a + k * pi / 2) * h * sqrt2),
        ]);
      case CenterType.arc:
        final r = _in(rng, 0.22, 0.32);
        final c = Point(_in(rng, r + 0.04, 0.96 - r), _in(rng, r + 0.04, 0.96 - r));
        return CenterRound(type, c, radius: r, arcStart: rng.nextDouble() * 2 * pi, arcSweep: _in(rng, 1.7, 2.4));
      case CenterType.threePoints:
        final r = _in(rng, 0.2, 0.3);
        final c = Point(_in(rng, r + 0.05, 0.95 - r), _in(rng, r + 0.05, 0.95 - r));
        // Noktalar birbirine çok yakın olmasın (aralarında en az 70°)
        final base = rng.nextDouble() * 2 * pi;
        final a2 = base + _in(rng, 1.2, 2.2);
        final a3 = a2 + _in(rng, 1.2, 2 * pi - (a2 - base) - 1.2);
        return CenterRound(type, c, radius: r, points: [
          for (final a in [base, a2, a3]) c + Point(cos(a) * r, sin(a) * r),
        ]);
    }
  }

  static double roundScore(Point<double> actual, Point<double> guess) =>
      max(0, maxRoundScore * (1 - actual.distanceTo(guess) / zeroAt));
}
