import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/app_strings.dart';
import '../services/coin_service.dart';
import 'chunky_button.dart';
import 'coin_badge.dart';

/// Coin karşılığı bir şey teklif eder (ikinci şans, ek süre...). Kabul edilir ve
/// coin yeterliyse harcar ve true döner. Oyun içi kullanım yalnızca bilet
/// modunda olmalı; Daily Run sıralamasını coin etkilememeli.
Future<bool> showCoinOffer(
  BuildContext context, {
  required IconData icon,
  required String title,
  required String description,
  required String confirmLabel,
  required int price,
  required String item,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) {
      final canAfford = CoinService().balance >= price;
      return Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 28),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF4A1A8C), Color(0xFF231457)],
            ),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12), width: 2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: const Color(0xFFFFC233), size: 46),
              const SizedBox(height: 8),
              Text(title, style: GoogleFonts.nunito(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white)),
              const SizedBox(height: 4),
              Text(
                description,
                textAlign: TextAlign.center,
                style: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white70),
              ),
              const SizedBox(height: 12),
              CoinBadge(amount: CoinService().balance),
              const SizedBox(height: 16),
              ChunkyButton(
                face: const Color(0xFF3DDC84),
                lip: const Color(0xFF1E9E55),
                height: 56,
                onTap: canAfford ? () => Navigator.pop(ctx, true) : null,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(confirmLabel,
                        style: GoogleFonts.nunito(fontSize: 19, fontWeight: FontWeight.w900, color: Colors.white)),
                    const SizedBox(width: 10),
                    const CoinIcon(size: 22),
                    const SizedBox(width: 4),
                    Text('$price', style: GoogleFonts.nunito(fontSize: 19, fontWeight: FontWeight.w900, color: Colors.white)),
                  ],
                ),
              ),
              if (!canAfford)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(AppStrings.notEnoughCoins,
                      style: GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.redAccent)),
                ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(AppStrings.noThanks,
                    style: GoogleFonts.nunito(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white60)),
              ),
            ],
          ),
        ),
      );
    },
  );
  if (ok != true) return false;
  return CoinService().spend(price, item);
}
