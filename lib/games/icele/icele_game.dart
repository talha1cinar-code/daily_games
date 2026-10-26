import 'dart:collection';
import 'dart:math';

enum Slide { up, down, left, right }

class IcePuzzle {
  final int size;
  final Set<int> rocks;
  final int start;
  final int goal;

  /// Bilinen en kısa çözüm (BFS)
  final int par;

  const IcePuzzle(this.size, this.rocks, this.start, this.goal, this.par);

  /// Taş [from] konumundan [dir] yönünde kayar; bir kayaya ya da duvara
  /// çarpınca durur. Hedefin üzerinden geçmek yetmez, üstünde durmak gerekir.
  int slide(int from, Slide dir) {
    var r = from ~/ size, c = from % size;
    final (dr, dc) = switch (dir) {
      Slide.up => (-1, 0),
      Slide.down => (1, 0),
      Slide.left => (0, -1),
      Slide.right => (0, 1),
    };
    while (true) {
      final nr = r + dr, nc = c + dc;
      if (nr < 0 || nr >= size || nc < 0 || nc >= size || rocks.contains(nr * size + nc)) break;
      r = nr;
      c = nc;
    }
    return r * size + c;
  }

  /// [start]'tan durulabilecek her hücreye en az hamle sayısı
  static Map<int, int> distances(int size, Set<int> rocks, int start) {
    final probe = IcePuzzle(size, rocks, start, start, 0);
    final dist = <int, int>{start: 0};
    final q = Queue<int>()..add(start);
    while (q.isNotEmpty) {
      final cur = q.removeFirst();
      for (final d in Slide.values) {
        final next = probe.slide(cur, d);
        if (!dist.containsKey(next)) {
          dist[next] = dist[cur]! + 1;
          q.add(next);
        }
      }
    }
    return dist;
  }

  /// En az [minPar] hamle gerektiren, çözülebilir bir bulmaca üretir.
  factory IcePuzzle.generate(Random rng, {required int size, required int minPar}) {
    while (true) {
      final rocks = <int>{};
      final rockCount = (size * size * 0.16).round();
      while (rocks.length < rockCount) {
        rocks.add(rng.nextInt(size * size));
      }
      final free = [for (var i = 0; i < size * size; i++) if (!rocks.contains(i)) i];
      final start = free[rng.nextInt(free.length)];
      final dist = distances(size, rocks, start);
      final best = dist.entries.where((e) => e.value >= minPar).toList()..sort((a, b) => a.key.compareTo(b.key));
      if (best.isEmpty) continue;
      final goal = best[rng.nextInt(best.length)];
      return IcePuzzle(size, rocks, start, goal.key, goal.value);
    }
  }
}

/// Icele: 3 buz bulmacası, büyüyen tahta. Her biri en fazla 33.3 puan.
class IceleGame {
  static const int totalRounds = 3;
  static const double maxRoundScore = 100 / 3;

  final List<IcePuzzle> puzzles;

  IceleGame(Random rng)
      : puzzles = [
          IcePuzzle.generate(rng, size: 6, minPar: 4),
          IcePuzzle.generate(rng, size: 7, minPar: 5),
          IcePuzzle.generate(rng, size: 8, minPar: 6),
        ];

  static double roundScore(int par, int moves, {required bool solved}) {
    if (!solved) return 0;
    return maxRoundScore * par / max(moves, par);
  }
}
