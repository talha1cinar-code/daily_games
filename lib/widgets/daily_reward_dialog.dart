import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/app_strings.dart';
import '../services/daily_reward_service.dart';
import '../services/sound_service.dart';
import 'chunky_button.dart';
import 'coin_badge.dart';

/// 7 günlük ödül takvimi. Bugünün ödülü vurgulanır; topla deyince coin eklenir.
class DailyRewardDialog extends StatefulWidget {
  const DailyRewardDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.7),
      builder: (_) => const DailyRewardDialog(),
    );
  }

  @override
  State<DailyRewardDialog> createState() => _DailyRewardDialogState();
}

class _DailyRewardDialogState extends State<DailyRewardDialog> {
  int? _claimed;

  Future<void> _claim() async {
    final amount = await DailyRewardService().claim();
    SoundService().playCoin();
    if (!mounted) return;
    setState(() => _claimed = amount);
    await Future.delayed(const Duration(milliseconds: 1100));
    if (mounted) Navigator.pop(context);
  }

  Widget _cell(int i, int today) {
    final amount = DailyRewardService.rewards[i];
    final isToday = i == today;
    final past = i < today || (_claimed != null && isToday);
    final big = i == DailyRewardService.rewards.length - 1;
    return AnimatedScale(
      scale: isToday && _claimed == null ? 1.06 : 1,
      duration: const Duration(milliseconds: 200),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isToday
              ? const Color(0xFFFFB627)
              : past
                  ? const Color(0xFF3DDC84).withValues(alpha: 0.25)
                  : Colors.white.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(16),
          border: isToday ? Border.all(color: Colors.white, width: 2) : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              AppStrings.day(i + 1),
              style: GoogleFonts.nunito(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                color: isToday ? const Color(0xFF5A3A00) : Colors.white70,
              ),
            ),
            const SizedBox(height: 6),
            past
                ? const Icon(Icons.check_circle_rounded, color: Color(0xFF3DDC84), size: 30)
                : big
                    ? const Icon(Icons.redeem_rounded, color: Color(0xFFFFE27A), size: 30)
                    : const CoinIcon(size: 28),
            const SizedBox(height: 4),
            Text(
              '$amount',
              style: GoogleFonts.nunito(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: isToday ? const Color(0xFF5A3A00) : Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final service = DailyRewardService();
    final today = service.currentDay;
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 22, 18, 18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF4A1A8C), Color(0xFF231457)],
          ),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12), width: 2),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.card_giftcard_rounded, color: Color(0xFFFFC233), size: 48),
            const SizedBox(height: 6),
            Text(
              AppStrings.dailyReward,
              style: GoogleFonts.nunito(fontSize: 26, fontWeight: FontWeight.w900, color: Colors.white),
            ),
            const SizedBox(height: 4),
            Text(
              AppStrings.dailyRewardDesc,
              textAlign: TextAlign.center,
              style: GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white70),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                for (var i = 0; i < 4; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  Expanded(child: _cell(i, today)),
                ],
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                for (var i = 4; i < 7; i++) ...[
                  if (i > 4) const SizedBox(width: 8),
                  Expanded(flex: i == 6 ? 2 : 1, child: _cell(i, today)),
                ],
              ],
            ),
            const SizedBox(height: 20),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: _claimed != null
                  ? Row(
                      key: const ValueKey('done'),
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const CoinIcon(size: 32),
                        const SizedBox(width: 8),
                        Text(
                          '+$_claimed',
                          style: GoogleFonts.nunito(fontSize: 30, fontWeight: FontWeight.w900, color: Colors.white),
                        ),
                      ],
                    )
                  : ChunkyButton(
                      key: const ValueKey('claim'),
                      face: const Color(0xFF3DDC84),
                      lip: const Color(0xFF1E9E55),
                      height: 60,
                      onTap: service.canClaim ? _claim : null,
                      child: Text(
                        AppStrings.claim,
                        style: GoogleFonts.nunito(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
