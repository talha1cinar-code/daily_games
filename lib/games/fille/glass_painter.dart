import 'dart:math';
import 'package:flutter/material.dart';

/// Bardak ve su çiziminden sorumlu CustomPainter.
/// 
/// [glassHeightRatio] bardağın ekran yüksekliğine oranı (0.4-0.8 arası).
/// [waterLevel] suyun doluluk oranı (0.0-1.0+, 1.0 üstü taşma).
/// [wavePhase] dalga animasyonu için faz değeri.
/// [bubbles] kabarcık listesi.
/// [isOverflow] taşma durumu.
/// [showResult] sonuç gösteriliyor mu.
class GlassPainter extends CustomPainter {
  final double glassHeightRatio;
  final double waterLevel;
  final double wavePhase;
  final List<BubbleParticle> bubbles;
  final bool isOverflow;
  final bool showResult;
  final bool isFilling;
  final List<SplashDrop> splashDrops;

  GlassPainter({
    required this.glassHeightRatio,
    required this.waterLevel,
    required this.wavePhase,
    required this.bubbles,
    this.isOverflow = false,
    this.showResult = false,
    this.isFilling = false,
    this.splashDrops = const [],
  });

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final glassWidth = size.width * 0.48;
    final glassHeight = size.height * glassHeightRatio;
    final glassBottom = size.height * 0.82;
    final glassTop = glassBottom - glassHeight;
    final glassLeft = centerX - glassWidth / 2;
    final glassRight = centerX + glassWidth / 2;

    // Bardak duvarları hafifçe daralıyor (yukarı doğru)
    final topNarrow = glassWidth * 0.04;

    // ─── Arka plan glow efekti ────────────────────────────────────
    if (isFilling || showResult) {
      final glowColor = isOverflow
          ? Colors.redAccent.withValues(alpha: 0.15)
          : showResult
              ? Colors.greenAccent.withValues(alpha: 0.12)
              : Colors.cyanAccent.withValues(alpha: 0.08);
      final glowPaint = Paint()
        ..shader = RadialGradient(
          colors: [glowColor, Colors.transparent],
        ).createShader(Rect.fromCenter(
          center: Offset(centerX, glassBottom - glassHeight / 2),
          width: glassWidth * 2.5,
          height: glassHeight * 2,
        ));
      canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), glowPaint);
    }

    // ─── Su çizimi ────────────────────────────────────────────────
    final clampedWater = waterLevel.clamp(0.0, 1.05);
    if (clampedWater > 0.005) {
      final waterHeight = glassHeight * clampedWater;
      final waterTop = glassBottom - waterHeight;

      // Su rengi: normal → taşma kırmızı
      final waterColor1 = isOverflow
          ? const Color(0xFFFF6B6B)
          : const Color(0xFF00D2FF);
      final waterColor2 = isOverflow
          ? const Color(0xFFEE5A24)
          : const Color(0xFF0078FF);

      final waterPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            waterColor1.withValues(alpha: 0.85),
            waterColor2.withValues(alpha: 0.95),
          ],
        ).createShader(Rect.fromLTRB(glassLeft, waterTop, glassRight, glassBottom));

      // Dalga efekti ile su yüzeyi
      final waterPath = Path();
      final waveAmplitude = isFilling ? 4.0 : (showResult ? 1.5 : 2.5);
      final waveFreq = 3.0;

      // Sol alt köşeden başla
      final leftAtBottom = glassLeft + topNarrow * (0);
      final rightAtBottom = glassRight - topNarrow * (0);

      // İnterpolasyonla duvarın genişliğini hesapla
      final waterRatioFromBottom = clampedWater.clamp(0.0, 1.0);
      final leftAtWater = glassLeft + topNarrow * waterRatioFromBottom;
      final rightAtWater = glassRight - topNarrow * waterRatioFromBottom;

      waterPath.moveTo(leftAtBottom, glassBottom);
      waterPath.lineTo(leftAtWater, waterTop);

      // Üst dalga (su yüzeyi)
      for (double x = leftAtWater; x <= rightAtWater; x += 2) {
        final normalizedX = (x - leftAtWater) / (rightAtWater - leftAtWater);
        final waveY = waterTop +
            sin((normalizedX * waveFreq * pi * 2) + wavePhase) * waveAmplitude +
            sin((normalizedX * waveFreq * 1.7 * pi * 2) + wavePhase * 1.3) * waveAmplitude * 0.5;
        waterPath.lineTo(x, waveY);
      }

      waterPath.lineTo(rightAtBottom, glassBottom);
      waterPath.close();

      // Clip to glass shape
      final glassClip = Path();
      glassClip.moveTo(glassLeft, glassBottom);
      glassClip.lineTo(glassLeft + topNarrow, glassTop);
      glassClip.lineTo(glassRight - topNarrow, glassTop);
      glassClip.lineTo(glassRight, glassBottom);
      glassClip.close();

      canvas.save();
      canvas.clipPath(glassClip);
      canvas.drawPath(waterPath, waterPaint);

      // Su parıltısı
      final shimmerPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.12),
            Colors.transparent,
            Colors.white.withValues(alpha: 0.06),
          ],
          stops: const [0.0, 0.5, 1.0],
        ).createShader(Rect.fromLTRB(glassLeft, waterTop, glassRight, glassBottom));
      canvas.drawPath(waterPath, shimmerPaint);

      canvas.restore();
    }

    // ─── Kabarcıklar ──────────────────────────────────────────────
    for (final bubble in bubbles) {
      final bubbleY = glassBottom - (bubble.y * glassHeight);
      if (bubbleY < glassTop || bubbleY > glassBottom) continue;

      final bubbleX = glassLeft + (bubble.x * glassWidth) + glassWidth * 0.02;
      final bubblePaint = Paint()
        ..color = Colors.white.withValues(alpha: bubble.opacity * 0.6)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(bubbleX, bubbleY), bubble.radius, bubblePaint);

      // Kabarcık highlight
      final highlightPaint = Paint()
        ..color = Colors.white.withValues(alpha: bubble.opacity * 0.3)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(
        Offset(bubbleX - bubble.radius * 0.3, bubbleY - bubble.radius * 0.3),
        bubble.radius * 0.35,
        highlightPaint,
      );
    }

    // ─── Bardak çizimi (cam efekti) ───────────────────────────────
    // Sol duvar
    final leftWallPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          Colors.white.withValues(alpha: 0.35),
          Colors.white.withValues(alpha: 0.08),
        ],
      ).createShader(Rect.fromLTRB(glassLeft - 2, glassTop, glassLeft + 6, glassBottom))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;

    final leftWall = Path();
    leftWall.moveTo(glassLeft, glassBottom);
    leftWall.lineTo(glassLeft + topNarrow, glassTop);
    canvas.drawPath(leftWall, leftWallPaint);

    // Sağ duvar
    final rightWallPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          Colors.white.withValues(alpha: 0.08),
          Colors.white.withValues(alpha: 0.3),
        ],
      ).createShader(Rect.fromLTRB(glassRight - 6, glassTop, glassRight + 2, glassBottom))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;

    final rightWall = Path();
    rightWall.moveTo(glassRight, glassBottom);
    rightWall.lineTo(glassRight - topNarrow, glassTop);
    canvas.drawPath(rightWall, rightWallPaint);

    // Alt çizgi
    final bottomPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(glassLeft, glassBottom),
      Offset(glassRight, glassBottom),
      bottomPaint,
    );

    // Üst ağız
    final rimPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(glassLeft + topNarrow - 4, glassTop),
      Offset(glassRight - topNarrow + 4, glassTop),
      rimPaint,
    );

    // Cam parıltısı (sol taraf)
    final reflectionPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.white.withValues(alpha: 0.12),
          Colors.white.withValues(alpha: 0.02),
          Colors.white.withValues(alpha: 0.08),
        ],
      ).createShader(Rect.fromLTRB(
        glassLeft + 8, glassTop + glassHeight * 0.1,
        glassLeft + 14, glassBottom - glassHeight * 0.1,
      ))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawLine(
      Offset(glassLeft + 10, glassTop + glassHeight * 0.15),
      Offset(glassLeft + 8, glassBottom - glassHeight * 0.15),
      reflectionPaint,
    );

    // ─── Splash damlaları (taşma) ─────────────────────────────────
    for (final drop in splashDrops) {
      final dropPaint = Paint()
        ..color = Colors.cyanAccent.withValues(alpha: drop.opacity)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(
        Offset(drop.x * size.width, drop.y * size.height),
        drop.radius,
        dropPaint,
      );
    }

    // ─── Doldurma stream (su akışı) ───────────────────────────────
    if (isFilling && !isOverflow) {
      final streamTop = glassTop - size.height * 0.15;
      final clampedW = waterLevel.clamp(0.0, 1.0);
      final streamBottom = glassBottom - (glassHeight * clampedW);

      final streamPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.cyanAccent.withValues(alpha: 0.6),
            const Color(0xFF00D2FF).withValues(alpha: 0.8),
          ],
        ).createShader(Rect.fromLTRB(centerX - 4, streamTop, centerX + 4, streamBottom));

      // Hafif dalgalanan akış
      final streamPath = Path();
      streamPath.moveTo(centerX - 3, streamTop);
      for (double y = streamTop; y <= streamBottom; y += 3) {
        final wobble = sin(y * 0.05 + wavePhase * 2) * 2;
        streamPath.lineTo(centerX - 3 + wobble, y);
      }
      for (double y = streamBottom; y >= streamTop; y -= 3) {
        final wobble = sin(y * 0.05 + wavePhase * 2) * 2;
        streamPath.lineTo(centerX + 3 + wobble, y);
      }
      streamPath.close();
      canvas.drawPath(streamPath, streamPaint);
    }
  }

  @override
  bool shouldRepaint(covariant GlassPainter oldDelegate) {
    return waterLevel != oldDelegate.waterLevel ||
        wavePhase != oldDelegate.wavePhase ||
        bubbles != oldDelegate.bubbles ||
        isOverflow != oldDelegate.isOverflow ||
        showResult != oldDelegate.showResult ||
        isFilling != oldDelegate.isFilling ||
        splashDrops != oldDelegate.splashDrops;
  }
}

/// Kabarcık verisi.
class BubbleParticle {
  double x; // 0-1 (bardak genişliğine göre)
  double y; // 0-1 (bardak yüksekliğine göre, alttan üste)
  double radius;
  double speed;
  double opacity;
  double wobblePhase;

  BubbleParticle({
    required this.x,
    required this.y,
    required this.radius,
    required this.speed,
    this.opacity = 0.7,
    this.wobblePhase = 0.0,
  });
}

/// Splash (taşma) damla verisi.
class SplashDrop {
  double x; // 0-1 (ekran genişliğine göre)
  double y; // 0-1 (ekran yüksekliğine göre)
  double vx;
  double vy;
  double radius;
  double opacity;
  double gravity;

  SplashDrop({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.radius,
    this.opacity = 1.0,
    this.gravity = 0.0003,
  });
}
