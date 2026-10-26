import 'dart:math';

/// Terazideki bir ağırlık. [pos]: negatif sol, pozitif sağ kol; |pos| merkeze uzaklık (1-4).
class Weight {
  final int kg;
  final int pos;
  const Weight(this.kg, this.pos);

  int get torque => kg * pos;
}

class BalanceRound {
  /// Önceden yerleştirilmiş, oynatılamayan ağırlıklar
  final List<Weight> fixed;

  /// Oyuncunun yerleştireceği ağırlıklar (kg)
  final List<int> tray;

  const BalanceRound(this.fixed, this.tray);
}

/// Balancele: elindeki ağırlıkları tahterevalliye yerleştir, dengeyi bul.
/// Denemeden önce terazi kilitli durur; "Bırak" denince kilit kalkar.
/// 5 tur, tur başına 3 deneme: ilk denemede 20, ikincide 12, üçüncüde 6 puan.
class BalanceleGame {
  static const int totalRounds = 5;
  static const int maxDistance = 4;
  static const int maxTries = 3;
  static const List<double> tryScores = [20, 12, 6];

  // (sabit ağırlık sayısı, oyuncu ağırlıkları)
  static const _plan = [
    (1, 1),
    (2, 1),
    (2, 2),
    (3, 2),
    (3, 2),
  ];

  final List<BalanceRound> rounds;

  BalanceleGame(Random rng) : rounds = [for (final (f, t) in _plan) _make(rng, f, t)];

  static int _randPos(Random rng) => (1 + rng.nextInt(maxDistance)) * (rng.nextBool() ? 1 : -1);

  /// Çözümden geriye doğru üretilir: önce oyuncu ağırlıklarının doğru yerleri seçilir,
  /// sonra sabit ağırlıklar toplam tork sıfır olacak şekilde tamamlanır.
  static BalanceRound _make(Random rng, int fixedCount, int trayCount) {
    while (true) {
      final tray = [for (var i = 0; i < trayCount; i++) 1 + rng.nextInt(5)];
      final solution = [for (final kg in tray) Weight(kg, _randPos(rng))];
      final fixed = [for (var i = 0; i < fixedCount - 1; i++) Weight(1 + rng.nextInt(6), _randPos(rng))];
      final need = -(solution.fold(0, (a, w) => a + w.torque) + fixed.fold(0, (a, w) => a + w.torque));
      if (need == 0) continue;
      // Son sabit ağırlık eksik torku kapatsın (1-9 kg, 1-4 mesafe)
      final options = [
        for (var d = 1; d <= maxDistance; d++)
          if (need.abs() % d == 0 && need.abs() ~/ d <= 9) Weight(need.abs() ~/ d, need > 0 ? d : -d),
      ];
      if (options.isEmpty) continue;
      fixed.add(options[rng.nextInt(options.length)]);
      // Oyuncu ağırlıkları olmadan zaten dengede olmasın
      if (fixed.fold(0, (a, w) => a + w.torque) == 0) continue;
      return BalanceRound(fixed, tray);
    }
  }

  static int torqueOf(Iterable<Weight> ws) => ws.fold(0, (a, w) => a + w.torque);

  static bool isBalanced(BalanceRound round, List<Weight> placed) =>
      torqueOf(round.fixed) + torqueOf(placed) == 0;

  /// Bir çözüm (sonuçta göstermek için). Bulunamazsa boş liste.
  static List<Weight> solve(BalanceRound round) {
    final positions = [for (var d = -maxDistance; d <= maxDistance; d++) if (d != 0) d];
    final base = torqueOf(round.fixed);
    List<Weight>? search(int i, int t, List<Weight> acc) {
      if (i == round.tray.length) return t == 0 ? acc : null;
      for (final p in positions) {
        final r = search(i + 1, t + round.tray[i] * p, [...acc, Weight(round.tray[i], p)]);
        if (r != null) return r;
      }
      return null;
    }

    return search(0, base, []) ?? [];
  }
}
