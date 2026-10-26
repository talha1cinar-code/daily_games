import 'dart:math';

class CountDot {
  /// Alan içindeki konum (0-1)
  final double x, y;

  /// Yarıçap, alanın kısa kenarına oranla
  final double r;

  /// 0: sayılacak renk, 1: dikkat dağıtıcı renk
  final int color;

  const CountDot(this.x, this.y, this.r, this.color);
}

class CountRound {
  final List<CountDot> dots;

  /// Noktaların ekranda kaldığı süre
  final int flashMs;

  /// true ise yalnızca hedef renkteki noktalar sayılır
  final bool onlyTarget;

  const CountRound(this.dots, this.flashMs, this.onlyTarget);

  int get answer => onlyTarget ? dots.where((d) => d.color == 0).length : dots.length;
}

/// Countle: bir an görünen noktaları say. 5 tur, tur başına en fazla 20 puan.
class CountleGame {
  static const int totalRounds = 5;
  static const double maxRoundScore = 20;

  /// Bu orandaki sapmada (%30) tur puanı sıfırlanır
  static const double zeroAt = 0.3;

  // (en az, en çok, süre ms, yalnızca hedef renk, dikkat dağıtıcı sayısı)
  static const _plan = [
    (7, 12, 1500, false, 0),
    (13, 20, 1300, false, 0),
    (20, 30, 1100, false, 0),
    (9, 16, 1300, true, 8),
    (18, 28, 1100, true, 12),
  ];

  final List<CountRound> rounds;

  CountleGame(Random rng)
      : rounds = [
          for (final (lo, hi, ms, only, extra) in _plan) _make(rng, lo + rng.nextInt(hi - lo + 1), ms, only, extra),
        ];

  static CountRound _make(Random rng, int count, int ms, bool only, int distractors) {
    final dots = <CountDot>[];
    final total = count + distractors;
    var guard = 0;
    while (dots.length < total && guard++ < 20000) {
      final r = 0.032 + rng.nextDouble() * 0.024;
      final x = r + rng.nextDouble() * (1 - 2 * r);
      final y = r + rng.nextDouble() * (1 - 2 * r);
      // Noktalar üst üste binmesin; aralarında küçük bir boşluk kalsın
      final clash = dots.any((d) => pow(d.x - x, 2) + pow(d.y - y, 2) < pow(d.r + r + 0.012, 2));
      if (clash) continue;
      dots.add(CountDot(x, y, r, dots.length < count ? 0 : 1));
    }
    dots.shuffle(rng);
    return CountRound(dots, ms, only);
  }

  static double roundScore(int actual, int guess) {
    final err = (actual - guess).abs() / actual;
    return max(0, maxRoundScore * (1 - err / zeroAt));
  }
}
