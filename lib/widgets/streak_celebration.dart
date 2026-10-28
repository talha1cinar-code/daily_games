import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/app_strings.dart';
import '../services/sound_service.dart';
import '../services/streak_service.dart';
import '../services/daily_run_service.dart';
import 'chunky_button.dart';
import 'streak_style.dart';

/// Günün ilk oyunu bitince bir kez gösterilir (Duolingo'daki seri ekranı gibi).
Future<void> maybeShowStreakCelebration(BuildContext context) async {
  // Seri güncellemesi oyun bitişinde asenkron çalışır; kısa bir pay bırak
  await Future.delayed(const Duration(milliseconds: 150));
  if (!context.mounted || !StreakService().shouldCelebrate) return;
  await StreakService().markCelebrated();
  if (!context.mounted) return;
  SoundService().playReward();
  await Navigator.of(context).push(
    PageRouteBuilder(
      opaque: false,
      barrierDismissible: false,
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (_, a, _) => FadeTransition(opacity: a, child: const _StreakCelebration()),
    ),
  );
}

class _StreakCelebration extends StatefulWidget {
  const _StreakCelebration();

  @override
  State<_StreakCelebration> createState() => _StreakCelebrationState();
}

class _StreakCelebrationState extends State<_StreakCelebration> with TickerProviderStateMixin {
  late final AnimationController _pop = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
    ..forward();
  late final AnimationController _flicker = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pop.dispose();
    _flicker.dispose();
    super.dispose();
  }

  String _dayLetter(int weekday) => [
    AppStrings.mon,
    AppStrings.tue,
    AppStrings.wed,
    AppStrings.thu,
    AppStrings.fri,
    AppStrings.sat,
    AppStrings.sun,
  ][weekday - 1];

  @override
  Widget build(BuildContext context) {
    final s = StreakService();
    final n = s.currentStreak;
    final milestone = StreakService.milestones.contains(n);
    final now = DailyRunService.turkeyNow;
    final today = DateTime.utc(now.year, now.month, now.day);
    final active = s.activeDays;
    final frozen = s.frozenDays;
    final tier = StreakTier.of(n);
    final mood = StreakMood.of(s);
    // Bugün yeni bir alev kademesine geçtiyse kutla
    final newTier = n == tier.minDays && n > 1;

    return Scaffold(
      backgroundColor: const Color(0xF2140A2E),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const Spacer(),
              AnimatedBuilder(
                animation: Listenable.merge([_pop, _flicker]),
                builder: (context, _) {
                  final pop = Curves.elasticOut.transform(_pop.value.clamp(0.0, 1.0));
                  return Transform.scale(
                    scale: 0.4 + pop * 0.6,
                    child: StreakFlame(streak: n, size: 170),
                  );
                },
              ),
              TweenAnimationBuilder<double>(
                tween: Tween(begin: (n - 1).toDouble(), end: n.toDouble()),
                duration: const Duration(milliseconds: 900),
                curve: Curves.easeOutCubic,
                builder: (context, v, _) => Text(
                  v.round().toString(),
                  style: GoogleFonts.nunito(fontSize: 96, fontWeight: FontWeight.w900, color: tier.glow, height: 1),
                ),
              ),
              Text(
                AppStrings.streakDayTitle,
                style: GoogleFonts.nunito(fontSize: 26, fontWeight: FontWeight.w900, color: Colors.white),
              ),
              const SizedBox(height: 10),
              if (newTier) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                  decoration: BoxDecoration(color: tier.color, borderRadius: BorderRadius.circular(14)),
                  child: Text(
                    '${AppStrings.newFlameTier}: ${tier.name}',
                    style: GoogleFonts.nunito(fontSize: 15, fontWeight: FontWeight.w900, color: Colors.white),
                  ),
                ),
              ],
              const SizedBox(height: 4),
              Text(
                milestone ? AppStrings.streakMilestone(n) : mood.line,
                textAlign: TextAlign.center,
                style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white70),
              ),
              const SizedBox(height: 28),
              // Son 7 gün
              Container(
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    for (var i = 6; i >= 0; i--)
                      Builder(
                        builder: (context) {
                          final d = today.subtract(Duration(days: i));
                          final key = StreakService.keyOf(d);
                          final isActive = active.contains(key);
                          final isFrozen = frozen.contains(key);
                          return Column(
                            children: [
                              Text(
                                _dayLetter(d.weekday),
                                style: GoogleFonts.nunito(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w900,
                                  color: i == 0 ? Colors.white : Colors.white54,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isActive
                                      ? tier.color
                                      : isFrozen
                                      ? const Color(0xFF4FC3F7)
                                      : Colors.white.withValues(alpha: 0.1),
                                ),
                                child: Icon(
                                  isActive
                                      ? Icons.local_fire_department_rounded
                                      : isFrozen
                                      ? Icons.ac_unit_rounded
                                      : null,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                  ],
                ),
              ),
              if (s.earnedFreezeToday) ...[
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.ac_unit_rounded, color: Color(0xFF6FD6FF)),
                    const SizedBox(width: 6),
                    Text(
                      AppStrings.freezeEarnedLong,
                      style: GoogleFonts.nunito(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF6FD6FF),
                      ),
                    ),
                  ],
                ),
              ],
              const Spacer(),
              ChunkyButton(
                face: tier.color,
                lip: Color.lerp(tier.color, Colors.black, 0.3)!,
                height: 60,
                onTap: () => Navigator.pop(context),
                child: Text(
                  AppStrings.continueButton,
                  style: GoogleFonts.nunito(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
