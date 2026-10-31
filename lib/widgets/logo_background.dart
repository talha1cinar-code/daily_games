import 'package:flutter/material.dart';
import 'dart:math' as math;

class LogoBackground extends StatefulWidget {
  const LogoBackground({super.key});

  @override
  State<LogoBackground> createState() => _LogoBackgroundState();
}

class _LogoBackgroundState extends State<LogoBackground> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  
  final List<String> logos = [
    'assets/images/icons/wordle.png',
    'assets/images/icons/fitle.png',
    'assets/images/icons/huedle.png',
    'assets/images/icons/timele.png',
    'assets/images/icons/sound.png',
    'assets/images/icons/rgble.png',
    'assets/images/icons/reactle.png',
    'assets/images/icons/nerdle.png',
    'assets/images/icons/memorle.png',
    'assets/images/icons/tempole.png',
    'assets/images/icons/quickle.png',
    'assets/images/icons/slicele.png',
    'assets/images/icons/stackle.png',
    'assets/images/icons/mirrorle.png',
  ];

  late List<_LogoItem> items;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 40),
    )..repeat();
    
    // Rastgele logoları oluştur (Sabit bir görünüm için seed kullanabiliriz ama rastgele daha dinamik)
    final random = math.Random(42); 
    items = List.generate(30, (index) {
      return _LogoItem(
        logoPath: logos[random.nextInt(logos.length)],
        initialX: random.nextDouble(), // 0.0 - 1.0 (Genişlik yüzdesi)
        initialY: random.nextDouble(), // 0.0 - 1.0 (Yükseklik yüzdesi)
        size: 25.0 + random.nextDouble() * 30.0, // 25 - 55 arası boyut (çok küçük)
        speedMultiplier: 0.3 + random.nextDouble() * 0.8, // Farklı hızlar
        opacity: 0.03 + random.nextDouble() * 0.05, // 0.03 - 0.08 arası çok saydam
        angle: random.nextDouble() * 2 * math.pi, // Rastgele başlangıç açısı
        spinDirection: random.nextBool() ? 1 : -1, // Dönüş yönü
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final height = constraints.maxHeight;
                
                return Stack(
                  children: items.map((item) {
                    // Yukarıdan aşağı doğru akış
                    double currentY = (item.initialY * height + _controller.value * height * item.speedMultiplier) % (height + 100);
                    currentY -= 50; // Ekranın dışından girmesi/çıkması için tolerans
                    
                    return Positioned(
                      left: item.initialX * width,
                      top: currentY,
                      child: Transform.rotate(
                        angle: item.angle + (_controller.value * math.pi * item.spinDirection),
                        child: Opacity(
                          opacity: item.opacity,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(item.size * 0.24),
                            child: Image.asset(
                              item.logoPath,
                              width: item.size,
                              height: item.size,
                              cacheWidth: 112,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _LogoItem {
  final String logoPath;
  final double initialX;
  final double initialY;
  final double size;
  final double speedMultiplier;
  final double opacity;
  final double angle;
  final int spinDirection;

  _LogoItem({
    required this.logoPath,
    required this.initialX,
    required this.initialY,
    required this.size,
    required this.speedMultiplier,
    required this.opacity,
    required this.angle,
    required this.spinDirection,
  });
}
