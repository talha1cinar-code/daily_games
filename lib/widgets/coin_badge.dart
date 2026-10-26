import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Coin bakiyesi rozeti (HUD, mağaza, ödül ekranları).
class CoinBadge extends StatelessWidget {
  final int amount;
  final VoidCallback? onTap;
  final bool showPlus;

  const CoinBadge({super.key, required this.amount, this.onTap, this.showPlus = false});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 44,
        padding: const EdgeInsets.only(left: 6, right: 12),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.28),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CoinIcon(size: 30),
            const SizedBox(width: 8),
            Text(
              '$amount',
              style: GoogleFonts.nunito(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            if (showPlus) ...[
              const SizedBox(width: 6),
              Container(
                width: 20,
                height: 20,
                decoration: const BoxDecoration(color: Color(0xFF3DDC84), shape: BoxShape.circle),
                child: const Icon(Icons.add_rounded, size: 16, color: Colors.white),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Basit çizilmiş coin: altın daire, koyu kenar, ortada yıldız.
class CoinIcon extends StatelessWidget {
  final double size;
  const CoinIcon({super.key, this.size = 24});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFE27A), Color(0xFFF5A623)],
        ),
        border: Border.all(color: const Color(0xFFC77F00), width: size * 0.07),
      ),
      child: Icon(Icons.star_rounded, size: size * 0.62, color: const Color(0xFFC77F00)),
    );
  }
}
