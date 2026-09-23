import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../../widgets/game_exit_wrapper.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/sound_service.dart';
import '../../services/daily_challenge_service.dart';
import '../../services/ticket_service.dart';
import '../../services/stats_service.dart';
import '../../services/leaderboard_service.dart';
import 'timele_game.dart';

enum _GamePhase {
  idle,
  countdown,
  showEffect,
  promptUser,
  userHold,
  showScore,
  gameOver,
}

class TimeleScreen extends StatefulWidget {
  final bool isDailyMode;
  final void Function(double score)? onGameComplete;
  const TimeleScreen({super.key, this.isDailyMode = true, this.onGameComplete});

  @override
  State<TimeleScreen> createState() => _TimeleScreenState();
}

class _TimeleScreenState extends State<TimeleScreen> with TickerProviderStateMixin {
  late TimeleGame _game;
  bool _isLoading = true;
  final SoundService _appSound = SoundService();

  _GamePhase _phase = _GamePhase.idle;

  // Animasyon Kontrolcüleri
  late AnimationController _textScaleController;
  late AnimationController _pulseAnimController;

  String _countdownText = '';

  // Zaman tutma
  final Stopwatch _stopwatch = Stopwatch();
  Timer? _effectTimer;
  Timer? _stopwatchUptimeTimer;
  int _guessedDuration = 0; // ekranda akarken göstermek için
  int _lastGuessMs = 0;

  @override
  void initState() {
    super.initState();

    _textScaleController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _pulseAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();

    _initGame();
  }

  Future<void> _initGame() async {
    List<int>? durations;
    if (widget.isDailyMode) {
      durations = await DailyChallengeService().getTimeleChallenge();
    }
    
    setState(() {
      _game = TimeleGame(externalDurations: durations);
      _isLoading = false;
    });
  }

  @override
  void dispose() {
    _textScaleController.dispose();
    _pulseAnimController.dispose();
    _effectTimer?.cancel();
    _stopwatchUptimeTimer?.cancel();
    _stopwatch.stop();
    super.dispose();
  }

  void _startGame() {
    setState(() => _phase = _GamePhase.countdown);
    _playCountdownAnimation();
  }

  Future<void> _playCountdownAnimation() async {
    setState(() => _countdownText = 'Hazır');
    _textScaleController.forward(from: 0.0);
    _appSound.playFlip();
    await Future.delayed(const Duration(milliseconds: 1000));
    if (!mounted) return;

    setState(() => _countdownText = 'Başla!');
    _textScaleController.forward(from: 0.0);
    _appSound.playWin();
    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;

    _startShowEffect();
  }

  void _startShowEffect() {
    setState(() {
      _phase = _GamePhase.showEffect;
    });

    final targetMs = _game.currentTargetDuration;

    _effectTimer?.cancel();
    _effectTimer = Timer(Duration(milliseconds: targetMs), () {
      if (!mounted) return;
      _startPromptUser();
    });
  }

  void _startPromptUser() {
    setState(() {
      _phase = _GamePhase.promptUser;
    });
  }

  void _onPointerDown(PointerDownEvent event) {
    if (_phase != _GamePhase.promptUser) return;

    setState(() {
      _phase = _GamePhase.userHold;
      _guessedDuration = 0;
    });

    _appSound.playFlip();
    _stopwatch.reset();
    _stopwatch.start();

    // Ekranda kronometrenin anlık akışını göstermek için
    _stopwatchUptimeTimer = Timer.periodic(const Duration(milliseconds: 16), (timer) {
      if (mounted && _phase == _GamePhase.userHold) {
        setState(() {
          _guessedDuration = _stopwatch.elapsedMilliseconds;
        });
      }
    });
  }

  void _onPointerUp(PointerUpEvent event) {
    if (_phase != _GamePhase.userHold) return;

    _stopwatch.stop();
    _stopwatchUptimeTimer?.cancel();
    _lastGuessMs = _stopwatch.elapsedMilliseconds;
    
    _submitGuess();
  }

  void _submitGuess() {
    final score = _game.submitGuess(_lastGuessMs);
    
    setState(() {
      _phase = _GamePhase.showScore;
    });

    if (score >= 8.0) {
      _appSound.playWin();
    } else {
      _appSound.playFlip();
    }

    Future.delayed(const Duration(milliseconds: 3000), () {
      if (!mounted) return;
      if (_game.isGameOver) {
        setState(() => _phase = _GamePhase.gameOver);
        
        final isWin = _game.totalScore >= 30;
        if (isWin) {
          _appSound.playWin();
        } else {
          _appSound.playLose();
        }
        
        if (widget.onGameComplete != null) {
          final score = LeaderboardService.calculateLeaderboardScore(
            gameId: 'timele',
            isWin: isWin,
            score: _game.totalScore,
          );
          widget.onGameComplete!(score);
        } else if (widget.isDailyMode) {
          TicketService().markDailyPlayed('timele');
          StatsService().saveDailyStat(
            gameId: 'timele',
            isWin: isWin,
            score: _game.totalScore,
            attempts: _game.roundScores.length,
            maxAttempts: TimeleGame.totalRounds,
          );
          LeaderboardService().submitScore(
            gameId: 'timele',
            score: LeaderboardService.calculateLeaderboardScore(
              gameId: 'timele',
              isWin: isWin,
              score: _game.totalScore,
            ),
            attempts: _game.roundScores.length,
            maxAttempts: TimeleGame.totalRounds,
            isWin: isWin,
          );
        }
      } else {
        _startShowEffect();
      }
    });
  }

  Widget _buildTopBar() {
    return Positioned(
      top: 50,
      left: 20,
      right: 20,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (_phase != _GamePhase.idle && _phase != _GamePhase.gameOver)
            Text(
              '${_game.currentRound + (_phase == _GamePhase.showScore ? 0 : 1)} / ${TimeleGame.totalRounds}',
              style: GoogleFonts.nunito(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w800,
                letterSpacing: 2,
              ),
            )
          else
            const SizedBox(),
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Icon(Icons.close, color: Colors.white.withValues(alpha: 0.5)),
          ),
        ],
      ),
    );
  }

  Widget _buildIdleScreen() {
    return Stack(
      children: [
        _buildTopBar(),
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.av_timer_rounded, color: Color(0xFFFF0055), size: 100),
              const SizedBox(height: 24),
              Text(
                'Timele',
                style: GoogleFonts.nunito(
                  color: Colors.white,
                  fontSize: 48,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 4,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Ekranda çıkan efekti izle,\naynı süreyi basılı tutarak tekrarla!',
                textAlign: TextAlign.center,
                style: GoogleFonts.nunito(
                  color: Colors.white70,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 48),
              ElevatedButton(
                onPressed: _startGame,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF0055),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  elevation: 8,
                ),
                child: Text(
                  'BAŞLA',
                  style: GoogleFonts.nunito(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCountdownScreen() {
    return Stack(
      children: [
        _buildTopBar(),
        Center(
          child: AnimatedBuilder(
            animation: _textScaleController,
            builder: (context, child) {
              return Transform.scale(
                scale: Curves.elasticOut.transform(_textScaleController.value),
                child: Text(
                  _countdownText,
                  style: GoogleFonts.nunito(
                    color: Colors.white,
                    fontSize: 64,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildGameOverScreen() {
    return Stack(
      children: [
        _buildTopBar(),
        Center(
          child: Container(
            margin: const EdgeInsets.all(24),
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: const Color(0xFF1B1B2F),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('⏳', style: TextStyle(fontSize: 64)),
                const SizedBox(height: 16),
                Text(
                  'Oyun Bitti!',
                  style: GoogleFonts.nunito(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  TimeleGame.getFinalMessage(_game.totalScore),
                  style: GoogleFonts.nunito(
                    fontSize: 20,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  '${_game.totalScore.toStringAsFixed(1)} / 50.0',
                  style: GoogleFonts.nunito(
                    fontSize: 48,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFFFF0055),
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF0055),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(widget.onGameComplete != null ? 'Sonraki' : 'Ana Menü',
                        style: GoogleFonts.nunito(
                            fontSize: 18,
                            fontWeight: FontWeight.w800)),
                  ),
                )
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPulsingOrb() {
    return AnimatedBuilder(
      animation: _pulseAnimController,
      builder: (context, child) {
        return CustomPaint(
          size: const Size(double.infinity, double.infinity),
          painter: OrbPainter(progress: _pulseAnimController.value),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_phase == _GamePhase.idle) return GameExitWrapper(gameId: 'timele', isDailyMode: widget.isDailyMode, child: Scaffold(backgroundColor: Colors.black, body: _buildIdleScreen()));
    if (_phase == _GamePhase.countdown) return GameExitWrapper(gameId: 'timele', isDailyMode: widget.isDailyMode, child: Scaffold(backgroundColor: Colors.black, body: _buildCountdownScreen()));
    if (_phase == _GamePhase.gameOver) return GameExitWrapper(gameId: 'timele', isDailyMode: widget.isDailyMode, child: Scaffold(backgroundColor: Colors.black, body: _buildGameOverScreen()));

    return GameExitWrapper(gameId: 'timele', isDailyMode: widget.isDailyMode, child: Scaffold(
      backgroundColor: Colors.black,
      body: Listener(
        onPointerDown: _onPointerDown,
        onPointerUp: _onPointerUp,
        behavior: HitTestBehavior.opaque,
        child: Stack(
          children: [
            // Sadece hedefin gösterildiği evrede veya kullanıcı basılı tutarken küreyi çiz
            if (_phase == _GamePhase.showEffect || _phase == _GamePhase.userHold)
              _buildPulsingOrb(),

            _buildTopBar(),

            if (_phase == _GamePhase.showEffect)
              Center(
                child: Text(
                  'Efekti İzle...',
                  style: GoogleFonts.nunito(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    shadows: [Shadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 10)],
                  ),
                ),
              ),

            if (_phase == _GamePhase.promptUser)
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.touch_app_rounded, color: Colors.white, size: 64),
                    const SizedBox(height: 24),
                    Text(
                      'Sıra Sende!',
                      style: GoogleFonts.nunito(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Aynı süreyi tutturmak için\nekrana basılı tut',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.nunito(
                        color: Colors.white70,
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),

            if (_phase == _GamePhase.userHold)
              Positioned(
                bottom: 60,
                left: 0,
                right: 0,
                child: Center(
                  child: Text(
                    '${(_guessedDuration / 1000).toStringAsFixed(2)} sn',
                    style: GoogleFonts.nunito(
                      color: Colors.white,
                      fontSize: 48,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),

            if (_phase == _GamePhase.showScore)
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 32),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        TimeleGame.getScoreEmoji(_game.roundScores.last),
                        style: const TextStyle(fontSize: 64),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '+${_game.roundScores.last.toStringAsFixed(1)}',
                        style: GoogleFonts.nunito(
                          color: const Color(0xFFFF0055),
                          fontSize: 56,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 32),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Column(
                            children: [
                              Text('Hedef', style: GoogleFonts.nunito(color: Colors.white70, fontSize: 16)),
                              Text('${(_game.targetDurations[_game.currentRound - 1] / 1000).toStringAsFixed(2)}s', 
                                style: GoogleFonts.nunito(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const SizedBox(width: 32),
                          Container(width: 2, height: 48, color: Colors.white24),
                          const SizedBox(width: 32),
                          Column(
                            children: [
                              Text('Tahminin', style: GoogleFonts.nunito(color: Colors.white70, fontSize: 16)),
                              Text('${(_game.guessedDurations[_game.currentRound - 1] / 1000).toStringAsFixed(2)}s', 
                                style: GoogleFonts.nunito(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ],
                      )
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    ));
  }
}

/// Ekranda titreşen neon enerji küresini (Orb) çizen sınıf
class OrbPainter extends CustomPainter {
  final double progress;

  OrbPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    // İçi dolu ana küre
    final corePaint = Paint()
      ..color = const Color(0xFFFF0055).withValues(alpha: 0.3 + (sin(progress * 2 * pi) * 0.2).abs())
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 50);

    canvas.drawCircle(center, 120, corePaint);

    // Dışarıya doğru yayılan şok dalgaları
    for (int i = 0; i < 3; i++) {
      final ringProgress = (progress + (i * 0.33)) % 1.0;
      final radius = 100 + (ringProgress * 150);
      
      // Büyüdükçe saydamlığı azalır
      final opacity = (1.0 - ringProgress).clamp(0.0, 1.0);

      final ringPaint = Paint()
        ..color = const Color(0xFFFF0055).withValues(alpha: opacity * 0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4.0
        ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 10);

      canvas.drawCircle(center, radius, ringPaint);
    }
    
    // Merkez parlaklığı
    final brightPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.8)
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    
    canvas.drawCircle(center, 30 + (sin(progress * 4 * pi) * 5), brightPaint);
  }

  @override
  bool shouldRepaint(covariant OrbPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}