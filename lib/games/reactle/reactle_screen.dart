import 'dart:async';
import '../../services/app_strings.dart';
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
import '../../services/language_service.dart';

class ReactleScreen extends StatefulWidget {
  final bool isDailyMode;
  final void Function(double score, [int durationMs])? onGameComplete;
  const ReactleScreen({super.key, this.isDailyMode = true, this.onGameComplete});

  @override
  State<ReactleScreen> createState() => _ReactleScreenState();
}

enum _GamePhase {
  idle,       // Başla butonu
  lighting,   // Işıklar yanıyor (1-2-3-4-5)
  waiting,    // Tüm ışıklar yandı, rastgele bekleme
  go,         // Işıklar söndü — TIKLA!
  tooEarly,   // Erken bastı
  result,     // Sonuç gösterimi
}

class _ReactleScreenState extends State<ReactleScreen>
    with TickerProviderStateMixin {
  // ─── Oyun durumu ─────────────────────────────────────────────────
  _GamePhase _phase = _GamePhase.idle;
  int _round = 0;
  static const int _totalRounds = 5;

  // Işık durumu (5 ışık)
  List<bool> _lights = [false, false, false, false, false];
  int _litCount = 0;

  // Zamanlama
  Timer? _lightTimer;
  Timer? _goTimer;
  DateTime? _lightsOutTime; // Işıklar sönme zamanı
  int _reactionMs = 0;

  // Round sonuçları
  final List<int> _reactionTimes = [];

  // Ses
  final SoundService _sound = SoundService();
  final AudioPlayer _beepPlayer = AudioPlayer();

  DateTime? _gameStartTime;

  // Daily modda seed tabanlı gecikmeler
  late final List<int> _roundDelays;

  // Animasyonlar
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late AnimationController _resultController;
  late Animation<double> _resultAnimation;

  @override
  void initState() {
    super.initState();
    _gameStartTime = DateTime.now();

    // Daily modda seed tabanlı gecikmeler, biletli modda rastgele
    if (widget.isDailyMode) {
      _roundDelays = DailyChallengeService.getSeededReactleDelays();
    } else {
      _roundDelays = List.generate(5, (_) => 1000 + Random().nextInt(3001));
    }

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _pulseAnimation = CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    );

    _resultController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _resultAnimation = CurvedAnimation(
      parent: _resultController,
      curve: Curves.elasticOut,
    );
  }

  @override
  void dispose() {
    _lightTimer?.cancel();
    _goTimer?.cancel();
    _pulseController.dispose();
    _resultController.dispose();
    _beepPlayer.stop();
    _beepPlayer.dispose();
    super.dispose();
  }

  // ─── Oyun akışı ─────────────────────────────────────────────────
  void _startRound() {
    _round++;
    _lights = [false, false, false, false, false];
    _litCount = 0;
    _reactionMs = 0;

    setState(() {
      _phase = _GamePhase.lighting;
    });

    // Işıkları sırayla yak (her biri ~1 saniye aralıkla)
    _lightNextBulb();
  }

  void _lightNextBulb() {
    if (_litCount >= 5) {
      // Tüm ışıklar yandı → rastgele bekleme
      setState(() {
        _phase = _GamePhase.waiting;
      });

      // Seed tabanlı gecikme süresi (tüm kullanıcılarda aynı)
      final delay = _roundDelays[(_round - 1).clamp(0, _roundDelays.length - 1)];
      _goTimer = Timer(Duration(milliseconds: delay), _lightsOut);
      return;
    }

    // Bir sonraki ışığı yak
    _lightTimer = Timer(const Duration(milliseconds: 1000), () {
      if (!mounted) return;
      setState(() {
        _lights[_litCount] = true;
        _litCount++;
      });
      _playBeep();
      _lightNextBulb();
    });
  }

  Future<void> _playBeep() async {
    try {
      await _beepPlayer.stop();
      await _beepPlayer.play(AssetSource('sounds/click.wav'), volume: 0.8);
    } catch (_) {}
  }

  void _lightsOut() {
    if (!mounted) return;
    setState(() {
      _lights = [false, false, false, false, false];
      _phase = _GamePhase.go;
      _lightsOutTime = DateTime.now();
    });
    _pulseController.repeat(reverse: true);
  }

  // ─── Ekrana tıklama ─────────────────────────────────────────────
  void _onScreenTap() {
    switch (_phase) {
      case _GamePhase.lighting:
      case _GamePhase.waiting:
        // Erken bastı!
        _lightTimer?.cancel();
        _goTimer?.cancel();
        _sound.playError();
        setState(() {
          _phase = _GamePhase.tooEarly;
        });

        Future.delayed(const Duration(milliseconds: 1500), () {
          if (mounted) {
            _round--; // Round tekrar oynanması için geri alıyoruz
            _startRound(); 
          }
        });
        break;

      case _GamePhase.go:
        // Doğru an!
        _reactionMs =
            DateTime.now().difference(_lightsOutTime!).inMilliseconds;
        _reactionTimes.add(_reactionMs);
        _pulseController.stop();
        _resultController.forward(from: 0);
        _sound.playKeyTap();

        setState(() {
          _phase = _GamePhase.result;
        });

        Future.delayed(const Duration(milliseconds: 2000), () {
          if (!mounted) return;
          if (_round >= _totalRounds) {
            _finishGame();
          } else {
            _startRound();
          }
        });
        break;

      default:
        break;
    }
  }

  // ─── Oyun sonu ─────────────────────────────────────────────────
  void _finishGame() {
    _saveScore();
    _showGameOverDialog();
  }

  double _getAverageReaction() {
    if (_reactionTimes.isEmpty) return 0;
    return _reactionTimes.reduce((a, b) => a + b) / _reactionTimes.length;
  }

  int _getBestReaction() {
    if (_reactionTimes.isEmpty) return 0;
    return _reactionTimes.reduce(min);
  }

  /// Skor: Düşük reaksiyon süresi = yüksek puan
  /// 150ms → 100 puan, 300ms → 70 puan, 500ms → 40 puan, 1000ms → 0 puan
  double _calculateScore() {
    final avg = _getAverageReaction();
    if (avg <= 0) return 0;
    // 150ms ve altı = 100 puan, 1000ms ve üstü = 0 puan
    final score = ((1000 - avg) / 850 * 100).clamp(0.0, 100.0);
    return score;
  }

  String _getReactionRating(double avgMs) {
    if (avgMs < 200) return LanguageService().currentLanguage == 'tr' ? 'İnanılmaz! ⚡' : 'Incredible! ⚡';
    if (avgMs < 250) return LanguageService().currentLanguage == 'tr' ? 'Harika! 🏎️' : 'Awesome! 🏎️';
    if (avgMs < 300) return LanguageService().currentLanguage == 'tr' ? 'Çok İyi! 🔥' : 'Great! 🔥';
    if (avgMs < 400) return LanguageService().currentLanguage == 'tr' ? 'İyi 👍' : 'Good 👍';
    if (avgMs < 500) return LanguageService().currentLanguage == 'tr' ? 'Ortalama 😐' : 'Average 😐';
    return LanguageService().currentLanguage == 'tr' ? 'Yavaş 🐌' : 'Slow 🐌';
  }

  Color _getReactionColor(double avgMs) {
    if (avgMs < 200) return Colors.purpleAccent;
    if (avgMs < 250) return Colors.greenAccent;
    if (avgMs < 300) return Colors.cyanAccent;
    if (avgMs < 400) return Colors.orangeAccent;
    return Colors.redAccent;
  }

  // ─── Skor kaydetme ────────────────────────────────────────────
  void _saveScore() {
    final durationMs =
        DateTime.now().difference(_gameStartTime!).inMilliseconds;
    final score = _calculateScore();

    if (widget.onGameComplete != null) {
      final lbScore = LeaderboardService.calculateLeaderboardScore(
        gameId: 'reactle',
        isWin: true,
        score: score,
        durationMs: durationMs,
      );
      widget.onGameComplete!(lbScore, durationMs);
    } else if (widget.isDailyMode) {
      TicketService().markDailyPlayed('reactle');
      StatsService().saveDailyStat(
        gameId: 'reactle',
        isWin: true,
        score: score,
        attempts: _totalRounds,
        maxAttempts: _totalRounds,
        durationMs: durationMs,
      );
      LeaderboardService().submitScore(
        gameId: 'reactle',
        score: LeaderboardService.calculateLeaderboardScore(
          gameId: 'reactle',
          isWin: true,
          score: score,
          durationMs: durationMs,
        ),
        attempts: _totalRounds,
        maxAttempts: _totalRounds,
        durationMs: durationMs,
        isWin: true,
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
    final avg = _getAverageReaction();
    final best = _getBestReaction();
    final score = _calculateScore();
    final rating = _getReactionRating(avg);
    final ratingColor = _getReactionColor(avg);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF1A1A2E),
            score >= 60
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
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          Text(rating,
              style: GoogleFonts.outfit(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: ratingColor,
              )),
          const SizedBox(height: 16),
          // Ortalama süre
          Text(
            '${avg.toStringAsFixed(0)} ms',
            style: GoogleFonts.jetBrainsMono(
              fontSize: 48,
              fontWeight: FontWeight.bold,
              color: ratingColor,
              shadows: [
                Shadow(
                  color: ratingColor.withValues(alpha: 0.5),
                  blurRadius: 16,
                ),
              ],
            ),
          ),
          Text(
            LanguageService().currentLanguage == 'tr' ? 'Ortalama Reaksiyon' : 'Average Reaction',
            style: GoogleFonts.outfit(
              fontSize: 14,
              color: Colors.white54,
            ),
          ),
          const SizedBox(height: 20),
          // Detaylar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _resultStat(LanguageService().isTurkish ? 'En İyi' : 'Best', '${best}ms', Colors.greenAccent),
              _resultStat(LanguageService().currentLanguage == 'tr' ? 'Puan' : 'Score', score.toStringAsFixed(0), Colors.amberAccent),
              _resultStat('Round', '$_totalRounds', Colors.cyanAccent),
            ],
          ),
          const SizedBox(height: 16),
          // Round detayları
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Column(
              children: List.generate(_reactionTimes.length, (i) {
                final ms = _reactionTimes[i];
                final color = _getReactionColor(ms.toDouble());
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Text(
                        'Round ${i + 1}',
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          color: Colors.white54,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${ms}ms',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: ratingColor.withValues(alpha: 0.2),
                foregroundColor: ratingColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: ratingColor.withValues(alpha: 0.5),
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

  Widget _resultStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.outfit(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 12,
            color: Colors.white38,
          ),
        ),
      ],
    );
  }

  // ─── Build ────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return GameExitWrapper(
      gameId: 'reactle', isDailyMode: widget.isDailyMode, onGameComplete: widget.onGameComplete,
      child: Scaffold(
        body: GestureDetector(
          onTap: (_phase == _GamePhase.lighting ||
                  _phase == _GamePhase.waiting ||
                  _phase == _GamePhase.go)
              ? _onScreenTap
              : null,
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF0A0A0A),
                  Color(0xFF1A1A1A),
                  Color(0xFF0D0D0D),
                ],
              ),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  _buildTopBar(),
                  _buildRoundIndicator(),
                  Expanded(child: _buildLightsPanel()),
                  _buildBottomContent(),
                ],
              ),
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
                'Reactle',
                style: GoogleFonts.outfit(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              Text(
                LanguageService().isTurkish ? 'F1 Reaksiyon Testi' : 'F1 Reaction Test',
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  color: Colors.white38,
                ),
              ),
            ],
          ),
          const Spacer(),
          if (_reactionTimes.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.redAccent.withValues(alpha: 0.15),
                    Colors.orangeAccent.withValues(alpha: 0.1),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
              ),
              child: Text(
                '⚡ ${_getAverageReaction().toStringAsFixed(0)}ms',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.redAccent,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRoundIndicator() {
    if (_phase == _GamePhase.idle) return const SizedBox(height: 40);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(_totalRounds, (i) {
          final isDone = i < _reactionTimes.length;
          final isCurrent = i == _round - 1 && _phase != _GamePhase.result;
          return Container(
            width: 40,
            height: 6,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            decoration: BoxDecoration(
              color: isDone
                  ? Colors.greenAccent
                  : isCurrent
                      ? Colors.redAccent
                      : Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(3),
              boxShadow: isDone
                  ? [
                      BoxShadow(
                        color: Colors.greenAccent.withValues(alpha: 0.3),
                        blurRadius: 4,
                      ),
                    ]
                  : null,
            ),
          );
        }),
      ),
    );
  }

  Widget _buildLightsPanel() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // F1 Işıkları — yatay panel
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
            margin: const EdgeInsets.symmetric(horizontal: 32),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.08),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.5),
                  blurRadius: 24,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(5, (i) => _buildLight(i)),
            ),
          ),
          const SizedBox(height: 32),
          // Durum metni
          _buildStatusText(),
        ],
      ),
    );
  }

  Widget _buildLight(int index) {
    final isOn = _lights[index];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Üst çerçeve
        Container(
          width: 48,
          height: 8,
          decoration: BoxDecoration(
            color: Colors.grey.shade800,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(6)),
          ),
        ),
        // Ana ışık kutusu
        Container(
          width: 48,
          height: 100,
          decoration: BoxDecoration(
            color: const Color(0xFF222222),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: Colors.grey.shade700,
              width: 1.5,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildBulb(isOn, 24),
              _buildBulb(isOn, 24),
              _buildBulb(isOn, 24),
            ],
          ),
        ),
        // Alt çerçeve
        Container(
          width: 48,
          height: 8,
          decoration: BoxDecoration(
            color: Colors.grey.shade800,
            borderRadius:
                const BorderRadius.vertical(bottom: Radius.circular(6)),
          ),
        ),
      ],
    );
  }

  Widget _buildBulb(bool isOn, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isOn ? const Color(0xFFFF1A1A) : const Color(0xFF3A1515),
        boxShadow: isOn
            ? [
                BoxShadow(
                  color: Colors.red.withValues(alpha: 0.8),
                  blurRadius: 16,
                  spreadRadius: 4,
                ),
                BoxShadow(
                  color: Colors.redAccent.withValues(alpha: 0.4),
                  blurRadius: 32,
                  spreadRadius: 8,
                ),
              ]
            : [
                BoxShadow(
                  color: Colors.red.withValues(alpha: 0.05),
                  blurRadius: 4,
                ),
              ],
        border: Border.all(
          color: isOn
              ? Colors.red.shade300
              : Colors.grey.shade700,
          width: 1.5,
        ),
      ),
    );
  }

  Widget _buildStatusText() {
    switch (_phase) {
      case _GamePhase.lighting:
      case _GamePhase.waiting:
        return Text(
          LanguageService().isTurkish ? 'Bekle...' : 'Wait...',
          style: GoogleFonts.outfit(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.redAccent,
          ),
        );

      case _GamePhase.go:
        return AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (context, child) {
            return Opacity(
              opacity: 0.6 + _pulseAnimation.value * 0.4,
              child: child,
            );
          },
          child: Text(
            LanguageService().isTurkish ? 'ŞİMDİ!' : 'NOW!',
            style: GoogleFonts.outfit(
              fontSize: 36,
              fontWeight: FontWeight.w900,
              color: Colors.greenAccent,
              shadows: [
                Shadow(
                  color: Colors.greenAccent.withValues(alpha: 0.5),
                  blurRadius: 16,
                ),
              ],
            ),
          ),
        );

      case _GamePhase.tooEarly:
        return Column(
          children: [
            Text(
              LanguageService().currentLanguage == 'tr' ? 'Erken Bastın! ❌' : 'Too Early! ❌',
              style: GoogleFonts.outfit(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.orangeAccent,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              LanguageService().isTurkish ? 'Tekrar deneniyor...' : 'Retrying...',
              style: GoogleFonts.outfit(
                fontSize: 14,
                color: Colors.white38,
              ),
            ),
          ],
        );

      case _GamePhase.result:
        return AnimatedBuilder(
          animation: _resultAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: 0.5 + _resultAnimation.value * 0.5,
              child: child,
            );
          },
          child: Column(
            children: [
              Text(
                '${_reactionMs}ms',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  color: _getReactionColor(_reactionMs.toDouble()),
                  shadows: [
                    Shadow(
                      color: _getReactionColor(_reactionMs.toDouble())
                          .withValues(alpha: 0.5),
                      blurRadius: 16,
                    ),
                  ],
                ),
              ),
              Text(
                _getReactionRating(_reactionMs.toDouble()),
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
        );

      default:
        return const SizedBox();
    }
  }

  Widget _buildBottomContent() {
    if (_phase == _GamePhase.idle) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 48),
        child: Column(
          children: [
            Text(
              LanguageService().currentLanguage == 'tr' ? '🏎️ F1 Işıkları Sönünce Tıkla!' : '🏎️ Click when F1 lights go out!',
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              LanguageService().isTurkish ? '$_totalRounds round • En hızlı ol' : '$_totalRounds rounds • Be the fastest',
              style: GoogleFonts.outfit(
                fontSize: 14,
                color: Colors.white38,
              ),
            ),
            const SizedBox(height: 28),
            GestureDetector(
              onTap: _startRound,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 56, vertical: 18),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.redAccent.withValues(alpha: 0.25),
                      Colors.orangeAccent.withValues(alpha: 0.15),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: Colors.redAccent.withValues(alpha: 0.5)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.redAccent.withValues(alpha: 0.15),
                      blurRadius: 16,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Text(
                  '🏁 ${AppStrings.start}',
                  style: GoogleFonts.outfit(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.redAccent,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (_phase == _GamePhase.go ||
        _phase == _GamePhase.lighting ||
        _phase == _GamePhase.waiting) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 48),
        child: Text(
          _phase == _GamePhase.go
              ? (LanguageService().isTurkish ? 'Ekrana dokun!' : 'Tap the screen!')
              : (LanguageService().currentLanguage == 'tr' ? 'Işıklar sönene kadar DOKUNMA' : 'DO NOT TOUCH until lights go out'),
          style: GoogleFonts.outfit(
            fontSize: 15,
            color: _phase == _GamePhase.go
                ? Colors.greenAccent.withValues(alpha: 0.7)
                : Colors.redAccent.withValues(alpha: 0.5),
          ),
        ),
      );
    }

    return const SizedBox(height: 48);
  }
}
