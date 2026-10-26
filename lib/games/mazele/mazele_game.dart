import 'dart:math';

/// Mükemmel labirent (her iki hücre arasında tek yol). Duvarlar hücre başına 4 bit:
/// 1 üst, 2 sağ, 4 alt, 8 sol.
class Maze {
  static const int up = 1, right = 2, down = 4, left = 8;

  final int n;
  final List<int> walls;

  Maze(this.n, this.walls);

  bool hasWall(int cell, int dir) => walls[cell] & dir != 0;

  /// Hareket mümkünse yeni hücre, duvar varsa null
  int? move(int cell, int dir) {
    if (hasWall(cell, dir)) return null;
    final r = cell ~/ n, c = cell % n;
    switch (dir) {
      case up:
        return (r - 1) * n + c;
      case down:
        return (r + 1) * n + c;
      case left:
        return r * n + c - 1;
      default:
        return r * n + c + 1;
    }
  }

  /// Derinlik öncelikli arama ile üretilir
  static Maze generate(Random rng, int n) {
    final walls = List.filled(n * n, up | right | down | left);
    final seen = List.filled(n * n, false);
    final stack = [0];
    seen[0] = true;
    while (stack.isNotEmpty) {
      final cell = stack.last;
      final r = cell ~/ n, c = cell % n;
      final options = <(int, int, int)>[
        if (r > 0 && !seen[cell - n]) (cell - n, up, down),
        if (c < n - 1 && !seen[cell + 1]) (cell + 1, right, left),
        if (r < n - 1 && !seen[cell + n]) (cell + n, down, up),
        if (c > 0 && !seen[cell - 1]) (cell - 1, left, right),
      ];
      if (options.isEmpty) {
        stack.removeLast();
        continue;
      }
      final (next, dir, back) = options[rng.nextInt(options.length)];
      walls[cell] &= ~dir;
      walls[next] &= ~back;
      seen[next] = true;
      stack.add(next);
    }
    return Maze(n, walls);
  }

  /// Başlangıçtan hedefe en kısa yolun uzunluğu (adım)
  int distance(int from, int to) {
    final dist = {from: 0};
    final queue = [from];
    while (queue.isNotEmpty) {
      final cell = queue.removeAt(0);
      if (cell == to) return dist[cell]!;
      for (final d in const [up, right, down, left]) {
        final next = move(cell, d);
        if (next != null && !dist.containsKey(next)) {
          dist[next] = dist[cell]! + 1;
          queue.add(next);
        }
      }
    }
    return -1;
  }
}

class MazeRound {
  final Maze maze;
  final int start;
  final int goal;

  /// Duvarların görünür kaldığı süre
  final int viewMs;

  const MazeRound(this.maze, this.start, this.goal, this.viewMs);
}

/// Mazele: labirenti birkaç saniye ezberle, sonra duvarlar kaybolur ve karanlıkta yürürsün.
/// 4 tur, tur başına 25 puan; her duvara çarpış 5 puan götürür.
class MazeleGame {
  static const int totalRounds = 4;
  static const double maxRoundScore = 25;
  static const double bumpPenalty = 5;

  static const _plan = [(4, 5000), (5, 6000), (5, 5000), (6, 6000)];

  final List<MazeRound> rounds;

  MazeleGame(Random rng)
      : rounds = [
          for (final (n, ms) in _plan) _make(rng, n, ms),
        ];

  static MazeRound _make(Random rng, int n, int ms) {
    final maze = Maze.generate(rng, n);
    // Başlangıç sol alt köşe, hedef sağ üst köşe
    return MazeRound(maze, (n - 1) * n, n - 1, ms);
  }

  static double roundScore(int bumps) => max(0, maxRoundScore - bumps * bumpPenalty);
}
