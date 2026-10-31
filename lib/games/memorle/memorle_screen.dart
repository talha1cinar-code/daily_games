import 'dart:async';
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
import '../../services/app_strings.dart';
import '../../services/language_service.dart';

class MemorleScreen extends StatefulWidget {
  final bool isDailyMode;
  final void Function(double score, [int durationMs])? onGameComplete;
  const MemorleScreen({super.key, this.isDailyMode = true, this.onGameComplete});

  @override
  State<MemorleScreen> createState() => _MemorleScreenState();
}

enum _GamePhase {
  ready,      // Başlamaya hazır
  showing,    // Sayılar gösteriliyor
  input,      // Kullanıcı giriyor
  correct,    // Doğru bildi
  wrong,      // Yanlış bildi - oyun bitti
}

class _MemorleScreenState extends State<MemorleScreen>
    with TickerProviderStateMixin {
  // ─── Oyun durumu ─────────────────────────────────────────────────
  int _level = 1;
  int _score = 0;
  bool _isGameOver = false;
  _GamePhase _phase = _GamePhase.ready;

  // Sayı bilgileri
  String _currentNumber = '';
  String _userInput = '';
  int _showingDigitIndex = -1; // Hangi basamak gösteriliyor

  // Zamanlama
  Timer? _digitTimer;
  Timer? _inputTimer;
  int _inputTimeLeft = 0; // Saniye cinsinden giriş süresi

  late final Random _random;
  final SoundService _sound = SoundService();
  DateTime? _gameStartTime;

  // Animasyonlar
  late AnimationController _digitController;
  late AnimationController _resultController;
  late AnimationController _shakeController;
  late Animation<double> _digitAnimation;
  late Animation<double> _resultAnimation;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _gameStartTime = DateTime.now();

    // Daily modda seed tabanlı Random, biletli modda rastgele
    if (widget.isDailyMode) {
      _random = Random(DailyChallengeService.getSeededMemorleSeed());
    } else {
      _random = Random();
    }

    _digitController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _digitAnimation = CurvedAnimation(
      parent: _digitController,
      curve: Curves.easeOutBack,
    );

    _resultController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _resultAnimation = CurvedAnimation(
      parent: _resultController,
      curve: Curves.elasticOut,
    );

    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _shakeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.elasticOut),
    );
  }

  @override
  void dispose() {
    _digitTimer?.cancel();
    _inputTimer?.cancel();
    _digitController.dispose();
    _resultController.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  // ─── Seviye mantığı ──────────────────────────────────────────────
  // Level 1-3: 3 basamak
  // Level 4-6: 4 basamak
  // Level 7-9: 5 basamak
  // Level 10-12: 6 basamak
  // Level 13+: 7 basamak
  int _getDigitCount() {
    if (_level <= 3) return 3;
    if (_level <= 6) return 4;
    if (_level <= 9) return 5;
    if (_level <= 12) return 6;
    return 7;
  }

  /// Basamak gösterim süresi (ms) - level arttıkça hızlanır
  /// Başlangıçta bile çok kolay olmasın
  int _getDigitShowDuration() {
    // Level 1: 650ms per digit (zaten hızlı)
    // Level 5: 450ms
    // Level 10: 300ms
    // Level 15+: 200ms (minimum)
    final ms = 650 - (_level - 1) * 35;
    return ms.clamp(200, 650);
  }

  /// Giriş süresi (saniye)
  int _getInputTime() {
    final digits = _getDigitCount();
    // Basamak başına ~2.5 saniye, minimum 4 saniye
    return (digits * 2.5).ceil().clamp(4, 20);
  }

  String _generateNumber() {
    final digits = _getDigitCount();
    final buffer = StringBuffer();
    // İlk basamak 0 olmasın
    buffer.write(_random.nextInt(9) + 1);
    for (int i = 1; i < digits; i++) {
      buffer.write(_random.nextInt(10));
    }
    return buffer.toString();
  }

  // ─── Oyun akışı ─────────────────────────────────────────────────
  void _startRound() {
    _currentNumber = _generateNumber();
    _userInput = '';
    _showingDigitIndex = -1;

    setState(() {
      _phase = _GamePhase.showing;
    });

    // Sayıları tek tek göster
    _showNextDigit();
  }

  void _showNextDigit() {
    _showingDigitIndex++;
    if (_showingDigitIndex >= _currentNumber.length) {
      // Tüm basamaklar gösterildi → giriş aşamasına geç
      setState(() {
        _showingDigitIndex = -1;
        _phase = _GamePhase.input;
        _inputTimeLeft = _getInputTime();
      });
      _startInputTimer();
      return;
    }

    _digitController.forward(from: 0);
    _sound.playKeyTap();
    setState(() {});

    _digitTimer = Timer(
      Duration(milliseconds: _getDigitShowDuration()),
      _showNextDigit,
    );
  }

  void _startInputTimer() {
    _inputTimer?.cancel();
    _inputTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _inputTimeLeft--;
      });
      if (_inputTimeLeft <= 0) {
        timer.cancel();
        _onWrongAnswer();
      }
    });
  }

  // ─── Kullanıcı girişi ──────────────────────────────────────────
  void _onDigitPress(String digit) {
    if (_phase != _GamePhase.input || _isGameOver) return;

    _sound.playKeyTap();
    setState(() {
      _userInput += digit;
    });

    // Yeterli basamak girildiyse otomatik kontrol
    if (_userInput.length >= _currentNumber.length) {
      _inputTimer?.cancel();
      _checkAnswer();
    }
  }

  void _onDeletePress() {
    if (_phase != _GamePhase.input || _userInput.isEmpty) return;

    _sound.playDelete();
    setState(() {
      _userInput = _userInput.substring(0, _userInput.length - 1);
    });
  }

  void _checkAnswer() {
    if (_userInput == _currentNumber) {
      _onCorrectAnswer();
    } else {
      _onWrongAnswer();
    }
  }

  void _onCorrectAnswer() {
    _sound.playCorrect();
    final levelScore = _getLevelScore();
    _resultController.forward(from: 0);

    setState(() {
      _score += levelScore;
      _phase = _GamePhase.correct;
    });

    Future.delayed(const Duration(milliseconds: 1200), () {
      if (!mounted) return;
      if (_level >= _maxLevel) {
        setState(() {
          _level++;
          _isGameOver = true;
        });
        _saveScore();
        _showGameOverDialog();
        return;
      }
      setState(() {
        _level++;
        _phase = _GamePhase.ready;
      });
      // Otomatik olarak bir sonraki round başlasın
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted && !_isGameOver) _startRound();
      });
    });
  }

  void _onWrongAnswer() {
    _sound.playError();
    _shakeController.forward(from: 0);

    setState(() {
      _phase = _GamePhase.wrong;
      _isGameOver = true;
    });

    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) {
        _saveScore();
        _showGameOverDialog();
      }
    });
  }

  // ─── Puan hesaplama ──────────────────────────────────────────────
  /// Her seviye 10 puan; 10 seviye bitince oyun 100 puanla biter
  static const int _maxLevel = 10;
  int _getLevelScore() => 10;

  // ─── Skor kaydetme ────────────────────────────────────────────
  void _saveScore() {
    _sound.playGameEnd(_score.toDouble());
    final durationMs =
        DateTime.now().difference(_gameStartTime!).inMilliseconds;

    if (widget.onGameComplete != null) {
      final lbScore = LeaderboardService.calculateLeaderboardScore(
        gameId: 'memorle',
        isWin: true,
        score: _score.toDouble(),
        durationMs: durationMs,
      );
      widget.onGameComplete!(lbScore, durationMs);
    } else if (widget.isDailyMode) {
      TicketService().markDailyPlayed('memorle');
      StatsService().saveDailyStat(
        gameId: 'memorle',
        isWin: true,
        score: _score.toDouble(),
        attempts: _level - 1,
        maxAttempts: _level - 1,
        durationMs: durationMs,
      );
      LeaderboardService().submitScore(
        gameId: 'memorle',
        score: LeaderboardService.calculateLeaderboardScore(
          gameId: 'memorle',
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
        'memorle',
        LeaderboardService.calculateLeaderboardScore(
          gameId: 'memorle',
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
    final emoji = _score >= 70
        ? '🧠'
        : _score >= 50
            ? '⭐'
            : _score >= 30
                ? '👍'
                : '😅';
    final title = _score >= 50 ? (LanguageService().currentLanguage == 'tr' ? 'Müthiş Hafıza!' : 'Amazing Memory!') : (LanguageService().currentLanguage == 'tr' ? 'Oyun Bitti!' : 'Game Over!');
    final titleColor =
        _score >= 50 ? Colors.cyanAccent : Colors.orangeAccent;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF1A1A2E),
            _score >= 50
                ? const Color(0xFF0A1E2E)
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
            LanguageService().currentLanguage == 'tr' ? 'Seviye ${_level - 1} • ${_getDigitCount()} Basamak' : 'Level ${_level - 1} • ${_getDigitCount()} Digits',
            style: GoogleFonts.outfit(
              fontSize: 16,
              color: Colors.white54,
            ),
          ),
          if (_phase == _GamePhase.wrong) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: Column(
                children: [
                  Text(
                    LanguageService().currentLanguage == 'tr' ? 'Doğru Cevap' : 'Correct Answer',
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      color: Colors.white38,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _currentNumber,
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.greenAccent,
                      letterSpacing: 8,
                    ),
                  ),
                  if (_userInput.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      LanguageService().isTurkish ? 'Senin Cevabın' : 'Your Answer',
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        color: Colors.white38,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _userInput.isEmpty ? '—' : _userInput,
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.redAccent,
                        letterSpacing: 8,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
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
      gameId: 'memorle', isDailyMode: widget.isDailyMode, onGameComplete: widget.onGameComplete,
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF0A0A1A),
                Color(0xFF1A1A2E),
                Color(0xFF0D1B2A),
              ],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                _buildTopBar(),
                _buildInfoBar(),
                Expanded(child: _buildGameArea()),
                if (_phase == _GamePhase.input) _buildNumpad(),
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
                'Memorle',
                style: GoogleFonts.outfit(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              Text(
                LanguageService().isTurkish ? 'Sayıları hafızana al!' : 'Memorize the numbers!',
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  color: Colors.white38,
                ),
              ),
            ],
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.amberAccent.withValues(alpha: 0.15),
                  Colors.orangeAccent.withValues(alpha: 0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.amberAccent.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.star_rounded, color: Colors.amberAccent, size: 18),
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: [
          _buildChip(
            icon: Icons.layers_rounded,
            label: LanguageService().currentLanguage == 'tr' ? 'Seviye $_level' : 'Level $_level',
            color: Colors.cyanAccent,
          ),
          const SizedBox(width: 10),
          _buildChip(
            icon: Icons.pin_rounded,
            label: LanguageService().isTurkish ? '${_getDigitCount()} Basamak' : '${_getDigitCount()} Digits',
            color: Colors.purpleAccent,
          ),
          const Spacer(),
          _buildChip(
            icon: Icons.speed_rounded,
            label: '${_getDigitShowDuration()}ms',
            color: _getDigitShowDuration() <= 300
                ? Colors.redAccent
                : _getDigitShowDuration() <= 450
                    ? Colors.orangeAccent
                    : Colors.greenAccent,
          ),
        ],
      ),
    );
  }

  Widget _buildChip({
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

  Widget _buildGameArea() {
    return AnimatedBuilder(
      animation: _shakeController,
      builder: (context, child) {
        final shakeOffset = _isGameOver
            ? sin(_shakeAnimation.value * pi * 4) * 8
            : 0.0;
        return Transform.translate(
          offset: Offset(shakeOffset, 0),
          child: child,
        );
      },
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: _buildPhaseContent(),
        ),
      ),
    );
  }

  Widget _buildPhaseContent() {
    switch (_phase) {
      case _GamePhase.ready:
        return _buildReadyState();
      case _GamePhase.showing:
        return _buildShowingState();
      case _GamePhase.input:
        return _buildInputState();
      case _GamePhase.correct:
        return _buildCorrectState();
      case _GamePhase.wrong:
        return _buildWrongState();
    }
  }

  Widget _buildReadyState() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                Colors.cyanAccent.withValues(alpha: 0.15),
                Colors.transparent,
              ],
            ),
          ),
          child: const Icon(
            Icons.psychology_rounded,
            color: Colors.cyanAccent,
            size: 64,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          LanguageService().isTurkish ? 'Sayıları Hafızana Al' : 'Memorize the Numbers',
          style: GoogleFonts.outfit(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          LanguageService().currentLanguage == 'tr' ? '${_getDigitCount()} basamaklı sayı gösterilecek' : '${_getDigitCount()}-digit number will be shown',
          style: GoogleFonts.outfit(
            fontSize: 15,
            color: Colors.white54,
          ),
        ),
        const SizedBox(height: 32),
        GestureDetector(
          onTap: _startRound,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.cyanAccent.withValues(alpha: 0.2),
                  Colors.blueAccent.withValues(alpha: 0.15),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.cyanAccent.withValues(alpha: 0.4)),
              boxShadow: [
                BoxShadow(
                  color: Colors.cyanAccent.withValues(alpha: 0.15),
                  blurRadius: 16,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Text(
              _level == 1 ? AppStrings.start : (LanguageService().currentLanguage == 'tr' ? 'Devam' : 'Continue'),
              style: GoogleFonts.outfit(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.cyanAccent,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildShowingState() {
    if (_showingDigitIndex < 0 || _showingDigitIndex >= _currentNumber.length) {
      return const SizedBox();
    }

    final digit = _currentNumber[_showingDigitIndex];

    return AnimatedBuilder(
      animation: _digitAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _digitAnimation.value,
          child: Opacity(
            opacity: _digitAnimation.value.clamp(0, 1),
            child: child,
          ),
        );
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // İlerleme noktaları
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_currentNumber.length, (i) {
              final isActive = i <= _showingDigitIndex;
              return Container(
                width: 10,
                height: 10,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isActive
                      ? Colors.cyanAccent
                      : Colors.white.withValues(alpha: 0.15),
                  boxShadow: isActive
                      ? [
                          BoxShadow(
                            color: Colors.cyanAccent.withValues(alpha: 0.5),
                            blurRadius: 8,
                          ),
                        ]
                      : null,
                ),
              );
            }),
          ),
          const SizedBox(height: 48),
          // Ana sayı
          Container(
            width: 120,
            height: 140,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.cyanAccent.withValues(alpha: 0.12),
                  Colors.blueAccent.withValues(alpha: 0.08),
                ],
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: Colors.cyanAccent.withValues(alpha: 0.4),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.cyanAccent.withValues(alpha: 0.2),
                  blurRadius: 24,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: Center(
              child: Text(
                digit,
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 72,
                  fontWeight: FontWeight.bold,
                  color: Colors.cyanAccent,
                  shadows: [
                    Shadow(
                      color: Colors.cyanAccent.withValues(alpha: 0.5),
                      blurRadius: 16,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            '${_showingDigitIndex + 1} / ${_currentNumber.length}',
            style: GoogleFonts.outfit(
              fontSize: 16,
              color: Colors.white38,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputState() {
    final digits = _currentNumber.length;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Zamanlayıcı
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.timer_rounded,
              color: _inputTimeLeft <= 3
                  ? Colors.redAccent
                  : Colors.white54,
              size: 20,
            ),
            const SizedBox(width: 6),
            Text(
              '${_inputTimeLeft}s',
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: _inputTimeLeft <= 3
                    ? Colors.redAccent
                    : Colors.white54,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        // Giriş kutuları
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(digits, (i) {
            final hasValue = i < _userInput.length;
            final isNext = i == _userInput.length;
            return Container(
              width: digits <= 4 ? 52 : (digits <= 5 ? 44 : 38),
              height: digits <= 4 ? 60 : (digits <= 5 ? 52 : 46),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: hasValue
                    ? Colors.cyanAccent.withValues(alpha: 0.12)
                    : Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isNext
                      ? Colors.cyanAccent.withValues(alpha: 0.6)
                      : hasValue
                          ? Colors.cyanAccent.withValues(alpha: 0.3)
                          : Colors.white.withValues(alpha: 0.1),
                  width: isNext ? 2 : 1,
                ),
                boxShadow: isNext
                    ? [
                        BoxShadow(
                          color: Colors.cyanAccent.withValues(alpha: 0.15),
                          blurRadius: 8,
                        ),
                      ]
                    : null,
              ),
              child: Center(
                child: Text(
                  hasValue ? _userInput[i] : '',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: digits <= 4 ? 28 : (digits <= 5 ? 24 : 20),
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 16),
        Text(
          LanguageService().isTurkish ? 'Gördüğün sayıyı gir' : 'Enter the number you saw',
          style: GoogleFonts.outfit(
            fontSize: 14,
            color: Colors.white38,
          ),
        ),
      ],
    );
  }

  Widget _buildCorrectState() {
    return AnimatedBuilder(
      animation: _resultAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: 0.5 + _resultAnimation.value * 0.5,
          child: Opacity(
            opacity: _resultAnimation.value.clamp(0, 1),
            child: child,
          ),
        );
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.greenAccent.withValues(alpha: 0.15),
              boxShadow: [
                BoxShadow(
                  color: Colors.greenAccent.withValues(alpha: 0.2),
                  blurRadius: 24,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: const Icon(
              Icons.check_rounded,
              color: Colors.greenAccent,
              size: 56,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            LanguageService().currentLanguage == 'tr' ? 'Doğru! +${_getLevelScore()}' : 'Correct! +${_getLevelScore()}',
            style: GoogleFonts.outfit(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.greenAccent,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWrongState() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.redAccent.withValues(alpha: 0.15),
          ),
          child: const Icon(
            Icons.close_rounded,
            color: Colors.redAccent,
            size: 56,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          LanguageService().currentLanguage == 'tr' ? 'Yanlış!' : 'Wrong!',
          style: GoogleFonts.outfit(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.redAccent,
          ),
        ),
      ],
    );
  }

  Widget _buildNumpad() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
      child: Column(
        children: [
          // 1-3
          Row(
            children: [
              _numKey('1'),
              _numKey('2'),
              _numKey('3'),
            ],
          ),
          const SizedBox(height: 8),
          // 4-6
          Row(
            children: [
              _numKey('4'),
              _numKey('5'),
              _numKey('6'),
            ],
          ),
          const SizedBox(height: 8),
          // 7-9
          Row(
            children: [
              _numKey('7'),
              _numKey('8'),
              _numKey('9'),
            ],
          ),
          const SizedBox(height: 8),
          // Sil - 0 - Gönder
          Row(
            children: [
              _actionKey(
                icon: Icons.backspace_rounded,
                color: Colors.orangeAccent,
                onTap: _onDeletePress,
              ),
              _numKey('0'),
              _actionKey(
                icon: Icons.send_rounded,
                color: Colors.greenAccent,
                onTap: _userInput.length >= _currentNumber.length
                    ? _checkAnswer
                    : null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _numKey(String digit) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _onDigitPress(digit),
            borderRadius: BorderRadius.circular(14),
            child: Container(
              height: 56,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: Center(
                child: Text(
                  digit,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _actionKey({
    required IconData icon,
    required Color color,
    VoidCallback? onTap,
  }) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(14),
            child: Opacity(
              opacity: onTap != null ? 1.0 : 0.3,
              child: Container(
                height: 56,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: color.withValues(alpha: 0.2)),
                ),
                child: Center(
                  child: Icon(icon, color: color, size: 24),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
