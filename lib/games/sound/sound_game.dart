import 'dart:math';
import '../../services/language_service.dart';

/// Sound oyununun çekirdek mantığı
class SoundGame {
  static const int totalRounds = 5;
  static const double maxScorePerRound = 10.0;
  static const double minFreq = 80.0;
  static const double maxFreq = 1200.0;

  final List<double> targetFrequencies = [];
  final List<double> guessedFrequencies = [];
  final List<double> roundScores = [];

  int currentRound = 0;
  bool isGameOver = false;

  SoundGame({List<double>? externalFrequencies}) {
    if (externalFrequencies != null && externalFrequencies.length == totalRounds) {
      targetFrequencies.addAll(externalFrequencies);
    } else {
      _generateTargetFrequencies();
    }
  }

  void _generateTargetFrequencies() {
    final frequencies = getRandomFrequencies();
    targetFrequencies.addAll(frequencies);
  }

  /// Rastgele frekanslar üret (Biletli mod için)
  static List<double> getRandomFrequencies() {
    final random = Random();
    return List.generate(5, (_) {
      return minFreq + random.nextDouble() * (maxFreq - minFreq);
    });
  }

  double get currentTargetFreq => targetFrequencies[currentRound];
  double get totalScore => roundScores.fold(0.0, (sum, s) => sum + s);
  int get remainingRounds => totalRounds - currentRound;

  double submitGuess(double guessFreq) {
    final score = calculateScore(currentTargetFreq, guessFreq);
    guessedFrequencies.add(guessFreq);
    roundScores.add(score);
    currentRound++;

    if (currentRound >= totalRounds) {
      isGameOver = true;
    }

    return score;
  }

  static double calculateScore(double target, double guess) {
    final diff = (target - guess).abs();
    
    // Hata toleransını oldukça kıstık. 250 Hz'lik sapmada 0 puan alınacak.
    final error = (diff / 250.0).clamp(0.0, 1.0);

    // Üssel formül: Hata arttıkça puan hızla düşer.
    final score = pow(1.0 - error, 2.5) * maxScorePerRound;

    return double.parse(score.clamp(0.0, 10.0).toStringAsFixed(1));
  }

  static String getScoreEmoji(double score) {
    if (score >= 9.5) return '🎯';
    if (score >= 8.0) return '🔥';
    if (score >= 6.0) return '👍';
    if (score >= 4.0) return '😐';
    return '😬';
  }

  static String getFinalMessage(double total) {
    final isTr = LanguageService().isTurkish;
    if (total >= 47) return isTr ? 'Kusursuz Kulak! 🎶' : 'Perfect Ear! 🎶';
    if (total >= 40) return isTr ? 'Müzisyen Misin? 🎵' : 'Are You a Musician? 🎵';
    if (total >= 30) return isTr ? 'İyi Duyuyorsun 👂' : 'Good Hearing! 👂';
    if (total >= 20) return isTr ? 'Fena Değil 🙂' : 'Not Bad 🙂';
    return isTr ? 'Biraz Pratik Şart 😅' : 'Needs Practice 😅';
  }
}
