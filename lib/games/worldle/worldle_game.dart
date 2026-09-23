import 'dart:math';
import 'country.dart';

/// Worldle oyun mantığı — Haversine mesafe, yön ve yakınlık hesaplaması.
class WorldleGame {
  static const int maxAttempts = 6;

  /// Dünya'nın yarıçapı (km) — Haversine formülü için
  static const double _earthRadiusKm = 6371.0;

  /// Yakınlık hesabı için referans mesafe (km)
  /// Dünya üzerindeki en uzak iki nokta ~20.000 km
  static const double _maxDistanceKm = 20000.0;

  final Country targetCountry;
  final List<WorldleGuess> guesses = [];
  bool isGameOver = false;
  bool isWon = false;

  WorldleGame({required this.targetCountry});

  /// Kalan hak sayısı
  int get remainingAttempts => maxAttempts - guesses.length;

  // ─── Tahmin gönderme ──────────────────────────────────────────────
  WorldleGuessResult submitGuess(Country guessedCountry) {
    if (isGameOver) return WorldleGuessResult.gameOver;

    // Aynı ülkeyi tekrar tahmin etmeyi engelle
    if (guesses.any((g) => g.country == guessedCountry)) {
      return WorldleGuessResult.alreadyGuessed;
    }

    final distanceKm = _haversineDistance(
      guessedCountry.latitude,
      guessedCountry.longitude,
      targetCountry.latitude,
      targetCountry.longitude,
    );

    final bearing = _calculateBearing(
      guessedCountry.latitude,
      guessedCountry.longitude,
      targetCountry.latitude,
      targetCountry.longitude,
    );

    final direction = _bearingToDirection(bearing);
    final directionArrow = _bearingToArrow(bearing);
    final proximityPercent = _calculateProximity(distanceKm);

    final guess = WorldleGuess(
      country: guessedCountry,
      distanceKm: distanceKm,
      direction: direction,
      directionArrow: directionArrow,
      bearingDegrees: bearing,
      proximityPercent: proximityPercent,
    );

    guesses.add(guess);

    // Doğru tahmin
    if (guessedCountry == targetCountry) {
      isGameOver = true;
      isWon = true;
      return WorldleGuessResult.correct;
    }

    // Hak bitti
    if (guesses.length >= maxAttempts) {
      isGameOver = true;
      isWon = false;
      return WorldleGuessResult.outOfAttempts;
    }

    return WorldleGuessResult.wrong;
  }

  // ─── Haversine formülü ────────────────────────────────────────────
  /// İki koordinat arası kuş uçuşu mesafe (km)
  static double _haversineDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    final dLat = _degreesToRadians(lat2 - lat1);
    final dLon = _degreesToRadians(lon2 - lon1);

    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_degreesToRadians(lat1)) *
            cos(_degreesToRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);

    final c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return _earthRadiusKm * c;
  }

  // ─── Bearing (yön açısı) hesaplama ────────────────────────────────
  /// Tahmin edilen ülkeden hedef ülkeye doğru bearing açısı (0°-360°)
  static double _calculateBearing(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    final dLon = _degreesToRadians(lon2 - lon1);
    final lat1Rad = _degreesToRadians(lat1);
    final lat2Rad = _degreesToRadians(lat2);

    final y = sin(dLon) * cos(lat2Rad);
    final x = cos(lat1Rad) * sin(lat2Rad) -
        sin(lat1Rad) * cos(lat2Rad) * cos(dLon);

    final bearing = atan2(y, x);
    return (_radiansToDegrees(bearing) + 360) % 360;
  }

  // ─── Bearing → 8 yön dönüşümü ────────────────────────────────────
  static String _bearingToDirection(double bearing) {
    const directions = [
      'Kuzey',
      'Kuzeydoğu',
      'Doğu',
      'Güneydoğu',
      'Güney',
      'Güneybatı',
      'Batı',
      'Kuzeybatı',
    ];
    final index = ((bearing + 22.5) % 360 / 45).floor();
    return directions[index];
  }

  static String _bearingToArrow(double bearing) {
    const arrows = ['⬆️', '↗️', '➡️', '↘️', '⬇️', '↙️', '⬅️', '↖️'];
    final index = ((bearing + 22.5) % 360 / 45).floor();
    return arrows[index];
  }

  // ─── Yakınlık yüzdesi ─────────────────────────────────────────────
  static double _calculateProximity(double distanceKm) {
    final proximity = (1 - (distanceKm / _maxDistanceKm)) * 100;
    return proximity.clamp(0.0, 100.0);
  }

  // ─── Yardımcı dönüşümler ──────────────────────────────────────────
  static double _degreesToRadians(double degrees) => degrees * pi / 180;
  static double _radiansToDegrees(double radians) => radians * 180 / pi;
}

/// Tek bir tahmin sonucunu tutan veri sınıfı
class WorldleGuess {
  final Country country;
  final double distanceKm;
  final String direction;
  final String directionArrow;
  final double bearingDegrees;
  final double proximityPercent;

  const WorldleGuess({
    required this.country,
    required this.distanceKm,
    required this.direction,
    required this.directionArrow,
    required this.bearingDegrees,
    required this.proximityPercent,
  });

  /// Mesafeyi okunabilir formatta döndürür
  String get formattedDistance {
    if (distanceKm < 1) return '< 1 km';
    return '${distanceKm.round()} km';
  }

  /// Doğru tahmin mi?
  bool get isCorrect => distanceKm < 1;
}

/// Tahmin sonucu enum'ı
enum WorldleGuessResult {
  correct,
  wrong,
  alreadyGuessed,
  outOfAttempts,
  gameOver,
}
