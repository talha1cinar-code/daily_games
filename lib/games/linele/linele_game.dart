import 'dart:math' hide Point;

class Point {
  final int x;
  final int y;

  const Point(this.x, this.y);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Point && runtimeType == other.runtimeType && x == other.x && y == other.y;

  @override
  int get hashCode => Object.hash(x, y);

  bool isAdjacent(Point other) {
    final dx = (x - other.x).abs();
    final dy = (y - other.y).abs();
    return (dx + dy) == 1;
  }

  @override
  String toString() => '($x,$y)';
}

class Edge {
  final Point p1;
  final Point p2;
  Edge(this.p1, this.p2);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Edge && 
      ((p1 == other.p1 && p2 == other.p2) || (p1 == other.p2 && p2 == other.p1)));

  @override
  int get hashCode => p1.hashCode ^ p2.hashCode; // Symmetric hash
}

class LineleGame {
  final int gridSize;
  final int seed;
  
  // A set of walls between adjacent points. If an Edge is in this set, you cannot move between p1 and p2.
  final Set<Edge> wallEdges;
  
  final Point startPoint;
  final List<Point> exits;

  List<Point> currentPath = [];
  bool isComplete = false;
  bool isWin = false;

  LineleGame._({
    required this.gridSize,
    required this.seed,
    required this.wallEdges,
    required this.startPoint,
    required this.exits,
  });

  /// Build from daily seed
  factory LineleGame.generateMaze({int size = 8, int? seed}) {
    final s = seed ?? DateTime.now().millisecondsSinceEpoch;
    final rng = Random(s);
    
    // We will use a randomized DFS (Recursive Backtracker) to build a perfect maze.
    final Set<Edge> allEdges = {};
    for (int y = 0; y < size; y++) {
      for (int x = 0; x < size; x++) {
        final p = Point(x, y);
        if (x < size - 1) allEdges.add(Edge(p, Point(x + 1, y)));
        if (y < size - 1) allEdges.add(Edge(p, Point(x, y + 1)));
      }
    }

    final Set<Edge> walls = Set.from(allEdges);
    final Set<Point> visited = {};
    final start = Point(rng.nextInt(size), rng.nextInt(size));
    
    void carve(Point current) {
      visited.add(current);
      final dirs = [
        Point(current.x + 1, current.y),
        Point(current.x - 1, current.y),
        Point(current.x, current.y + 1),
        Point(current.x, current.y - 1),
      ];
      dirs.shuffle(rng);
      
      for (final next in dirs) {
        if (next.x >= 0 && next.x < size && next.y >= 0 && next.y < size) {
          if (!visited.contains(next)) {
            // Remove wall between current and next
            walls.remove(Edge(current, next));
            carve(next);
          }
        }
      }
    }
    
    carve(start);

    // Now we have a perfect maze. Let's pick a start and exits.
    // Start at top-left or bottom-left randomly
    final entry = rng.nextBool() ? const Point(0, 0) : Point(0, size - 1);
    
    // Pick 2-3 exits on the right edge or far away
    int numExits = rng.nextInt(2) + 2; // 2 or 3
    List<Point> possibleExits = [];
    for (int y = 0; y < size; y++) {
      for (int x = size ~/ 2; x < size; x++) { // right half
        final p = Point(x, y);
        if (p != entry) possibleExits.add(p);
      }
    }
    possibleExits.shuffle(rng);
    final exits = possibleExits.take(numExits).toList();

    return LineleGame._(
      gridSize: size,
      seed: s,
      wallEdges: walls,
      startPoint: entry,
      exits: exits,
    );
  }

  void reset() {
    currentPath.clear();
    isComplete = false;
    isWin = false;
  }

  /// Returns true if state changed
  bool tapOrDrag(Point p) {
    if (isComplete) return false;
    if (p.x < 0 || p.y < 0 || p.x >= gridSize || p.y >= gridSize) return false;

    if (currentPath.isEmpty) {
      if (p == startPoint) {
        currentPath.add(p);
        _checkState();
        return true;
      }
      return false;
    }

    // No undo! Once visited, we cannot go back.
    if (currentPath.contains(p)) return false;

    final last = currentPath.last;
    if (!last.isAdjacent(p)) return false;

    // Check if there is a wall
    if (wallEdges.contains(Edge(last, p))) return false;

    currentPath.add(p);
    _checkState();
    return true;
  }

  void _checkState() {
    if (currentPath.isEmpty) return;
    
    final last = currentPath.last;
    
    // Check win (reached exit)
    if (exits.contains(last)) {
      isComplete = true;
      isWin = true;
      return;
    }

    // Check dead end
    bool hasValidMoves = false;
    final dirs = [
      Point(last.x + 1, last.y),
      Point(last.x - 1, last.y),
      Point(last.x, last.y + 1),
      Point(last.x, last.y - 1),
    ];
    
    for (final next in dirs) {
      if (next.x >= 0 && next.x < gridSize && next.y >= 0 && next.y < gridSize) {
        if (!currentPath.contains(next) && !wallEdges.contains(Edge(last, next))) {
          hasValidMoves = true;
          break;
        }
      }
    }

    if (!hasValidMoves) {
      // Dead end reached!
      isComplete = true;
      isWin = false;
    }
  }
}
