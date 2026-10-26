import 'dart:math';

/// Kule bloğu; konum ve genişlik oyun alanı genişliğine oranla (0-1).
class StackBlock {
  final double left;
  final double width;
  const StackBlock(this.left, this.width);
  double get right => left + width;
}

enum PlaceOutcome { placed, perfect, miss }

class PlaceResult {
  final PlaceOutcome outcome;

  /// Kesilip düşen parça (mükemmel yerleşimde null)
  final StackBlock? chunk;
  const PlaceResult(this.outcome, [this.chunk]);
}

class StackleGame {
  static const double baseWidth = 0.6;
  static const double perfectTolerance = 0.012;
  static const double growStep = 0.03;
  static const int growAfterCombo = 3;

  final List<StackBlock> placed = [const StackBlock((1 - baseWidth) / 2, baseWidth)];
  int perfects = 0;
  int combo = 0;
  bool isOver = false;

  int get floors => placed.length - 1;
  StackBlock get top => placed.last;

  /// Kat başına 1, her mükemmel yerleşim için +1; 40 puan = 100
  double get score => min(100, (floors + perfects) * 2.5);

  /// Hareketli bloğun hızı (oyun genişliği / saniye)
  double get speed => min(0.45 + floors * 0.025, 1.3);

  PlaceResult place(double movingLeft) {
    final width = top.width;
    if ((movingLeft - top.left).abs() <= perfectTolerance) {
      combo++;
      perfects++;
      var block = StackBlock(top.left, width);
      // Üst üste mükemmel yerleşim bloğu biraz büyütür
      if (combo >= growAfterCombo && width < baseWidth) {
        final w = min(baseWidth, width + growStep);
        block = StackBlock((top.left - (w - width) / 2).clamp(0.0, 1 - w), w);
      }
      placed.add(block);
      return const PlaceResult(PlaceOutcome.perfect);
    }

    combo = 0;
    final below = top;
    final l = max(movingLeft, below.left);
    final r = min(movingLeft + width, below.right);
    if (r - l <= 0) {
      isOver = true;
      return PlaceResult(PlaceOutcome.miss, StackBlock(movingLeft, width));
    }
    placed.add(StackBlock(l, r - l));
    final chunk = movingLeft < below.left
        ? StackBlock(movingLeft, below.left - movingLeft)
        : StackBlock(below.right, movingLeft + width - below.right);
    return PlaceResult(PlaceOutcome.placed, chunk);
  }
}
