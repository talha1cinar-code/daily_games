import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/game_model.dart';
import '../games/game_registry.dart';
import '../widgets/game_card.dart';
import '../widgets/game_details_bottom_sheet.dart';
import '../services/sound_service.dart';
import '../services/personal_best_service.dart';
import '../widgets/streak_celebration.dart';
import '../widgets/coin_badge.dart';
import '../services/app_strings.dart';
import '../widgets/logo_background.dart';

class GamesScreen extends StatefulWidget {
  const GamesScreen({super.key});

  @override
  State<GamesScreen> createState() => _GamesScreenState();
}

class _GamesScreenState extends State<GamesScreen> with TickerProviderStateMixin {
  late final List<AnimationController> _cardControllers;
  late final List<Animation<double>> _cardAnimations;

  @override
  void initState() {
    super.initState();
    _cardControllers = List.generate(
      games.length,
      (index) => AnimationController(
        duration: const Duration(milliseconds: 500),
        vsync: this,
      ),
    );

    _cardAnimations = _cardControllers.map((controller) {
      return CurvedAnimation(
        parent: controller,
        curve: Curves.easeOutBack,
      );
    }).toList();

    _staggerAnimations();
  }

  Future<void> _staggerAnimations() async {
    for (int i = 0; i < _cardControllers.length; i++) {
      await Future.delayed(const Duration(milliseconds: 80));
      if (mounted) {
        _cardControllers[i].forward();
      }
    }
  }

  @override
  void dispose() {
    for (final controller in _cardControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _onGameTap(GameModel game) {
    GameDetailsBottomSheet.show(context, game, (isDailyMode) async {
      final screen = buildGameScreen(game.id, isDailyMode: isDailyMode);

      if (screen != null) {
        // Oyun açılırken müziği durdur
        SoundService().enterMiniGame();
        
        await Navigator.of(context).push(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => screen,
            transitionDuration: Duration.zero,
            reverseTransitionDuration: Duration.zero,
          ),
        );
        
        // Oyundan çıkınca müziği devam ettir (eğer açıksa)
        if (mounted) {
          SoundService().exitMiniGame();
          setState(() {}); // kartlardaki rekor rozetleri güncellensin
          await maybeShowStreakCelebration(context);
          if (!mounted) return;
          _announceResult(game);
          // "Bir tur daha" için detay sayfasını tekrar aç
          _onGameTap(game);
        }
      }
    });
  }

  void _announceResult(GameModel game) {
    final r = PersonalBestService().takeLastResult();
    if (r == null || r.gameId != game.id) return;
    final score = r.score.toStringAsFixed(0);
    final String text;
    if (r.isNewBest) {
      SoundService().playWin();
      text = AppStrings.newPersonalBest(score, r.previousBest!.toStringAsFixed(0));
    } else if (r.isFirst) {
      text = AppStrings.firstScore(score);
    } else {
      text = AppStrings.scoreVsBest(score, r.previousBest!.toStringAsFixed(0));
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(r.isNewBest ? Icons.emoji_events_rounded : Icons.insights_rounded,
                color: r.isNewBest ? const Color(0xFFFFD54F) : Colors.white70),
            const SizedBox(width: 10),
            Expanded(
              child: Text(text, style: GoogleFonts.nunito(fontWeight: FontWeight.w800, color: Colors.white)),
            ),
            const CoinIcon(size: 18),
            const SizedBox(width: 4),
            Text('+${r.coins}', style: GoogleFonts.nunito(fontWeight: FontWeight.w900, color: const Color(0xFFFFC233))),
          ],
        ),
        backgroundColor: const Color(0xFF2A2340),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2E0854), Color(0xFF0F3460), Color(0xFF16213E)],
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            const LogoBackground(),
            SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Üst bar
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                      ),
                      child: Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: Colors.white.withValues(alpha: 0.8),
                        size: 18,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    AppStrings.games,
                    style: GoogleFonts.nunito(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      AppStrings.gameCount(games.length),
                      style: GoogleFonts.nunito(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.white70,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Kaydırılabilir oyun grid'i
            Expanded(
              child: GridView.builder(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: screenWidth > 600 ? 4 : 3,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 18,
                  childAspectRatio: 0.68,
                ),
                itemCount: games.length,
                itemBuilder: (context, index) {
                  return FadeTransition(
                    opacity: _cardAnimations[index],
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 0.3),
                        end: Offset.zero,
                      ).animate(_cardAnimations[index]),
                      child: GameCard(
                        game: games[index],
                        index: index,
                        onTap: games[index].isComingSoon
                            ? null
                            : () => _onGameTap(games[index]),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    ],
  ),
));
  }
}
