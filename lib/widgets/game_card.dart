import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../models/game_model.dart';
import '../services/sound_service.dart';

class GameCard extends StatefulWidget {
  final GameModel game;
  final int index;
  final VoidCallback? onTap;

  const GameCard({
    super.key,
    required this.game,
    required this.index,
    this.onTap,
  });

  @override
  State<GameCard> createState() => _GameCardState();
}

class _GameCardState extends State<GameCard> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.92).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gradientColors = AppColors.cardGradients[
        widget.index % AppColors.cardGradients.length];
    final glowColor = gradientColors[0];

    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: child,
        );
      },
      child: GestureDetector(
        onTapDown: (_) => _controller.forward(),
        onTapUp: (_) => _controller.reverse(),
        onTapCancel: () => _controller.reverse(),
        onTap: () {
          SoundService().playKeyTap();
          if (!widget.game.isComingSoon && widget.onTap != null) {
            widget.onTap!();
          } else if (widget.game.isComingSoon) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  '${widget.game.name} yakında geliyor! 🎮',
                  style: GoogleFonts.nunito(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                backgroundColor: gradientColors[1],
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                margin: const EdgeInsets.all(16),
                duration: const Duration(seconds: 2),
              ),
            );
          }
        },
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: glowColor, width: 2.5),
            boxShadow: [
              BoxShadow(
                color: glowColor.withValues(alpha: 0.4),
                blurRadius: 14,
                spreadRadius: 1,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Oyun görseli — tüm alanı kaplıyor
                widget.game.imagePath != null
                    ? Image.asset(
                        widget.game.imagePath!,
                        fit: BoxFit.cover,
                      )
                    : Container(
                        color: glowColor.withValues(alpha: 0.15),
                        child: Center(
                          child: Icon(
                            widget.game.icon,
                            color: Colors.white,
                            size: 40,
                          ),
                        ),
                      ),
                // Alt gradient overlay — oyun adı için
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(8, 20, 8, 8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.85),
                        ],
                      ),
                    ),
                    child: Text(
                      widget.game.name,
                      style: GoogleFonts.nunito(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        shadows: [
                          Shadow(color: glowColor, blurRadius: 8),
                          const Shadow(color: Colors.black, blurRadius: 4),
                        ],
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                // Yakında gelecek ise üstüne overlay
                if (widget.game.isComingSoon)
                  Container(
                    color: Colors.black.withValues(alpha: 0.5),
                    child: Center(
                      child: Text(
                        'Yakında',
                        style: GoogleFonts.nunito(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
