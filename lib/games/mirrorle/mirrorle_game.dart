import 'dart:math';

enum MirrorType { vertical, horizontal, rotate, diagonal }

class MirrorRound {
  final MirrorType type;

  /// Kaynak yarıdaki hücre indeksi → renk (1 veya 2)
  final Map<int, int> source;
  final int colorCount;

  const MirrorRound(this.type, this.source, this.colorCount);
}

/// Mirrorle: kaynak yarıdaki deseni simetri kuralına göre öbür yarıya çiz.
class MirrorleGame {
  static const int n = 6;
  static const int totalRounds = 5;
  static const double maxRoundScore = 20;

  // Kolaydan zora: önce düz aynalar, sonra iki renk, en sonda döndürme ve çapraz (tek renk, az hücre)
  static const _plan = [
    (MirrorType.vertical, 4, 1),
    (MirrorType.horizontal, 5, 1),
    (MirrorType.vertical, 6, 2),
    (MirrorType.rotate, 5, 1),
    (MirrorType.diagonal, 5, 1),
  ];

  /// Her turda desenin görünür kaldığı süre; turlar ilerledikçe kısalır
  static const List<int> viewMs = [12000, 10000, 9000, 8000, 7000];

  final List<MirrorRound> rounds;

  MirrorleGame(Random rng)
      : rounds = [
          for (final (type, cells, colors) in _plan) _make(rng, type, cells, colors),
        ];

  static MirrorRound _make(Random rng, MirrorType type, int cells, int colors) {
    final pool = [
      for (var i = 0; i < n * n; i++)
        if (isSource(type, i)) i,
    ]..shuffle(rng);
    return MirrorRound(type, {
      for (final i in pool.take(cells)) i: colors == 1 ? 1 : 1 + rng.nextInt(2),
    }, colors);
  }

  static bool isSource(MirrorType type, int i) {
    final r = i ~/ n, c = i % n;
    switch (type) {
      case MirrorType.horizontal:
        return r < n ~/ 2;
      case MirrorType.diagonal:
        return r > c;
      default:
        return c < n ~/ 2;
    }
  }

  static bool isTarget(MirrorType type, int i) {
    final r = i ~/ n, c = i % n;
    if (type == MirrorType.diagonal) return r < c;
    return !isSource(type, i);
  }

  /// Kaynak hücrenin hedef yarıdaki karşılığı
  static int mirror(MirrorType type, int i) {
    final r = i ~/ n, c = i % n;
    switch (type) {
      case MirrorType.vertical:
        return r * n + (n - 1 - c);
      case MirrorType.horizontal:
        return (n - 1 - r) * n + c;
      case MirrorType.rotate:
        return (n - 1 - r) * n + (n - 1 - c);
      case MirrorType.diagonal:
        return c * n + r;
    }
  }

  static Map<int, int> expected(MirrorRound round) => {
        for (final e in round.source.entries) mirror(round.type, e.key): e.value,
      };

  /// Hedef yarıdaki yanlış hücre sayısı (eksik, fazla veya yanlış renk)
  static int errors(MirrorRound round, Map<int, int> answer) {
    final exp = expected(round);
    var wrong = 0;
    for (var i = 0; i < n * n; i++) {
      if (!isTarget(round.type, i)) continue;
      if ((exp[i] ?? 0) != (answer[i] ?? 0)) wrong++;
    }
    return wrong;
  }

  static double roundScore(MirrorRound round, Map<int, int> answer) {
    final e = errors(round, answer);
    return max(0, maxRoundScore * (1 - e / round.source.length));
  }
}
