import 'dart:math';
import 'package:flutter/material.dart';

/// RGBle oyun mantığı — 5 round'luk renk eşleştirme oyunu.
class RgbleGame {
  static const int totalRounds = 5;
  static const double maxScorePerRound = 10.0;

  final List<Color> targetColors = [];
  final List<Color> guessedColors = [];
  final List<double> roundScores = [];
  int currentRound = 0;
  bool isGameOver = false;

  RgbleGame({List<Color>? externalColors}) {
    if (externalColors != null && externalColors.length == totalRounds) {
      targetColors.addAll(externalColors);
    } else {
      _generateTargetColors();
    }
  }

  void _generateTargetColors() {
    final colors = getRandomColors();
    targetColors.addAll(colors);
  }

  /// Rastgele renkler üret (Biletli mod için)
  static List<Color> getRandomColors() {
    final random = Random();
    return List.generate(5, (_) {
      return HSVColor.fromAHSV(
        1.0,
        random.nextDouble() * 360,
        0.4 + random.nextDouble() * 0.6,
        0.4 + random.nextDouble() * 0.6,
      ).toColor();
    });
  }

  /// Mevcut round'un hedef rengi
  Color get currentTargetColor => targetColors[currentRound];

  /// Toplam puan
  double get totalScore => roundScores.fold(0.0, (sum, s) => sum + s);

  /// Kalan round
  int get remainingRounds => totalRounds - currentRound;

  /// Tahmin gönder ve puan hesapla
  double submitGuess(Color guessColor) {
    final score = calculateScore(currentTargetColor, guessColor);
    guessedColors.add(guessColor);
    roundScores.add(score);
    currentRound++;

    if (currentRound >= totalRounds) {
      isGameOver = true;
    }

    return score;
  }

  static double calculateScore(Color target, Color guess) {
    // RGB uzayında öklid mesafesi (bileşenler 0.0 - 1.0 arası)
    final dr = target.r - guess.r;
    final dg = target.g - guess.g;
    final db = target.b - guess.b;

    // Maksimum olası öklid mesafesi = sqrt(1^2 + 1^2 + 1^2) ≈ 1.732
    final distance = sqrt(dr * dr + dg * dg + db * db);
    final maxDistance = sqrt(3.0);

    // Hata oranı (0.0 ile 1.0 arası)
    final error = distance / maxDistance;

    // 10 üzerinden puan (fark arttıkça puan ÜSSEL olarak düşer)
    // Alakasız renkler (ör. yüksek hata) 0'a çok yakın puan alırken,
    // Sadece gerçekten yakın renkler 7-10 arası yüksek puan alabilir.
    // pow(..., 2.0) kullanımı uzak renkleri çok daha sert cezalandırır.
    final score = pow(1.0 - error, 2.0) * maxScorePerRound;

    return double.parse(score.clamp(0.0, 10.0).toStringAsFixed(1));
  }

  /// Puana göre emoji döndür
  static String getScoreEmoji(double score) {
    if (score >= 9.5) return '🎯';
    if (score >= 8.0) return '🔥';
    if (score >= 6.0) return '👍';
    if (score >= 4.0) return '😐';
    return '😬';
  }

  /// Toplam puana göre başarı mesajı
  static String getFinalMessage(double total) {
    if (total >= 47) return 'Renk Ustası! 🎨';
    if (total >= 40) return 'Harika! 🌟';
    if (total >= 30) return 'İyi İş! 👏';
    if (total >= 20) return 'Fena Değil 🙂';
    return 'Alıştırma Gerek 💪';
  }
}
