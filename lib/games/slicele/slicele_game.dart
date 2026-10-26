import 'dart:math';
import 'dart:ui';

/// Slicele turu: kesilecek şekil, hedef oran ve dönüp dönmediği.
class SliceleRound {
  /// Merkezi (0,0), yarıçapı ~1 olan normalize poligon
  final List<Offset> shape;

  /// Küçük parçanın hedef yüzdesi (50 = tam ortadan)
  final double targetPercent;

  /// Saniyedeki dönüş (radyan); 0 = sabit
  final double spin;

  const SliceleRound(this.shape, this.targetPercent, this.spin);
}

class SliceResult {
  final List<Offset> pieceA;
  final List<Offset> pieceB;
  final double percentA; // 0-100
  const SliceResult(this.pieceA, this.pieceB, this.percentA);

  double get smallerPercent => min(percentA, 100 - percentA);
}

class SliceleGame {
  static const int totalRounds = 5;
  static const double maxRoundScore = 20;

  final List<SliceleRound> rounds;

  SliceleGame(Random rng)
      : rounds = [
          SliceleRound(_blob(rng, 9, 0.75, 1.0), 50, 0),
          SliceleRound(_star(rng), 50, 0),
          SliceleRound(_blob(rng, 11, 0.5, 1.0), 25, 0),
          SliceleRound(_blob(rng, 12, 0.45, 1.0), 50, 0),
          SliceleRound(_star(rng), 50, 0.9),
        ];

  /// Hedefe 1 puan uzaklık 2 puan kaybettirir; 10 puan sapma = 0
  static double roundScore(double smallerPercent, double target) {
    final diff = (smallerPercent - target).abs();
    return max(0, maxRoundScore - diff * 2);
  }

  // ─── Şekil üretimi ─────────────────────────────────────────────
  // Açılar sıralı üretildiği için poligon merkezden "yıldız biçimli" ve
  // kendini kesmeyen bir şekildir.
  static List<Offset> _blob(Random rng, int n, double rMin, double rMax) {
    final angles = List.generate(n, (i) => (i + rng.nextDouble() * 0.6) / n * 2 * pi);
    return [
      for (final a in angles)
        Offset.fromDirection(a, rMin + rng.nextDouble() * (rMax - rMin)),
    ];
  }

  static List<Offset> _star(Random rng) {
    final points = 5 + rng.nextInt(3);
    final inner = 0.42 + rng.nextDouble() * 0.15;
    final offset = rng.nextDouble() * pi;
    return [
      for (var i = 0; i < points * 2; i++)
        Offset.fromDirection(
          offset + i * pi / points,
          i.isEven ? 0.9 + rng.nextDouble() * 0.1 : inner,
        ),
    ];
  }

  // ─── Geometri ──────────────────────────────────────────────────
  static double area(List<Offset> poly) {
    var s = 0.0;
    for (var i = 0; i < poly.length; i++) {
      final a = poly[i], b = poly[(i + 1) % poly.length];
      s += a.dx * b.dy - b.dx * a.dy;
    }
    return s.abs() / 2;
  }

  static Offset centroid(List<Offset> poly) {
    var x = 0.0, y = 0.0;
    for (final p in poly) {
      x += p.dx;
      y += p.dy;
    }
    return Offset(x / poly.length, y / poly.length);
  }

  /// [a]-[b] doğrusunun bir tarafında kalan kısım (Sutherland–Hodgman).
  /// Yarım düzlem dışbükey olduğu için içbükey şekillerde de alan doğrudur.
  static List<Offset> clip(List<Offset> poly, Offset a, Offset b, {required bool left}) {
    double side(Offset p) {
      final c = (b.dx - a.dx) * (p.dy - a.dy) - (b.dy - a.dy) * (p.dx - a.dx);
      return left ? c : -c;
    }

    final out = <Offset>[];
    for (var i = 0; i < poly.length; i++) {
      final p = poly[i], q = poly[(i + 1) % poly.length];
      final sp = side(p), sq = side(q);
      if (sp >= 0) out.add(p);
      if ((sp >= 0) != (sq >= 0)) {
        final t = sp / (sp - sq);
        out.add(Offset.lerp(p, q, t)!);
      }
    }
    return out;
  }

  /// Şekli sonsuz [a]-[b] doğrusu ile keser. Doğru şekli ikiye bölmüyorsa null.
  static SliceResult? slice(List<Offset> poly, Offset a, Offset b) {
    if ((b - a).distance < 1e-6) return null;
    final pa = clip(poly, a, b, left: true);
    final pb = clip(poly, a, b, left: false);
    final total = area(poly);
    if (pa.length < 3 || pb.length < 3 || total == 0) return null;
    final percentA = area(pa) / total * 100;
    if (percentA < 0.5 || percentA > 99.5) return null;
    return SliceResult(pa, pb, percentA);
  }
}
