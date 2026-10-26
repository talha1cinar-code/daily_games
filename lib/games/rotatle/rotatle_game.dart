import 'dart:math';
import '../common/grid_shape.dart';

class RotateRound {
  final Cells reference;

  /// 4 seçenek: biri yalnızca döndürülmüş, diğerleri aynalanıp döndürülmüş
  final List<Cells> options;
  final int answer;

  const RotateRound(this.reference, this.options, this.answer);
}

/// Rotatle: şekillerden hangisi referansın yalnızca döndürülmüş hali? (Diğerleri aynalanmış.)
/// 5 tur. Doğru cevap 12 puan + hıza göre 8 puana kadar bonus.
class RotatleGame {
  static const int totalRounds = 5;
  static const double baseScore = 12;
  static const double speedBonus = 8;

  /// Bu sürenin altında tam bonus, üstünde azalır
  static const int fastMs = 2500;
  static const int slowMs = 12000;

  static const _sizes = [5, 6, 7, 8, 9];

  final List<RotateRound> rounds;

  RotatleGame(Random rng) : rounds = [for (final n in _sizes) _make(rng, n)];

  /// Aynası kendisinin bir dönmüş hali olmayan (kiral) rastgele şekil
  static Cells _chiralShape(Random rng, int size) {
    while (true) {
      final cells = <(int, int)>{(0, 0)};
      while (cells.length < size) {
        final (c, r) = cells.elementAt(rng.nextInt(cells.length));
        final d = const [(1, 0), (-1, 0), (0, 1), (0, -1)][rng.nextInt(4)];
        final next = (c + d.$1, r + d.$2);
        // Şekil 4x4'ü aşmasın
        final all = {...cells, next};
        final w = all.map((e) => e.$1).reduce(max) - all.map((e) => e.$1).reduce(min);
        final h = all.map((e) => e.$2).reduce(max) - all.map((e) => e.$2).reduce(min);
        if (w < 4 && h < 4) cells.add(next);
      }
      final s = GridShape.normalize(cells);
      if (GridShape.rotationCanonical(s) != GridShape.rotationCanonical(GridShape.mirror(s))) return s;
    }
  }

  static RotateRound _make(Random rng, int size) {
    final ref = _chiralShape(rng, size);
    final correct = GridShape.rotateTimes(ref, 1 + rng.nextInt(3));
    final mirrored = GridShape.mirror(ref);
    final wrong = <Cells>[];
    final seen = {GridShape.key(correct)};
    for (final k in [0, 1, 2, 3]..shuffle(rng)) {
      final m = GridShape.rotateTimes(mirrored, k);
      if (seen.add(GridShape.key(m))) wrong.add(m);
      if (wrong.length == 3) break;
    }
    final options = [correct, ...wrong]..shuffle(rng);
    return RotateRound(ref, options, options.indexOf(correct));
  }

  static double roundScore(bool correct, int ms) {
    if (!correct) return 0;
    final t = ((ms - fastMs) / (slowMs - fastMs)).clamp(0.0, 1.0);
    return baseScore + speedBonus * (1 - t);
  }
}
