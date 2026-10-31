import 'dart:math';

typedef Pt = Point<double>;

class FitRound {
  /// 0-1 alanına sığdırılmış şekil
  final List<Pt> shape;
  final double radius;

  /// Şekle sığdırabildiğimiz en kalabalık dizilim; uzunluğu turun doğru cevabıdır
  final List<Pt> packing;

  const FitRound(this.shape, this.radius, this.packing);

  int get answer => packing.length;

  /// Ölçek için gösterilen tek çember: şeklin ortasına en yakın olan
  Pt get sample {
    const center = Point(0.5, 0.5);
    return packing.reduce((a, b) => a.distanceTo(center) <= b.distanceTo(center) ? a : b);
  }
}

/// Fitle: şekli ve içindeki tek çemberi gör, bu çemberden en fazla kaç tane sığacağını tahmin et.
/// Her turda tek tahmin; puan yakınlığa göre. 5 tur, tur başına en fazla 20 puan.
class FitleGame {
  static const int totalRounds = 5;
  static const double maxRoundScore = 20;

  /// Cevaptan bu oranda uzak tahmin 0 puan alır
  static const double zeroAtError = 0.5;

  /// Turda hedeflenen çember sayısı aralığı; cevap turun sırasından tahmin edilemesin
  static const List<(int, int)> _plan = [(5, 8), (8, 12), (12, 17), (16, 22), (20, 28)];

  /// Düzenli dizilimde çemberlerin şekil alanının yaklaşık kaçını doldurduğu
  static const double _fillRatio = 0.7;

  final List<FitRound> rounds;

  FitleGame(Random rng) : rounds = _build(rng);

  /// Arka planda üretmek için: dizilim araması ekranı takılacak kadar sürebilir
  static FitleGame fromSeed(int seed) => FitleGame(Random(seed));

  static List<FitRound> _build(Random rng) {
    final shapes = [..._shapes]..shuffle(rng);
    return [
      for (var i = 0; i < totalRounds; i++)
        () {
          final (low, high) = _plan[i];
          final count = low + rng.nextInt(high - low + 1);
          final shape = _fit(shapes[i % shapes.length], rng.nextDouble() * 2 * pi);
          final radius = sqrt(_area(shape) * _fillRatio / (count * pi));
          return FitRound(shape, radius, bestPacking(shape, radius, rng));
        }(),
    ];
  }

  // ─── Şekiller ────────────────────────────────────────────────────
  static List<Pt> _regular(int sides) => [
    for (var i = 0; i < sides; i++) Point(cos(i * 2 * pi / sides), sin(i * 2 * pi / sides)),
  ];

  static List<Pt> _star(int points, double inner) => [
    for (var i = 0; i < points * 2; i++)
      Point(cos(i * pi / points) * (i.isEven ? 1 : inner), sin(i * pi / points) * (i.isEven ? 1 : inner)),
  ];

  static final List<List<Pt>> _shapes = [
    _regular(48), // daire
    _regular(6),
    _regular(3),
    _regular(4),
    _star(5, 0.62),
    const [Point(0, 0), Point(1, 0), Point(1, 0.45), Point(0.45, 0.45), Point(0.45, 1), Point(0, 1)], // L
    const [
      Point(0.33, 0),
      Point(0.67, 0),
      Point(0.67, 0.33),
      Point(1, 0.33),
      Point(1, 0.67),
      Point(0.67, 0.67),
      Point(0.67, 1),
      Point(0.33, 1),
      Point(0.33, 0.67),
      Point(0, 0.67),
      Point(0, 0.33),
      Point(0.33, 0.33),
    ], // artı
  ];

  /// Şekli döndürür, oranını bozmadan alana sığdırır ve ortalar
  static List<Pt> _fit(List<Pt> shape, double angle) {
    final c = cos(angle), s = sin(angle);
    final turned = [for (final p in shape) Point(p.x * c - p.y * s, p.x * s + p.y * c)];
    final xs = turned.map((p) => p.x), ys = turned.map((p) => p.y);
    final minX = xs.reduce(min), maxX = xs.reduce(max), minY = ys.reduce(min), maxY = ys.reduce(max);
    final scale = 0.9 / max(maxX - minX, maxY - minY);
    final dx = 0.5 - (minX + maxX) / 2 * scale, dy = 0.5 - (minY + maxY) / 2 * scale;
    return [for (final p in turned) Point(p.x * scale + dx, p.y * scale + dy)];
  }

  // ─── Geometri ────────────────────────────────────────────────────
  static double _area(List<Pt> shape) {
    var sum = 0.0;
    for (var i = 0, j = shape.length - 1; i < shape.length; j = i++) {
      sum += shape[j].x * shape[i].y - shape[i].x * shape[j].y;
    }
    return sum.abs() / 2;
  }

  static bool _inside(List<Pt> shape, Pt p) {
    var inside = false;
    for (var i = 0, j = shape.length - 1; i < shape.length; j = i++) {
      final a = shape[i], b = shape[j];
      if ((a.y > p.y) != (b.y > p.y) && p.x < (b.x - a.x) * (p.y - a.y) / (b.y - a.y) + a.x) inside = !inside;
    }
    return inside;
  }

  static double _edgeDistance(Pt p, Pt a, Pt b) {
    final dx = b.x - a.x, dy = b.y - a.y;
    final t = (((p.x - a.x) * dx + (p.y - a.y) * dy) / (dx * dx + dy * dy)).clamp(0.0, 1.0);
    return p.distanceTo(Point(a.x + t * dx, a.y + t * dy));
  }

  /// Çember tamamen şeklin içinde mi?
  static bool fits(List<Pt> shape, Pt c, double r) {
    if (!_inside(shape, c)) return false;
    for (var i = 0, j = shape.length - 1; i < shape.length; j = i++) {
      if (_edgeDistance(c, shape[i], shape[j]) < r) return false;
    }
    return true;
  }

  static bool isFree(List<Pt> placed, Pt c, double r) => placed.every((p) => p.distanceTo(c) >= 2 * r - 1e-9);

  /// Altıgen ve kare dizilimleri farklı açı ve kaydırmalarla dener, boşlukları doldurur,
  /// sonra sıkıştırarak bir çember daha sığdırmaya çalışır. Sezgisel bir aramadır: en kalabalık
  /// bulduğu dizilimi döndürür, matematiksel üst sınır değildir. [rng] sabit olduğundan
  /// aynı gün herkes aynı cevabı görür.
  static List<Pt> bestPacking(List<Pt> shape, double r, [Random? rng]) {
    var best = <Pt>[];
    for (final hex in const [true, false]) {
      final dx = 2 * r + 1e-6, dy = (hex ? sqrt(3) * r : 2 * r) + 1e-6;
      final reach = (0.75 / min(dx, dy)).ceil() + 1;
      for (var deg = 0; deg < (hex ? 60 : 90); deg += 5) {
        final c = cos(deg * pi / 180), s = sin(deg * pi / 180);
        for (var ox = 0; ox < 6; ox++) {
          for (var oy = 0; oy < 6; oy++) {
            final found = <Pt>[];
            for (var row = -reach; row <= reach; row++) {
              for (var col = -reach; col <= reach; col++) {
                final x = (col + (hex && row.isOdd ? 0.5 : 0) + ox / 6) * dx, y = (row + oy / 6) * dy;
                final p = Point(0.5 + x * c - y * s, 0.5 + x * s + y * c);
                if (fits(shape, p, r)) found.add(p);
              }
            }
            // Boşluk doldurma pahalı; yalnızca en iyiye yakın dizilimlerde denenir
            if (found.length + 1 < best.length) continue;
            final filled = _fillGaps(shape, found, r);
            if (filled.length > best.length) best = filled;
          }
        }
      }
    }
    return _squeezeMore(shape, best, r, rng ?? Random(1));
  }

  /// Bir çember daha sığmayana kadar sıkıştırma dener
  static List<Pt> _squeezeMore(List<Pt> shape, List<Pt> start, double r, Random rng) {
    var best = start;
    while (true) {
      final next = _squeeze(shape, best, r, rng);
      if (next == null) return best;
      best = next;
    }
  }

  /// Mevcut dizilime (ya da tamamen rastgele konumlara) fazladan bir çember ekleyip
  /// çakışanları birbirinden iterek geçerli bir yerleşim arar
  static List<Pt>? _squeeze(List<Pt> shape, List<Pt> current, double r, Random rng) {
    const steps = 300;
    final count = current.length + 1;
    // Az çemberde hem hesap ucuz hem tek hata pahalı: daha çok denenir
    final tries = (720 ~/ count).clamp(16, 90);
    Pt randomPoint() {
      while (true) {
        final p = Point(rng.nextDouble(), rng.nextDouble());
        if (_inside(shape, p)) return p;
      }
    }

    // Kenar payı: bitince katı kontrolden geçebilsin
    final push = r * 1.0005;
    for (var attempt = 0; attempt < tries; attempt++) {
      final pts = attempt.isEven && current.isNotEmpty
          ? [...current, randomPoint()]
          : [for (var i = 0; i < count; i++) randomPoint()];
      for (var step = 0; step < steps; step++) {
        final mx = List.filled(count, 0.0), my = List.filled(count, 0.0);
        var moved = false;
        for (var i = 0; i < count; i++) {
          for (var j = i + 1; j < count; j++) {
            final ddx = pts[i].x - pts[j].x, ddy = pts[i].y - pts[j].y;
            final d = sqrt(ddx * ddx + ddy * ddy);
            if (d >= 2 * push) continue;
            moved = true;
            final a = d == 0 ? rng.nextDouble() * 2 * pi : 0.0;
            final ux = d == 0 ? cos(a) : ddx / d, uy = d == 0 ? sin(a) : ddy / d;
            final o = (2 * push - d) / 2;
            mx[i] += ux * o;
            my[i] += uy * o;
            mx[j] -= ux * o;
            my[j] -= uy * o;
          }
          // Kenardan içeri: en yakın kenar noktasından uzaklaş
          final p = pts[i];
          var near = double.infinity;
          var qx = 0.0, qy = 0.0;
          for (var e = 0, f = shape.length - 1; e < shape.length; f = e++) {
            final a = shape[e], b = shape[f];
            final ex = b.x - a.x, ey = b.y - a.y;
            final t = (((p.x - a.x) * ex + (p.y - a.y) * ey) / (ex * ex + ey * ey)).clamp(0.0, 1.0);
            final hx = a.x + t * ex, hy = a.y + t * ey;
            final dd = (p.x - hx) * (p.x - hx) + (p.y - hy) * (p.y - hy);
            if (dd < near) {
              near = dd;
              qx = hx;
              qy = hy;
            }
          }
          final d = sqrt(near);
          final isIn = _inside(shape, p);
          if (isIn && d >= push) continue;
          if (d == 0) continue;
          moved = true;
          final ux = (p.x - qx) / d, uy = (p.y - qy) / d;
          final o = isIn ? push - d : -(d + push);
          mx[i] += ux * o;
          my[i] += uy * o;
        }
        if (!moved) break;
        for (var i = 0; i < count; i++) {
          pts[i] = Point(pts[i].x + mx[i], pts[i].y + my[i]);
        }
      }
      var valid = true;
      for (var i = 0; i < count && valid; i++) {
        valid = fits(shape, pts[i], r) && isFree(pts.sublist(0, i), pts[i], r);
      }
      if (valid) return pts;
    }
    return null;
  }

  static List<Pt> _fillGaps(List<Pt> shape, List<Pt> start, double r) {
    final filled = [...start];
    final step = r / 2;
    for (var y = r; y < 1; y += step) {
      for (var x = r; x < 1; x += step) {
        final p = Point(x, y);
        if (fits(shape, p, r) && isFree(filled, p, r)) filled.add(p);
      }
    }
    return filled;
  }

  /// Tam isabet tam puan; hata cevaba oranla büyüdükçe puan düşer
  static double roundScore(int guess, int answer) {
    if (answer <= 0) return 0;
    final error = (guess - answer).abs() / answer;
    return (maxRoundScore * (1 - error / zeroAtError)).clamp(0.0, maxRoundScore);
  }
}
