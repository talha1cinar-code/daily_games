import 'dart:async';
import '../../services/app_strings.dart';
import 'dart:math';
import 'package:flutter/material.dart';
import '../../widgets/game_exit_wrapper.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_soloud/flutter_soloud.dart';
import '../../services/sound_service.dart';
import '../../services/daily_challenge_service.dart';
import '../../services/ticket_service.dart';
import '../../services/stats_service.dart';
import '../../services/leaderboard_service.dart';
import 'sound_game.dart';
import '../../services/language_service.dart';

enum _GamePhase {
  idle,
  countdown,
  playTarget,
  guess,
  showScore,
  gameOver,
}

class SoundScreen extends StatefulWidget {
  final bool isDailyMode;
  final void Function(double score, [int durationMs])? onGameComplete;
  const SoundScreen({super.key, this.isDailyMode = true, this.onGameComplete});

  @override
  State<SoundScreen> createState() => _SoundScreenState();
}

class _SoundScreenState extends State<SoundScreen> with TickerProviderStateMixin {
  late SoundGame _game;
  bool _isLoading = true;
  final SoundService _appSound = SoundService();
  
  bool _isInit = false;
  AudioSource? _waveSource;
  SoundHandle? _currentHandle;

  _GamePhase _phase = _GamePhase.idle;
  
  // Tahmin Frekansı
  double _guessFreq = 640.0;
  
  // Animasyonlar
  late AnimationController _waveAnimController;
  late AnimationController _textScaleController;
  String _countdownText = '';

  @override
  void initState() {
    super.initState();
    
    _waveAnimController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    _textScaleController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _initGame();
    _initAudio();
  }

  Future<void> _initGame() async {
    List<double>? freqs;
    if (widget.isDailyMode) {
      freqs = DailyChallengeService.getSeededSoundFrequencies();
    }
    
    setState(() {
      _game = SoundGame(externalFrequencies: freqs);
      _isLoading = false;
    });
  }

  Future<void> _initAudio() async {
    try {
      await SoLoud.instance.init();
      _waveSource = await SoLoud.instance.loadWaveform(
        WaveForm.sin,
        false,
        0.5,
        0.0,
      );
      setState(() => _isInit = true);
    } catch (e) {
      debugPrint("SoLoud Init Error: $e");
    }
  }

  @override
  void dispose() {
    _waveAnimController.dispose();
    _textScaleController.dispose();
    if (_currentHandle != null) {
      SoLoud.instance.stop(_currentHandle!);
    }
    SoLoud.instance.deinit();
    super.dispose();
  }

  void _startGame() {
    setState(() => _phase = _GamePhase.countdown);
    _playCountdownAnimation();
  }

  Future<void> _playCountdownAnimation() async {
    setState(() => _countdownText = LanguageService().isTurkish ? 'Hazır' : 'Ready');
    _textScaleController.forward(from: 0.0);
    _appSound.playFlip();
    await Future.delayed(const Duration(milliseconds: 1000));
    if (!mounted) return;

    setState(() => _countdownText = LanguageService().isTurkish ? 'Başla!' : 'Go!');
    _textScaleController.forward(from: 0.0);
    _appSound.playWin();
    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;

    _startRound();
  }

  void _startRound() {
    setState(() {
      _phase = _GamePhase.playTarget;
      _guessFreq = 640.0; // Ortadan başlat
    });
    _playTargetSound();
  }

  Future<void> _playTargetSound() async {
    if (_waveSource == null) return;

    try {
      if (_currentHandle != null) SoLoud.instance.stop(_currentHandle!);
      _currentHandle = SoLoud.instance.play(_waveSource!);
      SoLoud.instance.setWaveformFreq(_waveSource!, _game.currentTargetFreq);
      
      await Future.delayed(const Duration(milliseconds: 2500));
      
      if (mounted && _phase == _GamePhase.playTarget) {
        if (_currentHandle != null) {
          SoLoud.instance.stop(_currentHandle!);
          _currentHandle = null;
        }
        setState(() => _phase = _GamePhase.guess);
      }
    } catch (e) {
      debugPrint("Error playing target: $e");
      if (mounted) setState(() => _phase = _GamePhase.guess);
    }
  }

  void _onPanStart(DragStartDetails details) {
    if (_phase != _GamePhase.guess || _waveSource == null) return;
    
    _currentHandle ??= SoLoud.instance.play(_waveSource!);
    _updateFreqFromY(details.localPosition.dy);
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_phase != _GamePhase.guess) return;
    _updateFreqFromY(details.localPosition.dy);
  }

  // Kullanıcı parmağını çektiğinde ses artık KESİLMEYECEK.
  void _onPanEnd(DragEndDetails details) {
    // Do nothing: Ses çalmaya devam eder ve o frekansta kalır.
  }

  void _updateFreqFromY(double y) {
    final screenHeight = MediaQuery.of(context).size.height;
    // Y ekseni: Yukarısı 1200 Hz, Aşağısı 80 Hz
    final ratio = 1.0 - (y / screenHeight).clamp(0.0, 1.0);
    final freq = SoundGame.minFreq + ratio * (SoundGame.maxFreq - SoundGame.minFreq);
    
    setState(() {
      _guessFreq = freq;
    });
    
    if (_waveSource != null) {
      SoLoud.instance.setWaveformFreq(_waveSource!, _guessFreq);
    }
  }

  void _onSubmit() {
    if (_phase != _GamePhase.guess) return;
    
    // Gönderirken çalan sesi durdur
    if (_currentHandle != null) {
      SoLoud.instance.stop(_currentHandle!);
      _currentHandle = null;
    }

    final score = _game.submitGuess(_guessFreq);
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
            gameId: 'sound',
            isWin: isWin,
            score: _game.totalScore,
          );
          widget.onGameComplete!(score);
        } else if (widget.isDailyMode) {
          TicketService().markDailyPlayed('sound');
          StatsService().saveDailyStat(
            gameId: 'sound',
            isWin: isWin,
            score: _game.totalScore,
            attempts: _game.roundScores.length,
            maxAttempts: SoundGame.totalRounds,
          );
          LeaderboardService().submitScore(
            gameId: 'sound',
            score: LeaderboardService.calculateLeaderboardScore(
              gameId: 'sound',
              isWin: isWin,
              score: _game.totalScore,
            ),
            attempts: _game.roundScores.length,
            maxAttempts: SoundGame.totalRounds,
            isWin: isWin,
          );
        }
      } else {
        _startRound();
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
              '${_game.currentRound + (_phase == _GamePhase.showScore ? 0 : 1)} / ${SoundGame.totalRounds}',
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
              const Icon(Icons.graphic_eq_rounded, color: Color(0xFF00FF87), size: 100),
              const SizedBox(height: 24),
              Text(
                'Sound',
                style: GoogleFonts.nunito(
                  color: Colors.white,
                  fontSize: 48,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 4,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                LanguageService().currentLanguage == 'tr' ? 'Dinle, kaydır ve frekansı bul!' : 'Listen, slide and find the frequency!',
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
                  backgroundColor: const Color(0xFF00FF87),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  elevation: 8,
                ),
                child: Text(
                  AppStrings.start,
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
                const Text('🎵', style: TextStyle(fontSize: 64)),
                const SizedBox(height: 16),
                Text(
                  LanguageService().currentLanguage == 'tr' ? 'Oyun Bitti!' : 'Game Over!',
                  style: GoogleFonts.nunito(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  SoundGame.getFinalMessage(_game.totalScore),
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
                    color: const Color(0xFF00FF87),
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF60EFFF),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(widget.onGameComplete != null ? (LanguageService().isTurkish ? 'Sonraki' : 'Next') : (LanguageService().isTurkish ? 'Ana Menü' : 'Main Menu'),
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading || !_isInit) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Color(0xFF00FF87))),
      );
    }

    if (_phase == _GamePhase.idle) {
      return GameExitWrapper(gameId: 'sound', isDailyMode: widget.isDailyMode, onGameComplete: widget.onGameComplete, child: Scaffold(backgroundColor: Colors.black, body: _buildIdleScreen()));
    } else if (_phase == _GamePhase.countdown) {
      return GameExitWrapper(gameId: 'sound', isDailyMode: widget.isDailyMode, onGameComplete: widget.onGameComplete, child: Scaffold(backgroundColor: Colors.black, body: _buildCountdownScreen()));
    } else if (_phase == _GamePhase.gameOver) {
      return GameExitWrapper(gameId: 'sound', isDailyMode: widget.isDailyMode, onGameComplete: widget.onGameComplete, child: Scaffold(backgroundColor: Colors.black, body: _buildGameOverScreen()));
    }

    // Gösterilecek frekans (Eğer hedef çalıyorsa hedefi, değilse tahmini gösterir)
    final displayFreq = _phase == _GamePhase.playTarget 
        ? _game.currentTargetFreq 
        : _guessFreq;
    
    // Animasyon hızı frekansa bağlı
    _waveAnimController.duration = Duration(milliseconds: (2000 - (displayFreq / 1200 * 1800)).toInt().clamp(200, 2000));

    final isWaveActive = _phase == _GamePhase.playTarget || 
                        _phase == _GamePhase.guess || 
                        _phase == _GamePhase.showScore;

    return GameExitWrapper(gameId: 'sound', isDailyMode: widget.isDailyMode, onGameComplete: widget.onGameComplete, child: Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onPanStart: _onPanStart,
        onPanUpdate: _onPanUpdate,
        onPanEnd: _onPanEnd,
        behavior: HitTestBehavior.opaque,
        child: Stack(
          children: [
            // Dalgayı Çiz
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _waveAnimController,
                builder: (context, child) {
                  return CustomPaint(
                    painter: WavePainter(
                      progress: _waveAnimController.value,
                      frequency: displayFreq,
                      isActive: isWaveActive,
                    ),
                  );
                },
              ),
            ),

            _buildTopBar(),

            // Ortada: Durum Metinleri
            if (_phase == _GamePhase.playTarget)
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.volume_up, color: Colors.white, size: 64),
                    const SizedBox(height: 16),
                    Text(
                      LanguageService().currentLanguage == 'tr' ? 'Hedef Sesi Dinle...' : 'Listen to Target Sound...',
                      style: GoogleFonts.nunito(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              
            if (_phase == _GamePhase.guess && _currentHandle == null)
              Center(
                child: Text(
                  LanguageService().currentLanguage == 'tr' ? 'Sesi bulmak için ekranda\nyukarı/aşağı kaydır ve\nbasılı tutarak dinle' : 'Slide up/down on the screen\nand hold to listen\nto find the sound',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.nunito(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),

            if (_phase == _GamePhase.showScore)
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        SoundGame.getScoreEmoji(_game.roundScores.last),
                        style: const TextStyle(fontSize: 64),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '+${_game.roundScores.last.toStringAsFixed(1)}',
                        style: GoogleFonts.nunito(
                          color: const Color(0xFF00FF87),
                          fontSize: 48,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Hedef ve Tahmin Karşılaştırması
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Column(
                            children: [
                              Text(LanguageService().currentLanguage == 'tr' ? 'Hedef' : 'Target', style: GoogleFonts.nunito(color: Colors.white70, fontSize: 16)),
                              Text('${_game.targetFrequencies[_game.currentRound - 1].toStringAsFixed(1)} Hz', 
                                style: GoogleFonts.nunito(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const SizedBox(width: 24),
                          Container(width: 2, height: 40, color: Colors.white24),
                          const SizedBox(width: 24),
                          Column(
                            children: [
                              Text(LanguageService().currentLanguage == 'tr' ? 'Tahminin' : 'Your Guess', style: GoogleFonts.nunito(color: Colors.white70, fontSize: 16)),
                              Text('${_game.guessedFrequencies[_game.currentRound - 1].toStringAsFixed(1)} Hz', 
                                style: GoogleFonts.nunito(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ],
                      )
                    ],
                  ),
                ),
              ),

            // Alt Kısım: Frekans ve Buton (Sadece guess durumunda görünür)
            if (_phase == _GamePhase.guess) ...[
              Positioned(
                bottom: 40,
                left: 20,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      _guessFreq.toStringAsFixed(1),
                      style: GoogleFonts.nunito(
                        color: Colors.white,
                        fontSize: 64,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -2,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Hz',
                      style: GoogleFonts.nunito(
                        color: Colors.white70,
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                bottom: 40,
                right: 20,
                child: GestureDetector(
                  onTap: _onSubmit,
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.arrow_forward_rounded,
                      color: Colors.black,
                      size: 32,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    ));
  }
}

/// Sesi görselleştiren şık neon dalga
class WavePainter extends CustomPainter {
  final double progress;
  final double frequency;
  final bool isActive;

  WavePainter({
    required this.progress,
    required this.frequency,
    required this.isActive,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (!isActive) return;

    final centerX = size.width / 2;

    // Frekansa göre dalga sıklığı ve genliği
    // 80Hz daha geniş ve yüksek genlikli, 1200Hz daha sık ve düşük genlikli
    final normFreq = (frequency - SoundGame.minFreq) / (SoundGame.maxFreq - SoundGame.minFreq);
    
    final waveCount = 2 + (normFreq * 10); 
    final maxAmplitude = 100.0 - (normFreq * 60.0);

    final paint1 = Paint()
      ..color = const Color(0xFF00FF87).withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final paint2 = Paint()
      ..color = const Color(0xFF60EFFF).withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final paint3 = Paint()
      ..color = const Color(0xFFB100FF).withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    _drawWave(canvas, size, paint1, waveCount, maxAmplitude, progress * 2 * pi, centerX);
    _drawWave(canvas, size, paint2, waveCount * 1.2, maxAmplitude * 0.8, (progress + 0.3) * 2 * pi, centerX);
    _drawWave(canvas, size, paint3, waveCount * 0.8, maxAmplitude * 1.2, (progress + 0.6) * 2 * pi, centerX);
  }

  void _drawWave(Canvas canvas, Size size, Paint paint, double waves, double amplitude, double phase, double centerX) {
    final path = Path();
    
    for (double y = 0; y <= size.height; y++) {
      // Uçlara doğru dalganın sönümlenmesi (Fade out)
      final fade = sin((y / size.height) * pi);
      
      final x = centerX + sin((y / size.height) * waves * 2 * pi + phase) * amplitude * fade;
      
      if (y == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant WavePainter oldDelegate) {
    return oldDelegate.progress != progress ||
           oldDelegate.frequency != frequency ||
           oldDelegate.isActive != isActive;
  }
}