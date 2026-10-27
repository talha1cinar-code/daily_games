import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/app_strings.dart';

class GameResultStat {
  final String label;
  final String value;
  const GameResultStat(this.label, this.value);
}

/// Oyun sonu alt sayfası. Daily Run içindeyse "Sonraki", değilse "Kapat" gösterir.
/// Kapatınca hem sayfayı hem oyun ekranını kapatır.
class GameResultSheet extends StatelessWidget {
  final String title;
  final String headline;
  final String caption;
  final List<GameResultStat> stats;
  final Color accent;
  final bool isDailyRun;

  /// Başlık ile istatistikler arasında ek içerik (ör. emoji ızgarası)
  final Widget? extra;

  const GameResultSheet({
    super.key,
    required this.title,
    required this.headline,
    required this.caption,
    required this.stats,
    required this.accent,
    required this.isDailyRun,
    this.extra,
  });

  static Future<void> show(BuildContext context, GameResultSheet sheet) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      enableDrag: false,
      builder: (_) => sheet,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      decoration: const BoxDecoration(
        color: Color(0xFF1B1B2F),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: GoogleFonts.nunito(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white),
            ),
            const SizedBox(height: 8),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.6, end: 1.0),
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeOutBack,
              builder: (context, v, child) => Transform.scale(scale: v, child: child),
              child: Text(
                headline,
                style: GoogleFonts.nunito(fontSize: 52, fontWeight: FontWeight.w900, color: accent, height: 1.1),
              ),
            ),
            Text(caption, style: GoogleFonts.nunito(fontSize: 14, color: Colors.white54)),
            if (extra != null) ...[const SizedBox(height: 16), extra!],
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  for (final s in stats)
                    Expanded(
                      child: Column(
                        children: [
                          Text(
                            s.value,
                            style: GoogleFonts.nunito(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white),
                          ),
                          const SizedBox(height: 2),
                          Text(s.label, style: GoogleFonts.nunito(fontSize: 12, color: Colors.white54)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: accent,
                  foregroundColor: const Color(0xFF1B1B2F),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: Text(
                  isDailyRun ? AppStrings.next : AppStrings.close,
                  style: GoogleFonts.nunito(fontSize: 17, fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
