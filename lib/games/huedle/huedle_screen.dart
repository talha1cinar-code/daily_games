import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../widgets/game_exit_wrapper.dart';
import '../../services/sound_service.dart';
import '../../services/ticket_service.dart';
import '../../services/stats_service.dart';
import '../../services/leaderboard_service.dart';
import '../../services/personal_best_service.dart';
import '../../services/daily_challenge_service.dart';
import '../../services/language_service.dart';

class HuedleScreen extends StatefulWidget {
  final bool isDailyMode;
  final void Function(double score, [int durationMs])? onGameComplete;
  const HuedleScreen({super.key, this.isDailyMode = true, this.onGameComplete});

  @override
  State<HuedleScreen> createState() => _HuedleScreenState();
}

class _HuedleScreenState extends State<HuedleScreen>
    with TickerProviderStateMixin {
  // ─── Oyun durumu ─────────────────────────────────────────────────
  int _level = 1;
  int _score = 0;
  bool _isGameOver = false;
  int _oddIndex = 0; // Farklı rengin indeksi

  // Renk bilgileri
  late Color _baseColor;
  late Color _oddColor;
  late int _gridSize; // NxN grid boyutu

  // Animasyon
  late AnimationController _shakeController;
  late AnimationController _levelUpController;
  late Animation<double> _shakeAnimation;
  late Animation<double> _levelUpAnimation;

  // Tapped index for wrong answer highlight
  int? _wrongTapIndex;
  bool _showCorrectHighlight = false;

  late final Random _random;
  final SoundService _sound = SoundService();

  DateTime? _gameStartTime;

  // Level geçiş animasyonu
  bool _showLevelUp = false;

  @override
  void initState() {
    super.initState();
    _gameStartTime = DateTime.now();

    // Daily modda seed tabanlı Random, biletli modda rastgele
    if (widget.isDailyMode) {
      _random = Random(DailyChallengeService.getSeededHuedleSeed());
    } else {
      _random = Random();
    }

    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _shakeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.elasticOut),
    );

    _levelUpController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _levelUpAnimation = CurvedAnimation(
      parent: _levelUpController,
      curve: Curves.easeOutBack,
    );

    _generateLevel();
  }

  @override
  void dispose() {
    _shakeController.dispose();
    _levelUpController.dispose();
    super.dispose();
  }

  // ─── Seviye mantığı ──────────────────────────────────────────────
  //
  // Grid boyutu: Level 1 → 2x2, Level 2 → 3x3, ... Level 5 → 6x6
  // Level 6+ → 6x6 sabit, renk farkı azalır
  //
  // Renk farkı (hue offset):
  //   Level 1: büyük fark (kolay)
  //   Level 5+: küçük fark (zor)
  //   Level 6+: grid sabit, sadece fark küçülür

  int _getGridSize() {
    if (_level <= 5) {
      return _level + 1; // 2, 3, 4, 5, 6
    }
    return 6;
  }

  /// Renk farkı hesaplama.
  /// Level arttıkça fark küçülür. HSL lightness farkı kullanılır.
  double _getColorDifference() {
    // Level 1: 0.18 (çok belirgin)
    // Level 5: 0.08 (6x6 grid ile zor)
    // Level 10: 0.035 (çok zor)
    // Level 15: 0.018 (neredeyse imkansız)
    // Level 20+: 0.010 (minimum)
    if (_level <= 5) {
      // Grid büyüyor, renk farkı yavaş azalıyor
      return 0.18 - (_level - 1) * 0.025; // 0.18, 0.155, 0.13, 0.105, 0.08
    } else {
      // Grid sabit 6x6, renk farkı hızlı azalıyor
      final extraLevel = _level - 5;
      final diff = 0.08 - extraLevel * 0.007;
      return diff.clamp(0.008, 0.08);
    }
  }

  void _generateLevel() {
    _gridSize = _getGridSize();
    final totalCells = _gridSize * _gridSize;
    _oddIndex = _random.nextInt(totalCells);

    // Rastgele bir temel renk seç (HSL)
    final hue = _random.nextDouble() * 360;
    final saturation = 0.5 + _random.nextDouble() * 0.4; // 0.5 - 0.9
    final lightness = 0.35 + _random.nextDouble() * 0.3; // 0.35 - 0.65

    _baseColor = HSLColor.fromAHSL(1.0, hue, saturation, lightness).toColor();

    // Farklı renk: lightness'ı kaydır
    final diff = _getColorDifference();
    // Rastgele yukarı veya aşağı kaydır
    double oddLightness;
    if (_random.nextBool()) {
      oddLightness = (lightness + diff).clamp(0.0, 1.0);
    } else {
      oddLightness = (lightness - diff).clamp(0.0, 1.0);
    }
    _oddColor =
        HSLColor.fromAHSL(1.0, hue, saturation, oddLightness).toColor();

    _wrongTapIndex = null;
    _showCorrectHighlight = false;
  }

  // ─── Puan hesaplama ──────────────────────────────────────────────
  /// Her seviye 10 puan; oyun ilk yanlışa kadar sürer
  int _getLevelScore() => 10;

  // ─── Kare tıklama ───────────────────────────────────────────────
  void _onTileTap(int index) {
    if (_isGameOver || _showLevelUp) return;

    if (index == _oddIndex) {
      // Doğru!
      _sound.playKeyTap();
      final levelScore = _getLevelScore();
      setState(() {
        _score += levelScore;
        _showLevelUp = true;
        _showCorrectHighlight = true;
      });
      _levelUpController.forward(from: 0);

      Future.delayed(const Duration(milliseconds: 800), () {
        if (!mounted) return;
        setState(() {
          _level++;
          _showLevelUp = false;
          _generateLevel();
        });
      });
    } else {
      // Yanlış! Oyun bitti
      _sound.playError();
      setState(() {
        _wrongTapIndex = index;
        _showCorrectHighlight = true;
        _isGameOver = true;
      });
      _shakeController.forward(from: 0);

      Future.delayed(const Duration(milliseconds: 1500), () {
        if (mounted) {
          _saveScore();
          _showGameOverDialog();
        }
      });
    }
  }

  // ─── Skor kaydetme ────────────────────────────────────────────
  void _saveScore() {
    _sound.playGameEnd(_score.toDouble());
    final durationMs =
        DateTime.now().difference(_gameStartTime!).inMilliseconds;

    if (widget.onGameComplete != null) {
      final lbScore = LeaderboardService.calculateLeaderboardScore(
        gameId: 'huedle',
        isWin: true,
        score: _score.toDouble(),
        durationMs: durationMs,
      );
      widget.onGameComplete!(lbScore, durationMs);
    } else if (widget.isDailyMode) {
      TicketService().markDailyPlayed('huedle');
      StatsService().saveDailyStat(
        gameId: 'huedle',
        isWin: true,
        score: _score.toDouble(),
        attempts: _level - 1,
        maxAttempts: _level - 1,
        durationMs: durationMs,
      );
      LeaderboardService().submitScore(
        gameId: 'huedle',
        score: LeaderboardService.calculateLeaderboardScore(
          gameId: 'huedle',
          isWin: true,
          score: _score.toDouble(),
          durationMs: durationMs,
        ),
        attempts: _level - 1,
        maxAttempts: _level - 1,
        durationMs: durationMs,
        isWin: true,
      );
    } else {
      PersonalBestService().submit(
        'huedle',
        LeaderboardService.calculateLeaderboardScore(
          gameId: 'huedle',
          isWin: true,
          score: _score.toDouble(),
          durationMs: durationMs,
        ),
      );
    }
  }

  // ─── Oyun sonu dialogu ────────────────────────────────────────
  void _showGameOverDialog() {
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      enableDrag: false,
      builder: (context) => _buildResultSheet(),
    );
  }

  Widget _buildResultSheet() {
    final emoji = _score >= 80
        ? '🏆'
        : _score >= 50
            ? '⭐'
            : _score >= 20
                ? '👍'
                : '😅';
    final title = _score >= 50 ? (LanguageService().currentLanguage == 'tr' ? 'Harika!' : 'Great!') : (LanguageService().currentLanguage == 'tr' ? 'Oyun Bitti!' : 'Game Over!');
    final titleColor =
        _score >= 50 ? Colors.greenAccent : Colors.orangeAccent;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF1A1A2E),
            _score >= 50
                ? const Color(0xFF0A2E1A)
                : const Color(0xFF2E1A0A),
          ],
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          Text(emoji, style: const TextStyle(fontSize: 56)),
          const SizedBox(height: 16),
          Text(
            title,
            style: GoogleFonts.outfit(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: titleColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            LanguageService().currentLanguage == 'tr' ? '$_score Puan' : '$_score Points',
            style: GoogleFonts.outfit(
              fontSize: 28,
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            LanguageService().currentLanguage == 'tr' ? 'Seviye ${_level - 1} • ${_gridSize}x$_gridSize Grid' : 'Level ${_level - 1} • ${_gridSize}x$_gridSize Grid',
            style: GoogleFonts.outfit(
              fontSize: 16,
              color: Colors.white54,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context); // Dialog
                Navigator.pop(context); // Ekran
              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: titleColor.withValues(alpha: 0.2),
                foregroundColor: titleColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: titleColor.withValues(alpha: 0.5),
                  ),
                ),
                elevation: 0,
              ),
              child: Text(
                widget.onGameComplete != null ? (LanguageService().currentLanguage == 'tr' ? 'Sonraki' : 'Next') : (LanguageService().currentLanguage == 'tr' ? 'Kapat' : 'Close'),
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Build ────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return GameExitWrapper(
      gameId: 'huedle', isDailyMode: widget.isDailyMode, onGameComplete: widget.onGameComplete,
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF0D0D1A),
                Color(0xFF1A1A2E),
                Color(0xFF16213E),
              ],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                _buildTopBar(),
                _buildInfoBar(),
                Expanded(child: _buildGameGrid()),
                _buildLevelUpBanner(),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
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
                border:
                    Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: Colors.white70,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Huedle',
                style: GoogleFonts.outfit(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              Text(
                LanguageService().isTurkish ? 'Farklı rengi bul!' : 'Find the different color!',
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  color: Colors.white38,
                ),
              ),
            ],
          ),
          const Spacer(),
          // Skor göstergesi
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.amberAccent.withValues(alpha: 0.15),
                  Colors.orangeAccent.withValues(alpha: 0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: Colors.amberAccent.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.star_rounded,
                    color: Colors.amberAccent, size: 18),
                const SizedBox(width: 6),
                Text(
                  '$_score',
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.amberAccent,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoBar() {

    // Zorluk göstergesi
    String difficultyText;
    Color difficultyColor;
    IconData difficultyIcon;

    if (_level <= 2) {
      difficultyText = LanguageService().isTurkish ? 'Kolay' : 'Easy';
      difficultyColor = Colors.greenAccent;
      difficultyIcon = Icons.sentiment_satisfied_rounded;
    } else if (_level <= 5) {
      difficultyText = LanguageService().isTurkish ? 'Orta' : 'Medium';
      difficultyColor = Colors.orangeAccent;
      difficultyIcon = Icons.sentiment_neutral_rounded;
    } else if (_level <= 10) {
      difficultyText = LanguageService().isTurkish ? 'Zor' : 'Hard';
      difficultyColor = Colors.redAccent;
      difficultyIcon = Icons.sentiment_dissatisfied_rounded;
    } else {
      difficultyText = LanguageService().isTurkish ? 'Uzman' : 'Expert';
      difficultyColor = Colors.purpleAccent;
      difficultyIcon = Icons.local_fire_department_rounded;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: [
          // Seviye
          _buildInfoChip(
            icon: Icons.layers_rounded,
            label: LanguageService().currentLanguage == 'tr' ? 'Seviye $_level' : 'Level $_level',
            color: Colors.cyanAccent,
          ),
          const SizedBox(width: 10),
          // Grid
          _buildInfoChip(
            icon: Icons.grid_on_rounded,
            label: '${_gridSize}x$_gridSize',
            color: Colors.white70,
          ),
          const Spacer(),
          // Zorluk
          _buildInfoChip(
            icon: difficultyIcon,
            label: difficultyText,
            color: difficultyColor,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGameGrid() {
    final totalCells = _gridSize * _gridSize;

    return AnimatedBuilder(
      animation: _shakeController,
      builder: (context, child) {
        final shakeOffset =
            _isGameOver ? sin(_shakeAnimation.value * pi * 4) * 8 : 0.0;
        return Transform.translate(
          offset: Offset(shakeOffset, 0),
          child: child,
        );
      },
      child: Center(
        child: AspectRatio(
          aspectRatio: 1.0,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final spacing = _gridSize <= 3 ? 8.0 : (_gridSize <= 5 ? 5.0 : 4.0);
                final availableSize = constraints.maxWidth;
                final tileSize =
                    (availableSize - spacing * (_gridSize - 1)) / _gridSize;

                return Wrap(
                  spacing: spacing,
                  runSpacing: spacing,
                  children: List.generate(totalCells, (index) {
                    return _buildTile(index, tileSize);
                  }),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTile(int index, double size) {
    final isOdd = index == _oddIndex;
    final color = isOdd ? _oddColor : _baseColor;

    // Highlight durumları
    final isWrongTap = _wrongTapIndex == index;
    final isCorrectHighlight = _showCorrectHighlight && isOdd;

    return GestureDetector(
      onTap: () => _onTileTap(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(
            _gridSize <= 3 ? 16 : (_gridSize <= 5 ? 12 : 8),
          ),
          border: Border.all(
            color: isWrongTap
                ? Colors.redAccent
                : isCorrectHighlight
                    ? Colors.greenAccent
                    : Colors.white.withValues(alpha: 0.05),
            width: isWrongTap || isCorrectHighlight ? 3 : 1,
          ),
          boxShadow: [
            if (isWrongTap)
              BoxShadow(
                color: Colors.redAccent.withValues(alpha: 0.5),
                blurRadius: 12,
                spreadRadius: 2,
              ),
            if (isCorrectHighlight && !isWrongTap)
              BoxShadow(
                color: Colors.greenAccent.withValues(alpha: 0.5),
                blurRadius: 12,
                spreadRadius: 2,
              ),
            BoxShadow(
              color: color.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: isWrongTap
            ? const Center(
                child: Icon(Icons.close_rounded,
                    color: Colors.white, size: 28))
            : isCorrectHighlight
                ? const Center(
                    child: Icon(Icons.check_rounded,
                        color: Colors.white, size: 28))
                : null,
      ),
    );
  }

  Widget _buildLevelUpBanner() {
    if (!_showLevelUp) return const SizedBox(height: 60);

    return AnimatedBuilder(
      animation: _levelUpAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _levelUpAnimation.value,
          child: Opacity(
            opacity: _levelUpAnimation.value.clamp(0, 1),
            child: Container(
              height: 60,
              margin: const EdgeInsets.symmetric(horizontal: 40),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.greenAccent.withValues(alpha: 0.2),
                    Colors.tealAccent.withValues(alpha: 0.15),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: Colors.greenAccent.withValues(alpha: 0.4)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.greenAccent.withValues(alpha: 0.15),
                    blurRadius: 16,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.arrow_upward_rounded,
                        color: Colors.greenAccent, size: 22),
                    const SizedBox(width: 8),
                    Text(
                      LanguageService().currentLanguage == 'tr' ? '+${_getLevelScore()} Puan!' : '+${_getLevelScore()} Points!',
                      style: GoogleFonts.outfit(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.greenAccent,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
