import 'dart:math';
import 'dart:ui';

class DropRound {
  final Offset launch;
  final Offset velocity;
  final List<(Offset, Offset)> ramps;

  /// Simülasyonun hesapladığı iniş noktası (x) ve animasyon için yol
  final double landingX;
  final List<Offset> path;

  const DropRound(this.launch, this.velocity, this.ramps, this.landingX, this.path);
}

/// Dropple: fırlatılan top rampalardan ve duvarlardan sekerek düşer;
/// oyuncu yere ineceği noktayı tahmin eder. Dünya 1 birim genişlik,
/// [worldHeight] birim yüksekliktir; y aşağı doğru artar.
class DroppleGame {
  static const int totalRounds = 5;
  static const double maxRoundScore = 20;
  static const double worldHeight = 1.4;
  static const double floorY = 1.32;
  static const double ballRadius = 0.022;
  static const double gravity = 2.2;
  static const double restitution = 0.78;

  /// Bu kadar (genişliğin oranı) sapmada tur puanı sıfırlanır
  static const double zeroAt = 0.3;

  final List<DropRound> rounds;

  DroppleGame(Random rng) : rounds = [for (var i = 0; i < totalRounds; i++) _make(rng, i)];

  static double roundScore(double actualX, double guessX) {
    return max(0, maxRoundScore * (1 - (actualX - guessX).abs() / zeroAt));
  }

  static double _r(Random rng, double lo, double hi) => lo + rng.nextDouble() * (hi - lo);

  static DropRound _make(Random rng, int index) {
    while (true) {
      final launch = Offset(0.1, _r(rng, 0.16, 0.24));
      final angle = _r(rng, 0.25, 0.9); // yukarı doğru, radyan
      final speed = index == 2 ? _r(rng, 1.6, 1.9) : _r(rng, 0.8, 1.3);
      final velocity = Offset(speed * cos(angle), -speed * sin(angle));

      final rampCount = switch (index) { 0 => 0, 1 => 1, 2 => 0, 3 => 2, _ => 3 };
      final ramps = <(Offset, Offset)>[];
      for (var k = 0; k < rampCount; k++) {
        final c = Offset(_r(rng, 0.25, 0.8), _r(rng, 0.5, 1.1));
        final len = index == 4 ? _r(rng, 0.14, 0.2) : _r(rng, 0.22, 0.34);
        final a = _r(rng, -0.7, 0.7);
        final d = Offset(cos(a), sin(a)) * (len / 2);
        ramps.add((c - d, c + d));
      }

      final sim = simulate(launch, velocity, ramps);
      if (sim == null) continue;
      final (x, path, hits, wallHits) = sim;
      if (x < 0.08 || x > 0.92) continue;
      if (rampCount > 0 && hits == 0) continue; // rampalar işe yaramalı
      if (index == 2 && wallHits == 0) continue; // 3. tur: duvardan seken atış
      return DropRound(launch, velocity, ramps, x, path);
    }
  }

  /// İniş x'i, yol, rampa ve duvar çarpma sayısı. 6 saniyede inmezse null.
  static (double, List<Offset>, int, int)? simulate(Offset start, Offset v0, List<(Offset, Offset)> ramps) {
    const dt = 1 / 300;
    var p = start;
    var v = v0;
    final path = <Offset>[p];
    var hits = 0, wallHits = 0;
    for (var step = 0; step < 6 * 300; step++) {
      v = Offset(v.dx, v.dy + gravity * dt);
      p += v * dt;

      if (p.dx < ballRadius) {
        p = Offset(ballRadius, p.dy);
        v = Offset(-v.dx * restitution, v.dy);
        wallHits++;
      } else if (p.dx > 1 - ballRadius) {
        p = Offset(1 - ballRadius, p.dy);
        v = Offset(-v.dx * restitution, v.dy);
        wallHits++;
      }
      if (p.dy < ballRadius) {
        p = Offset(p.dx, ballRadius);
        v = Offset(v.dx, -v.dy * restitution);
      }

      for (final (a, b) in ramps) {
        final ab = b - a;
        final t = (((p - a).dx * ab.dx + (p - a).dy * ab.dy) / (ab.dx * ab.dx + ab.dy * ab.dy)).clamp(0.0, 1.0);
        final closest = a + ab * t;
        final diff = p - closest;
        final dist = diff.distance;
        if (dist < ballRadius && dist > 1e-9) {
          final n = diff / dist;
          final vn = v.dx * n.dx + v.dy * n.dy;
          if (vn < 0) {
            v = v - n * ((1 + restitution) * vn);
            hits++;
          }
          p = closest + n * ballRadius;
        }
      }

      if (step % 4 == 0) path.add(p);
      if (p.dy >= floorY - ballRadius) {
        path.add(Offset(p.dx, floorY - ballRadius));
        return (p.dx, path, hits, wallHits);
      }
    }
    return null;
  }
}
