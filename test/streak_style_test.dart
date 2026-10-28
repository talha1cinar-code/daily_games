import 'package:flutter_test/flutter_test.dart';
import 'package:daily_games/widgets/streak_style.dart';

void main() {
  test('alev kademesi seriyle değişir', () {
    expect(StreakTier.of(0).nameTr, 'Sönük');
    expect(StreakTier.of(1).nameTr, 'Kıvılcım');
    expect(StreakTier.of(6).nameTr, 'Kıvılcım');
    expect(StreakTier.of(7).nameTr, 'Alev');
    expect(StreakTier.of(30).nameTr, 'Mor Alev');
    expect(StreakTier.of(120).nameTr, 'Altın Alev');
    expect(StreakTier.of(400).nameTr, 'Efsane');
  });

  test('hedefler sıralı ve ilerleme aralığı geçerli', () {
    for (var n = 0; n < 400; n++) {
      final goal = StreakTier.nextGoal(n);
      final prev = StreakTier.prevGoal(n);
      expect(prev, lessThanOrEqualTo(n));
      if (goal != null) expect(goal, greaterThan(n));
    }
    expect(StreakTier.nextGoal(0), 1);
    expect(StreakTier.nextGoal(5), 7);
    expect(StreakTier.next(5)!.nameTr, 'Alev');
  });
}
