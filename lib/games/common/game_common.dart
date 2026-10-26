import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/leaderboard_service.dart';
import '../../services/personal_best_service.dart';
import '../../services/stats_service.dart';
import '../../services/ticket_service.dart';

/// Oyun bitince skoru doğru yere iletir:
///   - Daily Run içindeyse [onGameComplete],
///   - günlük modda istatistik + sıralama,
///   - bilet modunda kişisel rekor (coin ve seri de buradan işler).
void reportGameScore({
  required String gameId,
  required bool isDailyMode,
  required void Function(double score, [int durationMs])? onGameComplete,
  required double score,
  required int durationMs,
  int attempts = 0,
  int maxAttempts = 0,
  bool isWin = true,
}) {
  if (onGameComplete != null) {
    onGameComplete(score, durationMs);
  } else if (isDailyMode) {
    TicketService().markDailyPlayed(gameId);
    StatsService().saveDailyStat(
      gameId: gameId,
      isWin: isWin,
      score: score,
      attempts: attempts,
      maxAttempts: maxAttempts,
      durationMs: durationMs,
    );
    LeaderboardService().submitScore(
      gameId: gameId,
      score: score,
      attempts: attempts,
      maxAttempts: maxAttempts,
      durationMs: durationMs,
      isWin: isWin,
    );
  } else {
    PersonalBestService().submit(gameId, score);
  }
}

/// Yeni oyunların ortak üst barı: geri (çıkış onayıyla), başlık, alt başlık, sağda skor.
class GameTopBar extends StatelessWidget {
  final String title;
  final String subtitle;
  final String? trailing;
  final Color accent;

  const GameTopBar({super.key, required this.title, required this.subtitle, this.trailing, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.maybePop(context),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white70, size: 20),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: GoogleFonts.nunito(fontSize: 24, fontWeight: FontWeight.w800, color: Colors.white)),
                Text(subtitle, style: GoogleFonts.nunito(fontSize: 12, color: Colors.white54)),
              ],
            ),
          ),
          if (trailing != null)
            Text(trailing!, style: GoogleFonts.nunito(fontSize: 22, fontWeight: FontWeight.w900, color: accent)),
        ],
      ),
    );
  }
}

/// Tur ilerleme noktaları
class RoundDots extends StatelessWidget {
  final int total;
  final int current;
  final int done;
  final Color accent;

  const RoundDots({super.key, required this.total, required this.current, required this.done, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(total, (i) {
        final isCurrent = i == current;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: isCurrent ? 28 : 10,
          height: 10,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: i < done ? accent : (isCurrent ? Colors.white : Colors.white24),
            borderRadius: BorderRadius.circular(5),
          ),
        );
      }),
    );
  }
}
