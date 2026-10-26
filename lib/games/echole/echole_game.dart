import 'dart:math';

/// Echole: yanıp sönen renk/ses dizisini tekrar et; her başarıda dizi bir uzar.
/// Dizi seed'den baştan üretilir, böylece herkes aynı günde aynı diziyi görür.
class EcholeGame {
  static const int pads = 4;
  static const int startLength = 3;
  static const int maxLength = 30;
  static const int lives = 2;

  final List<int> sequence;

  EcholeGame(Random rng) : sequence = List.generate(maxLength, (_) => rng.nextInt(pads));

  /// Dizinin her adımı arasındaki süre; dizi uzadıkça hızlanır
  static int stepMs(int length) => max(330, 650 - (length - startLength) * 30);

  /// Tamamlanan en uzun dizi uzunluğuna göre puan: 3 → 10, 12 ve üzeri → 100
  static double score(int completedLength) =>
      completedLength < startLength ? 0 : min(100, (completedLength - startLength + 1) * 10).toDouble();
}
