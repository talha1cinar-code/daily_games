import 'dart:async';
import '../../services/app_strings.dart';
import 'dart:math';
import 'package:flutter/material.dart';
import '../../widgets/game_exit_wrapper.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/sound_service.dart';
import '../../services/daily_challenge_service.dart';
import '../../services/ticket_service.dart';
import '../../services/stats_service.dart';
import '../../services/leaderboard_service.dart';
import '../../services/personal_best_service.dart';
import 'rgble_game.dart';
import '../../services/language_service.dart';

/// RGBle oyun ekranı — 3 round'luk renk eşleştirme.
///
/// Akış: Başla → Hazır/Başla animasyonu → Renk göster (5sn geri sayım)
///       → HSV renk seçici → Puan → Sonraki round...  → Final skor
class RgbleScreen extends StatefulWidget {
  final bool isDailyMode;
  final void Function(double score, [int durationMs])? onGameComplete;
  const RgbleScreen({super.key, this.isDailyMode = true, this.onGameComplete});

  @override
  State<RgbleScreen> createState() => _RgbleScreenState();
}

enum _GamePhase {
  idle,        // Başla butonu
  countdown,   // "Hazır... Başla!" animasyonu
  showColor,   // Hedef renk gösterimi + 5sn geri sayım
  pickColor,   // HSV renk seçici
  showScore,   // Round puanı gösterimi
  gameOver,    // Final skor
}

class _RgbleScreenState extends State<RgbleScreen>
    with TickerProviderStateMixin {
  late RgbleGame _game;
  bool _isLoading = true;
  final SoundService _sound = SoundService();

  _GamePhase _phase = _GamePhase.idle;

  // Geri sayım
  int _countdownValue = 5;
  Timer? _countdownTimer;

  // Hazır/Başla animasyonu
  String _countdownText = '';
  late AnimationController _textScaleController;
  late Animation<double> _textScaleAnimation;

  // HSV renk seçici state
  double _hue = 0.0;        // 0 - 360
  double _saturation = 1.0;  // 0 - 1
  double _brightness = 1.0;  // 0 - 1

  // Son round puanı
  double _lastRoundScore = 0.0;

  // Puan animasyonu
  late AnimationController _scoreAnimController;
  late Animation<double> _scoreAnimation;

  // Geri sayım animasyonu
  late AnimationController _cdAnimController;
  late Animation<double> _cdAnimation;

  @override
  void initState() {
    super.initState();

    _textScaleController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _textScaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _textScaleController, curve: Curves.elasticOut),
    );

    _scoreAnimController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _scoreAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _scoreAnimController, curve: Curves.elasticOut),
    );

    _cdAnimController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _cdAnimation = Tween<double>(begin: 1.5, end: 1.0).animate(
      CurvedAnimation(parent: _cdAnimController, curve: Curves.easeOutBack),
    );

    _initGame();
  }

  Future<void> _initGame() async {
    List<Color>? colors;
    if (widget.isDailyMode) {
      colors = DailyChallengeService.getSeededRgbleColors();
    }
    
    setState(() {
      _game = RgbleGame(externalColors: colors);
      _isLoading = false;
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _textScaleController.dispose();
    _scoreAnimController.dispose();
    _cdAnimController.dispose();
    super.dispose();
  }

  Color get _selectedColor => HSVColor.fromAHSV(
        1.0, _hue, _saturation, _brightness,
      ).toColor();

  // ─── Oyun Akışı ───────────────────────────────────────────────────
  void _startGame() {
    setState(() => _phase = _GamePhase.countdown);
    _playCountdownAnimation();
  }

  Future<void> _playCountdownAnimation() async {
    // "Hazır" / "Ready"
    setState(() => _countdownText = LanguageService().isTurkish ? 'Hazır' : 'Ready');
    _textScaleController.forward(from: 0.0);
    _sound.playFlip();
    await Future.delayed(const Duration(milliseconds: 1000));
    if (!mounted) return;

    // "Başla!" / "Go!"
    setState(() => _countdownText = LanguageService().isTurkish ? 'Başla!' : 'Go!');
    _textScaleController.forward(from: 0.0);
    _sound.playGo();
    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;

    _startShowColor();
  }

  void _startShowColor() {
    setState(() {
      _phase = _GamePhase.showColor;
      _countdownValue = 5;
    });
    _cdAnimController.forward(from: 0.0);
    _sound.playFlip();

    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => _countdownValue--);
      _cdAnimController.forward(from: 0.0);
      _sound.playKeyTap();

      if (_countdownValue <= 0) {
        timer.cancel();
        _startPickColor();
      }
    });
  }

  void _startPickColor() {
    // Slider'ları rastgele pozisyona koy (hile yapılmasın)
    final rng = Random();
    setState(() {
      _phase = _GamePhase.pickColor;
      _hue = rng.nextDouble() * 360;
      _saturation = 0.5 + rng.nextDouble() * 0.5;
      _brightness = 0.5 + rng.nextDouble() * 0.5;
    });
  }

  void _submitGuess() {
    final score = _game.submitGuess(_selectedColor);
    setState(() {
      _lastRoundScore = score;
      _phase = _GamePhase.showScore;
    });
    _scoreAnimController.forward(from: 0.0);

    if (score >= 8.0) {
      _sound.playCorrect();
    } else {
      _sound.playFlip();
    }
  }

  void _nextRound() {
    if (_game.isGameOver) {
      setState(() => _phase = _GamePhase.gameOver);
      
      final isWin = _game.totalScore >= RgbleGame.maxTotal * 0.6;
      if (isWin) {
        _sound.playWin();
      } else {
        _sound.playLose();
      }
      
      if (widget.onGameComplete != null) {
        final score = LeaderboardService.calculateLeaderboardScore(
          gameId: 'rgble',
          isWin: isWin,
          score: _game.totalScore,
        );
        widget.onGameComplete!(score);
      } else if (widget.isDailyMode) {
        TicketService().markDailyPlayed('rgble');
        StatsService().saveDailyStat(
          gameId: 'rgble',
          isWin: isWin,
          score: _game.totalScore,
          attempts: _game.roundScores.length,
          maxAttempts: RgbleGame.totalRounds,
        );
        LeaderboardService().submitScore(
          gameId: 'rgble',
          score: LeaderboardService.calculateLeaderboardScore(
            gameId: 'rgble',
            isWin: isWin,
            score: _game.totalScore,
          ),
          attempts: _game.roundScores.length,
          maxAttempts: RgbleGame.totalRounds,
          isWin: isWin,
        );
      } else {
        PersonalBestService().submit(
          'rgble',
          LeaderboardService.calculateLeaderboardScore(
            gameId: 'rgble',
            isWin: isWin,
            score: _game.totalScore,
          ),
        );
      }
    } else {
      _startShowColor();
    }
  }

  // ─── Build ────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF1B1B2F),
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return GameExitWrapper(gameId: 'rgble', isDailyMode: widget.isDailyMode, onGameComplete: widget.onGameComplete, child: Scaffold(
      backgroundColor: const Color(0xFF1B1B2F),
      body: SafeArea(
        child: switch (_phase) {
          _GamePhase.idle => _buildIdleScreen(),
          _GamePhase.countdown => _buildCountdownScreen(),
          _GamePhase.showColor => _buildShowColorScreen(),
          _GamePhase.pickColor => _buildPickColorScreen(),
          _GamePhase.showScore => _buildShowScoreScreen(),
          _GamePhase.gameOver => _buildGameOverScreen(),
        },
      ),
    ));
  }

  // ═════════════════════════════════════════════════════════════════
  //  PHASE 1: Idle — Başla Ekranı
  // ═════════════════════════════════════════════════════════════════
  Widget _buildIdleScreen() {
    return Column(
      children: [
        _buildTopBar(),
        Expanded(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Renk çemberi ikonu
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: 1.0),
                  duration: const Duration(milliseconds: 800),
                  curve: Curves.elasticOut,
                  builder: (context, value, child) =>
                      Transform.scale(scale: value, child: child),
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const SweepGradient(
                        colors: [
                          Colors.red,
                          Colors.yellow,
                          Colors.green,
                          Colors.cyan,
                          Colors.blue,
                          Colors.purple,
                          Colors.red,
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.purple.withValues(alpha: 0.3),
                          blurRadius: 30,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFF1B1B2F),
                        ),
                        child: const Icon(
                          Icons.palette_rounded,
                          color: Colors.white,
                          size: 36,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [
                      Color(0xFFFF6B6B),
                      Color(0xFFFECE54),
                      Color(0xFF6BCB77),
                      Color(0xFF74B9FF),
                      Color(0xFFA29BFE),
                    ],
                  ).createShader(bounds),
                  child: Text(
                    'RGBle',
                    style: GoogleFonts.nunito(
                      fontSize: 42,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: 3,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  LanguageService().isTurkish ? 'Rengi gör, rengi bul!' : 'See the color, find the color!',
                  style: GoogleFonts.nunito(
                    fontSize: 16,
                    color: Colors.white.withValues(alpha: 0.4),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  LanguageService().currentLanguage == 'tr'
                      ? '${RgbleGame.totalRounds} round • 10 puan/round • ${RgbleGame.maxTotal.toInt()} toplam'
                      : '${RgbleGame.totalRounds} rounds • 10 points/round • ${RgbleGame.maxTotal.toInt()} total',
                  style: GoogleFonts.nunito(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.25),
                  ),
                ),
                const SizedBox(height: 40),
                // Başla butonu
                GestureDetector(
                  onTap: _startGame,
                  child: Container(
                    width: 180,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF6C5CE7), Color(0xFFA29BFE)],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF6C5CE7).withValues(alpha: 0.4),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        AppStrings.start,
                        style: GoogleFonts.nunito(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ═════════════════════════════════════════════════════════════════
  //  PHASE 2: Countdown — "Hazır... Başla!"
  // ═════════════════════════════════════════════════════════════════
  Widget _buildCountdownScreen() {
    return Center(
      child: AnimatedBuilder(
        animation: _textScaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _textScaleAnimation.value,
            child: Opacity(
              opacity: _textScaleAnimation.value.clamp(0.0, 1.0),
              child: child,
            ),
          );
        },
        child: Text(
          _countdownText,
          style: GoogleFonts.nunito(
            fontSize: 64,
            fontWeight: FontWeight.w700,
            color: (_countdownText == 'Başla!' || _countdownText == 'Go!')
                ? const Color(0xFF6BCB77)
                : Colors.white,
            letterSpacing: 4,
          ),
        ),
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════════
  //  PHASE 3: Show Color — Hedef renk + Geri sayım
  // ═════════════════════════════════════════════════════════════════
  Widget _buildShowColorScreen() {
    return Stack(
      children: [
        // Tam ekran hedef renk
        AnimatedContainer(
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            color: _game.currentTargetColor,
          ),
        ),
        // Üstte round bilgisi
        Positioned(
          top: 16,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                LanguageService().isTurkish ? 'Bu rengi hatırla!' : 'Remember this color!',
                style: GoogleFonts.nunito(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
        // Round göstergesi
        Positioned(
          top: 16,
          left: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '${_game.currentRound + 1} / ${RgbleGame.totalRounds}',
              style: GoogleFonts.nunito(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ),
        // Sağ üst geri sayım
        Positioned(
          top: 12,
          right: 16,
          child: AnimatedBuilder(
            animation: _cdAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _cdAnimation.value,
                child: child,
              );
            },
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _countdownValue <= 2
                    ? const Color(0xFFFF6B6B).withValues(alpha: 0.9)
                    : Colors.black.withValues(alpha: 0.4),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.5),
                  width: 3,
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                '$_countdownValue',
                style: GoogleFonts.nunito(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ═════════════════════════════════════════════════════════════════
  //  PHASE 4: Pick Color — HSV Renk Seçici
  // ═════════════════════════════════════════════════════════════════
  Widget _buildPickColorScreen() {
    return Column(
      children: [
        // Üst bar — round bilgisi
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${_game.currentRound + 1} / ${RgbleGame.totalRounds}',
                  style: GoogleFonts.nunito(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
              ),
              const Spacer(),
              Text(
                LanguageService().isTurkish ? 'Rengi bul!' : 'Find the color!',
                style: GoogleFonts.nunito(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: 0.6),
                ),
              ),
              const Spacer(),
              // Puan göstergesi
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF6C5CE7).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '⭐ ${_game.totalScore.toStringAsFixed(1)}',
                  style: GoogleFonts.nunito(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFFA29BFE),
                  ),
                ),
              ),
            ],
          ),
        ),
        // HSV renk seçici alanı
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Sol: Hue slider (dikey gökkuşağı)
                _buildHueSlider(),
                const SizedBox(width: 8),
                // Orta: Saturation/Brightness 2D panel
                _buildSatBrightPanel(),
                const SizedBox(width: 8),
                // Sağ: Seçilen renk önizleme
                Expanded(child: _buildColorPreview()),
              ],
            ),
          ),
        ),
        // Alt: Tahmin Et butonu
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: _buildSubmitButton(),
        ),
      ],
    );
  }

  /// Dikey Hue slider — gökkuşağı gradyanı
  Widget _buildHueSlider() {
    return SizedBox(
      width: 40,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final height = constraints.maxHeight;
          return GestureDetector(
            onVerticalDragUpdate: (details) {
              final dy = details.localPosition.dy.clamp(0.0, height);
              setState(() => _hue = (dy / height) * 360);
            },
            onTapDown: (details) {
              final dy = details.localPosition.dy.clamp(0.0, height);
              setState(() => _hue = (dy / height) * 360);
            },
            child: Stack(
              children: [
                // Gökkuşağı gradyanı
                Container(
                  width: 40,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0xFFFF0000), // Red
                        Color(0xFFFFFF00), // Yellow
                        Color(0xFF00FF00), // Green
                        Color(0xFF00FFFF), // Cyan
                        Color(0xFF0000FF), // Blue
                        Color(0xFFFF00FF), // Magenta
                        Color(0xFFFF0000), // Red (tekrar)
                      ],
                    ),
                  ),
                ),
                // Thumb
                Positioned(
                  top: (_hue / 360) * height - 10,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        border: Border.all(
                          color: HSVColor.fromAHSV(1.0, _hue, 1.0, 1.0)
                              .toColor(),
                          width: 3,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// Saturation (x) × Brightness (y) 2D panel
  Widget _buildSatBrightPanel() {
    return SizedBox(
      width: 48,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final height = constraints.maxHeight;
          final width = constraints.maxWidth;
          final hueColor = HSVColor.fromAHSV(1.0, _hue, 1.0, 1.0).toColor();

          return GestureDetector(
            onVerticalDragUpdate: (details) {
              _updateSatBright(details.localPosition, width, height);
            },
            onTapDown: (details) {
              _updateSatBright(details.localPosition, width, height);
            },
            child: Stack(
              children: [
                // Arka plan: saturation (sol→sağ) × brightness (üst→alt)
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: CustomPaint(
                      size: Size(width, height),
                      painter: _SatBrightPainter(hueColor),
                    ),
                  ),
                ),
                // Thumb
                Positioned(
                  left: _saturation * width - 10,
                  top: (1 - _brightness) * height - 10,
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      border: Border.all(
                        color: _selectedColor,
                        width: 3,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _updateSatBright(Offset pos, double width, double height) {
    setState(() {
      _saturation = (pos.dx / width).clamp(0.0, 1.0);
      _brightness = 1.0 - (pos.dy / height).clamp(0.0, 1.0);
    });
  }

  /// Seçilen renk önizleme alanı (büyük kutu)
  Widget _buildColorPreview() {
    return Container(
      decoration: BoxDecoration(
        color: _selectedColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.15),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: _selectedColor.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
    );
  }

  /// Tahmin Et butonu
  Widget _buildSubmitButton() {
    return GestureDetector(
      onTap: _submitGuess,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF6C5CE7), Color(0xFFA29BFE)],
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF6C5CE7).withValues(alpha: 0.4),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.colorize_rounded, color: Colors.white, size: 22),
            const SizedBox(width: 10),
            Text(
              LanguageService().currentLanguage == 'tr' ? 'Tahmin Et' : 'Guess',
              style: GoogleFonts.nunito(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════════
  //  PHASE 5: Show Score — Round puanı
  // ═════════════════════════════════════════════════════════════════
  Widget _buildShowScoreScreen() {
    final targetColor = _game.targetColors[_game.currentRound - 1];
    final guessColor = _game.guessedColors.last;
    final emoji = RgbleGame.getScoreEmoji(_lastRoundScore);

    return Center(
      child: AnimatedBuilder(
        animation: _scoreAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scoreAnimation.value,
            child: Opacity(
              opacity: _scoreAnimation.value.clamp(0.0, 1.0),
              child: child,
            ),
          );
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Round ${_game.currentRound}',
              style: GoogleFonts.nunito(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.white.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 20),
            // Renk karşılaştırma
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildColorBox(targetColor, LanguageService().isTurkish ? 'Hedef' : 'Target'),
                const SizedBox(width: 16),
                Icon(Icons.compare_arrows_rounded,
                    color: Colors.white.withValues(alpha: 0.4), size: 28),
                const SizedBox(width: 16),
                _buildColorBox(guessColor, LanguageService().isTurkish ? 'Senin' : 'Yours'),
              ],
            ),
            const SizedBox(height: 32),
            // Emoji
            Text(emoji, style: const TextStyle(fontSize: 56)),
            const SizedBox(height: 12),
            // Puan
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _lastRoundScore.toStringAsFixed(1),
                  style: GoogleFonts.nunito(
                    fontSize: 56,
                    fontWeight: FontWeight.w700,
                    color: _getScoreColor(_lastRoundScore),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(
                    ' / 10',
                    style: GoogleFonts.nunito(
                      fontSize: 22,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withValues(alpha: 0.4),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${LanguageService().isTurkish ? 'Toplam' : 'Total'}: ${_game.totalScore.toStringAsFixed(1)}',
              style: GoogleFonts.nunito(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.white.withValues(alpha: 0.4),
              ),
            ),
            const SizedBox(height: 36),
            // Devam butonu
            GestureDetector(
              onTap: _nextRound,
              child: Container(
                width: 200,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6C5CE7), Color(0xFFA29BFE)],
                  ),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color:
                          const Color(0xFF6C5CE7).withValues(alpha: 0.4),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    _game.isGameOver ? (LanguageService().currentLanguage == 'tr' ? 'Sonuçlar' : 'Results') : (LanguageService().currentLanguage == 'tr' ? 'Sonraki Round' : 'Next Round'),
                    style: GoogleFonts.nunito(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildColorBox(Color color, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.3),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.4),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: GoogleFonts.nunito(
            fontSize: 12,
            color: Colors.white.withValues(alpha: 0.5),
          ),
        ),
      ],
    );
  }

  // ═════════════════════════════════════════════════════════════════
  //  PHASE 6: Game Over — Final skor
  // ═════════════════════════════════════════════════════════════════
  Widget _buildGameOverScreen() {
    final total = _game.totalScore;
    final message = RgbleGame.getFinalMessage(total);

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 600),
              curve: Curves.elasticOut,
              builder: (context, value, child) =>
                  Transform.scale(scale: value, child: child),
              child: Text(
                message,
                style: GoogleFonts.nunito(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: _getScoreColor(total / RgbleGame.totalRounds),
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 24),
            // Toplam puan
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: total),
              duration: const Duration(milliseconds: 1200),
              curve: Curves.easeOutCubic,
              builder: (context, value, _) {
                return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      value.toStringAsFixed(1),
                      style: GoogleFonts.nunito(
                        fontSize: 64,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        ' / ${RgbleGame.maxTotal.toInt()}',
                        style: GoogleFonts.nunito(
                          fontSize: 24,
                          fontWeight: FontWeight.w500,
                          color: Colors.white.withValues(alpha: 0.4),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 28),
            // Round detayları
            ...List.generate(RgbleGame.totalRounds, (i) {
              return _buildRoundSummaryRow(i);
            }),
            const SizedBox(height: 32),
            // Ana Sayfa butonu
            GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                width: 200,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6C5CE7), Color(0xFFA29BFE)],
                  ),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color:
                          const Color(0xFF6C5CE7).withValues(alpha: 0.4),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    widget.onGameComplete != null ? (LanguageService().currentLanguage == 'tr' ? 'Sonraki' : 'Next') : (LanguageService().currentLanguage == 'tr' ? 'Ana Sayfa' : 'Home'),
                    style: GoogleFonts.nunito(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ]        
        ),
      ),
    );
  }

  Widget _buildRoundSummaryRow(int index) {
    final target = _game.targetColors[index];
    final guess = _game.guessedColors[index];
    final score = _game.roundScores[index];

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 400 + index * 100),
      curve: Curves.easeOutBack,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 20 * (1 - value)),
          child: Opacity(opacity: value.clamp(0.0, 1.0), child: child),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.08),
          ),
        ),
        child: Row(
          children: [
            // Round numarası
            Text(
              'R${index + 1}',
              style: GoogleFonts.nunito(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.white.withValues(alpha: 0.4),
              ),
            ),
            const SizedBox(width: 12),
            // Hedef renk
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: target,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.2),
                ),
              ),
            ),
            const SizedBox(width: 6),
            Icon(Icons.arrow_forward_rounded,
                size: 14, color: Colors.white.withValues(alpha: 0.3)),
            const SizedBox(width: 6),
            // Tahmin renk
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: guess,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.2),
                ),
              ),
            ),
            const Spacer(),
            // Emoji
            Text(RgbleGame.getScoreEmoji(score),
                style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 8),
            // Puan
            Text(
              score.toStringAsFixed(1),
              style: GoogleFonts.nunito(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: _getScoreColor(score),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Ortak Widget'lar ─────────────────────────────────────────────
  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).maybePop(),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.arrow_back_ios_new_rounded,
                  color: Colors.white.withValues(alpha: 0.8), size: 18),
            ),
          ),
          const Spacer(),
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [
                Color(0xFFFF6B6B),
                Color(0xFF6BCB77),
                Color(0xFF74B9FF),
              ],
            ).createShader(bounds),
            child: Text(
              'RGBLE',
              style: GoogleFonts.nunito(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: 4,
              ),
            ),
          ),
          const Spacer(),
          const SizedBox(width: 34),
        ],
      ),
    );
  }

  Color _getScoreColor(double score) {
    if (score >= 9.0) return const Color(0xFF6BCB77);
    if (score >= 7.0) return const Color(0xFF00B894);
    if (score >= 5.0) return const Color(0xFFFECE54);
    if (score >= 3.0) return const Color(0xFFFDAA5E);
    return const Color(0xFFFF6B6B);
  }
}

// ─── Custom Painter: Saturation × Brightness ────────────────────────
class _SatBrightPainter extends CustomPainter {
  final Color hueColor;
  _SatBrightPainter(this.hueColor);

  @override
  void paint(Canvas canvas, Size size) {
    // Sol→sağ: beyaz → hue rengi (saturation artışı)
    final satGradient = LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      colors: [Colors.white, hueColor],
    );

    // Üst→alt: şeffaf → siyah (brightness azalması)
    const brightGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Colors.transparent, Colors.black],
    );

    final rect = Rect.fromLTWH(0, 0, size.width, size.height);

    canvas.drawRect(
      rect,
      Paint()..shader = satGradient.createShader(rect),
    );
    canvas.drawRect(
      rect,
      Paint()..shader = brightGradient.createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_SatBrightPainter oldDelegate) {
    return oldDelegate.hueColor != hueColor;
  }
}
