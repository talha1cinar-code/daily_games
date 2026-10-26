import 'package:flutter/material.dart';
import 'grid_shape.dart';

/// Hücre kümesini kare bir alana çizer. [gridSize] verilirse sabit ızgara
/// (ör. 3x3 silüet), verilmezse şekil kendi sınırlarına göre ortalanır.
class CellsView extends StatelessWidget {
  final Cells cells;
  final Color color;
  final int? gridSize;
  final bool showGrid;

  const CellsView({super.key, required this.cells, required this.color, this.gridSize, this.showGrid = false});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _CellsPainter(cells, color, gridSize, showGrid), size: Size.infinite);
  }
}

class _CellsPainter extends CustomPainter {
  final Cells cells;
  final Color color;
  final int? gridSize;
  final bool showGrid;

  _CellsPainter(this.cells, this.color, this.gridSize, this.showGrid);

  @override
  void paint(Canvas canvas, Size size) {
    if (cells.isEmpty) return;
    final shape = gridSize == null ? GridShape.normalize(cells) : cells;
    final w = gridSize ?? shape.map((e) => e.$1).reduce((a, b) => a > b ? a : b) + 1;
    final h = gridSize ?? shape.map((e) => e.$2).reduce((a, b) => a > b ? a : b) + 1;
    final span = (w > h ? w : h).toDouble();
    final cell = size.shortestSide / span;
    final ox = (size.width - w * cell) / 2;
    final oy = (size.height - h * cell) / 2;
    final gap = cell * 0.08;

    if (showGrid) {
      for (var c = 0; c < w; c++) {
        for (var r = 0; r < h; r++) {
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(ox + c * cell + gap, oy + r * cell + gap, cell - 2 * gap, cell - 2 * gap),
              Radius.circular(cell * 0.15),
            ),
            Paint()..color = Colors.white.withValues(alpha: 0.05),
          );
        }
      }
    }
    for (final (c, r) in shape) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(ox + c * cell + gap, oy + r * cell + gap, cell - 2 * gap, cell - 2 * gap),
          Radius.circular(cell * 0.15),
        ),
        Paint()..color = color,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CellsPainter old) => old.cells != cells || old.color != color;
}
