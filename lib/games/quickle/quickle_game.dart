import 'dart:math';

class QuickleQuestion {
  final String text;
  final int answer;
  final int points;
  const QuickleQuestion(this.text, this.answer, this.points);
}

/// Quickle: 60 saniyelik hızlı hesap.
///
/// Soru dizisi seed'den önceden üretilir, böylece Daily Run'da herkes aynı
/// soruları aynı sırayla görür. Zorluk soru sırasıyla artar.
class QuickleGame {
  static const int durationMs = 60000;
  static const int wrongPenaltyMs = 3000;
  static const int streakBonusMs = 2000;
  static const int streakForBonus = 5;

  final List<QuickleQuestion> questions;
  int index = 0;
  int correct = 0;
  int wrong = 0;
  int points = 0;
  int streak = 0;
  int bestStreak = 0;

  QuickleGame(Random rng) : questions = List.generate(80, (i) => _make(rng, i));

  QuickleQuestion get current => questions[index % questions.length];

  /// 0-100 arası skor
  double get score => min(points, 100).toDouble();

  /// Doğruysa true döner; ekstra süre/ceza hesabını ekran yapar.
  bool submit(int value) {
    final ok = value == current.answer;
    if (ok) {
      correct++;
      points += current.points;
      streak++;
      bestStreak = max(bestStreak, streak);
    } else {
      wrong++;
      streak = 0;
    }
    index++;
    return ok;
  }

  bool get earnedStreakBonus => streak > 0 && streak % streakForBonus == 0;

  static int _r(Random rng, int lo, int hi) => lo + rng.nextInt(hi - lo + 1);

  static QuickleQuestion _make(Random rng, int i) {
    final tier = i < 5 ? 0 : i < 10 ? 1 : i < 16 ? 2 : 3;
    final pts = tier + 3;
    final kind = rng.nextInt(3);
    switch (tier) {
      case 0:
        if (kind == 0) {
          final a = _r(rng, 6, 20), b = _r(rng, 1, a - 1);
          return QuickleQuestion('$a − $b', a - b, pts);
        }
        final a = _r(rng, 2, 12), b = _r(rng, 2, 12);
        return QuickleQuestion('$a + $b', a + b, pts);
      case 1:
        if (kind == 0) {
          final a = _r(rng, 25, 90), b = _r(rng, 6, a - 5);
          return QuickleQuestion('$a − $b', a - b, pts);
        }
        final a = _r(rng, 12, 49), b = _r(rng, 6, 40);
        return QuickleQuestion('$a + $b', a + b, pts);
      case 2:
        if (kind == 0) {
          final a = _r(rng, 25, 99), b = _r(rng, 25, 99);
          return QuickleQuestion('$a + $b', a + b, pts);
        }
        final a = _r(rng, 2, 9), b = _r(rng, 3, 9);
        return QuickleQuestion('$a × $b', a * b, pts);
      default:
        if (kind == 0) {
          final b = _r(rng, 3, 12), q = _r(rng, 3, 12);
          return QuickleQuestion('${b * q} ÷ $b', q, pts);
        }
        if (kind == 1) {
          final a = _r(rng, 60, 180), b = _r(rng, 15, a - 10);
          return QuickleQuestion('$a − $b', a - b, pts);
        }
        final a = _r(rng, 4, 12), b = _r(rng, 6, 15);
        return QuickleQuestion('$a × $b', a * b, pts);
    }
  }
}
