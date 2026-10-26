import 'dart:math';

class AngleRound {
  /// Tahmin edilecek açı (derece, 10-350)
  final int angle;

  /// İlk ışının yönü (radyan); açı her turda farklı yönde çizilir
  final double baseRotation;

  const AngleRound(this.angle, this.baseRotation);
}

/// Anglele: iki ışın arasındaki açıyı tahmin et. 5 tur, tur başına en fazla 20 puan.
class AngleleGame {
  static const int totalRounds = 5;
  static const double maxRoundScore = 20;

  /// Bu kadar derece sapmada tur puanı sıfırlanır
  static const double zeroAt = 30;

  final List<AngleRound> rounds;

  AngleleGame(Random rng)
      : rounds = [
          // Dar, geniş, dar, geniş ve son turda 180'den büyük (içbükey) açı
          AngleRound(15 + rng.nextInt(70), rng.nextDouble() * 2 * pi),
          AngleRound(95 + rng.nextInt(80), rng.nextDouble() * 2 * pi),
          AngleRound(20 + rng.nextInt(65), rng.nextDouble() * 2 * pi),
          AngleRound(100 + rng.nextInt(75), rng.nextDouble() * 2 * pi),
          AngleRound(190 + rng.nextInt(150), rng.nextDouble() * 2 * pi),
        ];

  static double roundScore(int actual, int guess) {
    final diff = (actual - guess).abs();
    return max(0, maxRoundScore * (1 - diff / zeroAt));
  }
}
