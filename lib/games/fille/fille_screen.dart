import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../widgets/game_exit_wrapper.dart';
import '../../services/sound_service.dart';
import '../../services/ticket_service.dart';
import '../../services/stats_service.dart';
import '../../services/leaderboard_service.dart';
import '../../services/daily_challenge_service.dart';
import 'glass_painter.dart';

class FilleScreen extends StatefulWidget {
  final bool isDailyMode;
  final void Function(double score, [int durationMs])? onGameComplete;
  const FilleScreen({super.key, this.isDailyMode = true, this.onGameComplete});

  @override
  State<FilleScreen> createState() => _FilleScreenState();
}

class _FilleScreenState extends State<FilleScreen> with TickerProviderStateMixin {
  // ─── Oyun durumu ─────────────────────────────────────────────────
  double _waterLevel = 0.0;        // 0.0 - 1.0+ (taşma)
  bool _isFilling = false;         // Ekrana basılı mı
  bool _hasReleased = false;       // Bir kez bıraktı mı (tek hak)
  bool _isOverflow = false;        // Taşma oldu mu
  bool _isGameOver = false;
  double _score = 0.0;
  
  // Bardak boyu rastgele (0.35 - 0.72 arası)
  late double _glassHeightRatio;
  
  // Dolma hızı: başta yavaş, sonra hızlanır
  double _fillSpeed = 0.003;
  static const double _baseFillSpeed = 0.003;
  static const double _maxFillSpeed = 0.018;
  final double _fillAcceleration = 0.000008;
  
  DateTime? _gameStartTime;

  // ─── Animasyonlar ────────────────────────────────────────────────
  late AnimationController _waveController;
  late AnimationController _resultController;
  late AnimationController _pulseController;
  late Animation<double> _resultAnimation;
  late Animation<double> _pulseAnimation;
  
  // Kabarcıklar
  final List<BubbleParticle> _bubbles = [];
  final List<SplashDrop> _splashDrops = [];
  final Random _random = Random();
  
  // Ses
  final SoundService _sound = SoundService();
  final AudioPlayer _waterFillPlayer = AudioPlayer();
  bool _isWaterSoundPlaying = false;

  @override
  void initState() {
    super.initState();
    _gameStartTime = DateTime.now();
    
    // Bardak boyu: Daily modda seed tabanlı deterministik, biletli modda rastgele
    if (widget.isDailyMode) {
      _glassHeightRatio = DailyChallengeService.getSeededFilleGlassHeight();
    } else {
      _glassHeightRatio = 0.35 + _random.nextDouble() * 0.37; // 0.35 - 0.72
    }
    
    // Dalga animasyonu (sürekli)
    _waveController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat();
    _waveController.addListener(_onTick);
    
    // Sonuç animasyonu
    _resultController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _resultAnimation = CurvedAnimation(
      parent: _resultController,
      curve: Curves.elasticOut,
    );
    
    // Pulse animasyonu (basılı tut yazısı için)
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat(reverse: true);
    _pulseAnimation = CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _waveController.removeListener(_onTick);
    _waveController.dispose();
    _resultController.dispose();
    _pulseController.dispose();
    _waterFillPlayer.stop();
    _waterFillPlayer.dispose();
    super.dispose();
  }

  // ─── Ana oyun döngüsü ──────────────────────────────────────────
  void _onTick() {
    if (!_isFilling || _isGameOver) return;
    
    setState(() {
      // Dolma hızını artır (ivme)
      _fillSpeed = (_fillSpeed + _fillAcceleration).clamp(_baseFillSpeed, _maxFillSpeed);
      _waterLevel += _fillSpeed;
      
      // Kabarcık oluştur
      if (_random.nextDouble() < 0.3) {
        _spawnBubble();
      }
      
      // Kabarcıkları güncelle
      _updateBubbles();
      
      // Taşma kontrolü
      if (_waterLevel >= 1.0) {
        _onOverflow();
      }
    });
  }

  void _spawnBubble() {
    _bubbles.add(BubbleParticle(
      x: 0.1 + _random.nextDouble() * 0.8,
      y: 0.02 + _random.nextDouble() * 0.2,
      radius: 1.5 + _random.nextDouble() * 3.5,
      speed: 0.003 + _random.nextDouble() * 0.005,
      opacity: 0.3 + _random.nextDouble() * 0.5,
      wobblePhase: _random.nextDouble() * pi * 2,
    ));
  }

  void _updateBubbles() {
    for (int i = _bubbles.length - 1; i >= 0; i--) {
      final bubble = _bubbles[i];
      bubble.y += bubble.speed;
      bubble.x += sin(bubble.wobblePhase + bubble.y * 10) * 0.003;
      bubble.wobblePhase += 0.1;
      
      // Suyun üstüne çıkanları kaldır
      if (bubble.y > _waterLevel) {
        _bubbles.removeAt(i);
      }
    }
    // Çok fazla kabarcık birikmesin
    while (_bubbles.length > 25) {
      _bubbles.removeAt(0);
    }
  }

  void _updateSplashDrops() {
    for (int i = _splashDrops.length - 1; i >= 0; i--) {
      final drop = _splashDrops[i];
      drop.x += drop.vx;
      drop.y += drop.vy;
      drop.vy += drop.gravity;
      drop.opacity -= 0.015;
      if (drop.opacity <= 0 || drop.y > 1) {
        _splashDrops.removeAt(i);
      }
    }
  }

  // ─── Taşma ─────────────────────────────────────────────────────
  void _onOverflow() {
    _isFilling = false;
    _isOverflow = true;
    _isGameOver = true;
    _score = 0;
    
    _stopWaterSound();
    _sound.playError();
    
    // Splash efekti
    for (int i = 0; i < 15; i++) {
      _splashDrops.add(SplashDrop(
        x: 0.35 + _random.nextDouble() * 0.3,
        y: 0.15 + (1.0 - _glassHeightRatio) * 0.67,
        vx: (_random.nextDouble() - 0.5) * 0.015,
        vy: -0.005 - _random.nextDouble() * 0.01,
        radius: 2 + _random.nextDouble() * 4,
        opacity: 0.8,
      ));
    }
    
    // Splash animasyonu sonra sonuç göster
    _animateSplashThenResult();
  }

  Future<void> _animateSplashThenResult() async {
    // Splash animasyonunu birkaç frame sürdür
    for (int f = 0; f < 40; f++) {
      await Future.delayed(const Duration(milliseconds: 30));
      if (!mounted) return;
      setState(() {
        _updateSplashDrops();
      });
    }
    
    await Future.delayed(const Duration(milliseconds: 500));
    if (mounted) {
      _saveScore();
      _showGameOverDialog();
    }
  }

  // ─── Başarılı bırakma ──────────────────────────────────────────
  void _onRelease() {
    if (!_isFilling || _isGameOver) return;
    
    _isFilling = false;
    _hasReleased = true;
    _isGameOver = true;
    
    _stopWaterSound();
    
    // Skor hesapla: doluluk yüzdesi (0-100)
    _score = (_waterLevel * 100).clamp(0, 100);
    
    if (_score >= 50) {
      _sound.playWin();
    } else {
      _sound.playLose();
    }
    
    _resultController.forward();
    
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) {
        _saveScore();
        _showGameOverDialog();
      }
    });
  }

  // ─── Basılı tutma başlangıcı ──────────────────────────────────
  void _onPressStart() {
    if (_hasReleased || _isGameOver) return;
    if (widget.isDailyMode && TicketService().isDailyPlayed('fille')) return;
    
    setState(() {
      _isFilling = true;
      _fillSpeed = _baseFillSpeed;
    });
    
    _sound.playKeyTap();
    _startWaterSound();
  }

  // ─── Su sesi yönetimi ──────────────────────────────────────────
  Future<void> _startWaterSound() async {
    if (_isWaterSoundPlaying) return;
    try {
      _isWaterSoundPlaying = true;
      _waterFillPlayer.setReleaseMode(ReleaseMode.loop);
      await _waterFillPlayer.play(AssetSource('sounds/water_fill.wav'), volume: 0.5);
    } catch (_) {}
  }

  Future<void> _stopWaterSound() async {
    _isWaterSoundPlaying = false;
    try {
      await _waterFillPlayer.stop();
    } catch (_) {}
  }

  // ─── Skor kaydetme ────────────────────────────────────────────
  void _saveScore() {
    final durationMs = DateTime.now().difference(_gameStartTime!).inMilliseconds;

    if (widget.onGameComplete != null) {
      final lbScore = LeaderboardService.calculateLeaderboardScore(
        gameId: 'fille',
        isWin: !_isOverflow,
        score: _score,
        durationMs: durationMs,
      );
      widget.onGameComplete!(lbScore, durationMs);
    } else if (widget.isDailyMode) {
      TicketService().markDailyPlayed('fille');
      StatsService().saveDailyStat(
        gameId: 'fille',
        isWin: !_isOverflow,
        score: _score,
        attempts: 1,
        maxAttempts: 1,
        durationMs: durationMs,
      );
      LeaderboardService().submitScore(
        gameId: 'fille',
        score: LeaderboardService.calculateLeaderboardScore(
          gameId: 'fille',
          isWin: !_isOverflow,
          score: _score,
          durationMs: durationMs,
        ),
        attempts: 1,
        maxAttempts: 1,
        durationMs: durationMs,
        isWin: !_isOverflow,
      );
    } else {
      // Bilet bottom sheet'te zaten düşürüldü, burada tekrar düşürme
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
    final isSuccess = !_isOverflow;
    final emoji = _isOverflow
        ? '💧'
        : _score >= 90
            ? '🏆'
            : _score >= 70
                ? '⭐'
                : _score >= 50
                    ? '👍'
                    : '😅';
    final title = _isOverflow ? 'Taştı!' : 'Tebrikler!';
    final scoreText = _isOverflow
        ? '0 Puan'
        : '%${_score.toStringAsFixed(1)} Dolu';
    final titleColor = isSuccess ? Colors.greenAccent : Colors.redAccent;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF1A1A2E),
            isSuccess ? const Color(0xFF0A2E1A) : const Color(0xFF2E0A0A),
          ],
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40, height: 4,
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
            scoreText,
            style: GoogleFonts.outfit(
              fontSize: 22,
              color: Colors.white70,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (!_isOverflow) ...[
            const SizedBox(height: 16),
            // İlerleme barı
            Container(
              width: double.infinity,
              height: 12,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: (_score / 100).clamp(0, 1),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: _score >= 80
                          ? [Colors.greenAccent, Colors.tealAccent]
                          : _score >= 50
                              ? [Colors.orangeAccent, Colors.amberAccent]
                              : [Colors.redAccent, Colors.orangeAccent],
                    ),
                    borderRadius: BorderRadius.circular(6),
                    boxShadow: [
                      BoxShadow(
                        color: (_score >= 80 ? Colors.greenAccent : Colors.orangeAccent)
                            .withValues(alpha: 0.4),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Text(
            'Bardak Boyutu: ${(_glassHeightRatio * 100).toStringAsFixed(0)}%',
            style: GoogleFonts.outfit(
              fontSize: 14,
              color: Colors.white38,
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
                backgroundColor: isSuccess
                    ? Colors.greenAccent.withValues(alpha: 0.2)
                    : Colors.redAccent.withValues(alpha: 0.2),
                foregroundColor: isSuccess ? Colors.greenAccent : Colors.redAccent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: (isSuccess ? Colors.greenAccent : Colors.redAccent)
                        .withValues(alpha: 0.5),
                  ),
                ),
                elevation: 0,
              ),
              child: Text(
                widget.onGameComplete != null ? 'Sonraki' : 'Kapat',
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
      gameId: 'fille', isDailyMode: widget.isDailyMode, onGameComplete: widget.onGameComplete,
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF0A0A2E),
                Color(0xFF1A1A3E),
                Color(0xFF0D2137),
              ],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                _buildTopBar(),
                _buildScoreIndicator(),
                Expanded(child: _buildGameArea()),
                _buildBottomInstructions(),
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
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
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
                'Fille',
                style: GoogleFonts.outfit(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              Text(
                'Bardağı doldur, taşırma!',
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  color: Colors.white38,
                ),
              ),
            ],
          ),
          const Spacer(),
          // Bardak boyutu göstergesi
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.cyanAccent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.cyanAccent.withValues(alpha: 0.2)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.straighten_rounded, color: Colors.cyanAccent, size: 16),
                const SizedBox(width: 4),
                Text(
                  '${(_glassHeightRatio * 100).toStringAsFixed(0)}%',
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.cyanAccent,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScoreIndicator() {
    if (!_isGameOver && _waterLevel <= 0) return const SizedBox(height: 48);
    
    final percentage = (_waterLevel * 100).clamp(0, 100);
    final color = _isOverflow
        ? Colors.redAccent
        : percentage >= 90
            ? Colors.greenAccent
            : percentage >= 60
                ? Colors.orangeAccent
                : Colors.cyanAccent;

    return AnimatedBuilder(
      animation: _resultController,
      builder: (context, child) {
        final scale = _isGameOver ? 0.8 + (_resultAnimation.value * 0.4) : 1.0;
        return Transform.scale(
          scale: scale,
          child: SizedBox(
            height: 48,
            child: Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: _isOverflow
                    ? Text(
                        '💧 TAŞTI!',
                        key: const ValueKey('overflow'),
                        style: GoogleFonts.outfit(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.redAccent,
                          shadows: [
                            Shadow(
                              color: Colors.redAccent.withValues(alpha: 0.5),
                              blurRadius: 12,
                            ),
                          ],
                        ),
                      )
                    : Text(
                        '%${percentage.toStringAsFixed(1)}',
                        key: ValueKey(percentage.toStringAsFixed(0)),
                        style: GoogleFonts.outfit(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: color,
                          shadows: [
                            Shadow(
                              color: color.withValues(alpha: 0.5),
                              blurRadius: 12,
                            ),
                          ],
                        ),
                      ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildGameArea() {
    return Listener(
      onPointerDown: (_) => _onPressStart(),
      onPointerUp: (_) => _onRelease(),
      onPointerCancel: (_) => _onRelease(),
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: _waveController,
        builder: (context, child) {
          return CustomPaint(
            painter: GlassPainter(
              glassHeightRatio: _glassHeightRatio,
              waterLevel: _waterLevel,
              wavePhase: _waveController.value * pi * 2,
              bubbles: _bubbles,
              isOverflow: _isOverflow,
              showResult: _isGameOver && !_isOverflow,
              isFilling: _isFilling,
              splashDrops: _splashDrops,
            ),
            size: Size.infinite,
          );
        },
      ),
    );
  }

  Widget _buildBottomInstructions() {
    if (_isGameOver) {
      return const SizedBox(height: 80);
    }
    
    if (_hasReleased) {
      return const SizedBox(height: 80);
    }

    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        final opacity = _isFilling
            ? 0.5
            : 0.5 + _pulseAnimation.value * 0.5;
        return Padding(
          padding: const EdgeInsets.only(bottom: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: _isFilling
                    ? Row(
                        key: const ValueKey('filling'),
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.touch_app_rounded,
                            color: Colors.cyanAccent.withValues(alpha: 0.7),
                            size: 28,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Dolduruluyor... Bırakarak durdur!',
                            style: GoogleFonts.outfit(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.cyanAccent.withValues(alpha: 0.8),
                            ),
                          ),
                        ],
                      )
                    : Opacity(
                        key: const ValueKey('waiting'),
                        opacity: opacity,
                        child: Column(
                          children: [
                            Icon(
                              Icons.touch_app_rounded,
                              color: Colors.white.withValues(alpha: 0.6),
                              size: 36,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Basılı tutarak doldur',
                              style: GoogleFonts.outfit(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Colors.white.withValues(alpha: 0.7),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Tek hakkın var, taşırma!',
                              style: GoogleFonts.outfit(
                                fontSize: 13,
                                color: Colors.white.withValues(alpha: 0.35),
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
