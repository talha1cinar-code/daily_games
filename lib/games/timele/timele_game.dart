import 'dart:math';

class TimeleGame {
  static const int totalRounds = 5;
  static const double maxScorePerRound = 10.0;
  static const int minMs = 300;   // 0.3 saniye
  static const int maxMs = 7000;  // 7.0 saniye

  final List<int> targetDurations = [];
  final List<int> guessedDurations = [];
  final List<double> roundScores = [];

  int currentRound = 0;
  bool isGameOver = false;

  TimeleGame({List<int>? externalDurations}) {
    if (externalDurations != null && externalDurations.length == totalRounds) {
      targetDurations.addAll(externalDurations);
    } else {
      _generateTargetDurations();
    }
  }

  void _generateTargetDurations() {
    final durations = getRandomDurations();
    targetDurations.addAll(durations);
  }

  /// Rastgele süreler üret (Biletli mod için)
  static List<int> getRandomDurations() {
    final random = Random();
    return List.generate(5, (_) {
      return minMs + random.nextInt(maxMs - minMs + 1);
    });
  }

  int get currentTargetDuration => targetDurations[currentRound];
  double get totalScore => roundScores.fold(0.0, (sum, s) => sum + s);
  int get remainingRounds => totalRounds - currentRound;

  double submitGuess(int guessDurationMs) {
    final score = calculateScore(currentTargetDuration, guessDurationMs);
    guessedDurations.add(guessDurationMs);
    roundScores.add(score);
    currentRound++;

    if (currentRound >= totalRounds) {
      isGameOver = true;
    }

    return score;
  }

  static double calculateScore(int target, int guess) {
    final diff = (target - guess).abs();
    
    // Yüzdesel hata (Örn: Hedef 1000ms iken 200ms şaşmak ile 
    // hedef 5000ms iken 1000ms şaşmak aynı orandır: %20 hata)
    final errorRatio = diff / target;
    
    // Hatayı 0.0 ile 1.0 arasına sıkıştırırken çarpan (2.5) ekleyerek
    // çok daha acımasız bir zorluk sağlıyoruz. %40 oranında şaştığı an 0 alır.
    final normalizedError = (errorRatio * 2.5).clamp(0.0, 1.0);

    // Üssel formül
    final score = pow(1.0 - normalizedError, 2.5) * maxScorePerRound;

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
    if (total >= 47) return 'Zaman Makinesi! ⏱️';
    if (total >= 40) return 'İç Saat Çok İyi! ⏰';
    if (total >= 30) return 'İyi İş Çıkardın ⌛';
    if (total >= 20) return 'Fena Değil 🙂';
    return 'Zaman Algın Zayıf 😅';
  }
}
