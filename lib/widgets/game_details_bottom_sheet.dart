import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/game_model.dart';
import '../services/ticket_service.dart';
import '../services/ad_service.dart';
import '../services/app_strings.dart';
import '../services/coin_service.dart';
import '../services/personal_best_service.dart';

class GameDetailsBottomSheet extends StatefulWidget {
  final GameModel game;
  final Function(bool isDailyMode) onPlay;

  const GameDetailsBottomSheet({
    super.key,
    required this.game,
    required this.onPlay,
  });

  static void show(BuildContext context, GameModel game, Function(bool) onPlay) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => GameDetailsBottomSheet(
        game: game,
        onPlay: onPlay,
      ),
    );
  }

  @override
  State<GameDetailsBottomSheet> createState() => _GameDetailsBottomSheetState();
}

class _GameDetailsBottomSheetState extends State<GameDetailsBottomSheet> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // Bilet sayacının canlı güncellenmesi için saniyede bir UI yenileniyor
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Color(0xFF181A30),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: AnimatedBuilder(
        animation: TicketService(),
        builder: (context, child) {
          final ticketState = TicketService().getTicketState(widget.game.id);
          final timeUntilNext = TicketService().getTimeUntilNextTicket(widget.game.id);
          final timeUntilNextAd = TicketService().getTimeUntilNextAd(widget.game.id);

          String? timerStr;
          if (timeUntilNext != null) {
            timerStr = '${timeUntilNext.inMinutes.toString().padLeft(2, '0')}:${(timeUntilNext.inSeconds % 60).toString().padLeft(2, '0')}';
          }
          
          String? adTimerStr;
          if (timeUntilNextAd != null) {
            adTimerStr = '${timeUntilNextAd.inMinutes.toString().padLeft(2, '0')}:${(timeUntilNextAd.inSeconds % 60).toString().padLeft(2, '0')}';
          }

          return SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
              // Üst İkon ve Başlık
              Container(
                padding: EdgeInsets.all(widget.game.imagePath != null ? 0 : 16),
                decoration: BoxDecoration(
                  color: widget.game.imagePath != null ? Colors.transparent : Colors.white10,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: widget.game.imagePath != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(22),
                        child: Image.asset(widget.game.imagePath!, width: 88, height: 88, fit: BoxFit.cover, cacheWidth: 264),
                      )
                    : Icon(widget.game.icon, size: 40, color: Colors.white),
              ),
              const SizedBox(height: 16),
              Text(
                widget.game.name,
                style: GoogleFonts.nunito(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              if (widget.game.tagline.isNotEmpty)
                Text(
                  widget.game.tagline.toUpperCase(),
                  style: GoogleFonts.nunito(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5,
                    color: Colors.white54,
                  ),
                ),
              if (PersonalBestService().best(widget.game.id) != null) ...[
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.emoji_events_rounded, color: Color(0xFFFFD54F), size: 18),
                    const SizedBox(width: 6),
                    Text(
                      AppStrings.personalBest(PersonalBestService().best(widget.game.id)!.toStringAsFixed(0)),
                      style: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white),
                    ),
                  ],
                ),
              ],
              if (widget.game.howTo.isNotEmpty) ...[
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppStrings.howToPlay,
                        style: GoogleFonts.nunito(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.game.howTo,
                        style: GoogleFonts.nunito(
                          fontSize: 14,
                          height: 1.4,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 24),

              // OYNA BUTONU
              if (ticketState.tickets > 0)
                _buildPlayButton(
                  title: AppStrings.play,
                  subtitle: AppStrings.ticketsRemaining(ticketState.tickets, TicketService.maxTickets),
                  timerText: ticketState.tickets < TicketService.maxTickets && timerStr != null ? AppStrings.nextTicket(timerStr) : null,
                  icon: Icons.confirmation_num_rounded,
                  gradientColors: [const Color(0xFFFFAB40), const Color(0xFFFF6D00)], // Turuncu
                  shadowColor: const Color(0xFFFFAB40),
                  onTap: () {
                    final success = TicketService().useTicket(widget.game.id);
                    if (success) {
                      Navigator.pop(context);
                      widget.onPlay(false);
                    }
                  },
                )
              else ...[
                _buildPlayButton(
                  title: AppStrings.ticketsUsedUp,
                  subtitle: timerStr != null ? AppStrings.renewalTimer(timerStr) : AppStrings.waiting,
                  timerText: null,
                  icon: Icons.timer_outlined,
                  gradientColors: [Colors.grey.shade700, Colors.grey.shade900],
                  shadowColor: Colors.transparent,
                  onTap: null, // Devre dışı
                ),
                const SizedBox(height: 12),
                if (adTimerStr != null)
                  _buildPlayButton(
                    title: AppStrings.adWaiting,
                    subtitle: AppStrings.adTimer(adTimerStr),
                    timerText: null,
                    icon: Icons.timer_outlined,
                    gradientColors: [Colors.grey.shade700, Colors.grey.shade900],
                    shadowColor: Colors.transparent,
                    onTap: null, // Devre dışı
                  )
                else
                  _buildPlayButton(
                    title: AppStrings.refillTickets,
                    subtitle: AppStrings.watchAdRefill,
                    timerText: null,
                    icon: Icons.live_tv_rounded,
                    gradientColors: [Colors.blue.shade400, Colors.blue.shade700],
                    shadowColor: Colors.blue.shade400,
                    onTap: () {
                      AdService().showRewardedAd(
                        onUserEarnedReward: () {
                          TicketService().resetTickets(widget.game.id);
                        },
                      );
                    },
                  ),
                const SizedBox(height: 12),
                _buildPlayButton(
                  title: AppStrings.refillWithCoins(CoinService.ticketRefillPrice),
                  subtitle: '${AppStrings.balance}: ${CoinService().balance}',
                  timerText: null,
                  icon: Icons.toll_rounded,
                  gradientColors: [const Color(0xFFFFC233), const Color(0xFFE08A00)],
                  shadowColor: const Color(0xFFFFC233),
                  onTap: CoinService().balance >= CoinService.ticketRefillPrice
                      ? () async {
                          if (await CoinService().spend(CoinService.ticketRefillPrice, 'ticket_refill')) {
                            TicketService().refillWithCoins(widget.game.id);
                          }
                        }
                      : null,
                ),
              ],

              const SizedBox(height: 16),

            ],
          ));
        },
      ),
    );
  }

  Widget _buildPlayButton({
    required String title,
    required String subtitle,
    required String? timerText,
    required IconData icon,
    required List<Color> gradientColors,
    required Color shadowColor,
    required VoidCallback? onTap,
  }) {
    final glowColor = gradientColors[0];
    return GestureDetector(
      onTap: onTap,
      child: AnimatedOpacity(
        opacity: onTap == null ? 0.45 : 1.0,
        duration: const Duration(milliseconds: 200),
        child: Container(
          width: double.infinity,
          height: 68,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: gradientColors,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              if (onTap != null)
                BoxShadow(
                  color: glowColor.withValues(alpha: 0.35),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: Colors.white, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    title,
                    style: GoogleFonts.nunito(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 1.0,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                timerText != null ? '$subtitle  •  $timerText' : subtitle,
                style: GoogleFonts.nunito(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.white.withValues(alpha: 0.85),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

}
