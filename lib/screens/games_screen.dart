import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../models/game_model.dart';
import '../widgets/game_card.dart';
import '../games/wordle/wordle_screen.dart';
import '../games/wikitrivia/wikitrivia_screen.dart';
import '../games/nerdle/nerdle_screen.dart';
import '../games/worldle/worldle_screen.dart';
import '../games/rgble/rgble_screen.dart';
import '../games/sound/sound_screen.dart';
import '../games/timele/timele_screen.dart';
import '../games/linele/linele_screen.dart';
import '../games/huedle/huedle_screen.dart';
import '../games/fille/fille_screen.dart';
import '../games/memorle/memorle_screen.dart';
import '../games/reactle/reactle_screen.dart';
import '../widgets/game_details_bottom_sheet.dart';
import '../services/sound_service.dart';

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
      Widget? screen;
      if (game.routeName == '/wordle') {
        screen = WordleScreen(isDailyMode: isDailyMode);
      } else if (game.routeName == '/wikitrivia') {
        screen = WikitriviaScreen(isDailyMode: isDailyMode);
      } else if (game.routeName == '/nerdle') {
        screen = NerdleScreen(isDailyMode: isDailyMode);
      } else if (game.routeName == '/worldle') {
        screen = WorldleScreen(isDailyMode: isDailyMode);
      } else if (game.routeName == '/rgble') {
        screen = RgbleScreen(isDailyMode: isDailyMode);
      } else if (game.routeName == '/sound') {
        screen = SoundScreen(isDailyMode: isDailyMode);
      } else if (game.routeName == '/timele') {
        screen = TimeleScreen(isDailyMode: isDailyMode);
      } else if (game.routeName == '/linele') {
        screen = LineleScreen(isDailyMode: isDailyMode);
      } else if (game.routeName == '/huedle') {
        screen = HuedleScreen(isDailyMode: isDailyMode);
      } else if (game.routeName == '/fille') {
        screen = FilleScreen(isDailyMode: isDailyMode);
      } else if (game.routeName == '/memorle') {
        screen = MemorleScreen(isDailyMode: isDailyMode);
      } else if (game.routeName == '/reactle') {
        screen = ReactleScreen(isDailyMode: isDailyMode);
      }

      if (screen != null) {
        // Oyun açılırken müziği durdur
        SoundService().enterMiniGame();
        
        await Navigator.of(context).push(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => screen!,
            transitionDuration: Duration.zero,
            reverseTransitionDuration: Duration.zero,
          ),
        );
        
        // Oyundan çıkınca müziği devam ettir (eğer açıksa)
        if (mounted) {
          SoundService().exitMiniGame();
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF121212),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF5E35B1), // Deep purple top
            Color(0xFF121212), // Dark background bottom
          ],
          stops: [0.0, 0.6],
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
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
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: AppColors.textPrimary,
                        size: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    'Oyunlar',
                    style: GoogleFonts.nunito(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${games.length} oyun',
                      style: GoogleFonts.nunito(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
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
                  mainAxisSpacing: 14,
                  childAspectRatio: 0.88,
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
    ));
  }
}
