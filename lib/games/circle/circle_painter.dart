import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class CirclePainter extends CustomPainter {
  final List<Offset> points;
  final Offset centerPoint;
  final bool isFailed;
  final double? accuracy;

  CirclePainter({
    required this.points,
    required this.centerPoint,
    this.isFailed = false,
    this.accuracy,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Merkez nokta çizimi
    final centerPaint = Paint()
      ..color = AppColors.primary
      ..style = PaintingStyle.fill;
    
    canvas.drawCircle(centerPoint, 6.0, centerPaint);

    if (points.isEmpty) return;

    // Kullanıcı çizgisinin rengi
    Color lineColor = Colors.white; // Default white for dark background
    
    if (isFailed) {
      lineColor = Colors.redAccent;
    } else if (accuracy != null) {
      if (accuracy! >= 90) {
        lineColor = Colors.green;
      } else if (accuracy! >= 70) {
        lineColor = Colors.orange;
      } else {
        lineColor = Colors.red;
      }
    }

    final pathPaint = Paint()
      ..color = lineColor
      ..strokeWidth = 6.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final path = Path();
    path.moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }

    // Eğer çizim bittiyse ve başarılıysa, son noktayı ilk noktaya bağla
    if (accuracy != null && !isFailed && points.length > 30) {
      // Çemberi sadece kapanmaya yakınsa kapat
      final distance = (points.first - points.last).distance;
      if (distance < 100) {
        path.close();
      }
    }

    canvas.drawPath(path, pathPaint);
  }

  @override
  bool shouldRepaint(covariant CirclePainter oldDelegate) {
    return true;
  }
}
