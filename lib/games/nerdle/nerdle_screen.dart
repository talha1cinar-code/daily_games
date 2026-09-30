import 'dart:math';
import 'package:flutter/material.dart';
import '../../widgets/game_exit_wrapper.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/sound_service.dart';
import '../../services/daily_challenge_service.dart';
import '../../services/ticket_service.dart';
import '../../services/stats_service.dart';
import '../../services/leaderboard_service.dart';
import 'nerdle_game.dart';

class NerdleScreen extends StatefulWidget {
  final bool isDailyMode;
  final void Function(double score, [int durationMs])? onGameComplete;
  const NerdleScreen({super.key, this.isDailyMode = true, this.onGameComplete});

  @override
  State<NerdleScreen> createState() => _NerdleScreenState();
}

class _NerdleScreenState extends State<NerdleScreen>
    with TickerProviderStateMixin {
  late NerdleGame _game;
  bool _isLoading = true;
  String _message = '';
  final SoundService _sound = SoundService();

  // Sallama animasyonu
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;
  int? _shakingRow;

  // Reveal animasyonu
  late AnimationController _revealController;
  late Animation<double> _revealAnimation;
  int? _revealingRow;

  // Harf bounce
  int? _bouncingCell;
  
  // Süre ölçümü
  DateTime? _startTime;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _shakeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.easeOut),
    );
    _shakeController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _shakeController.reset();
        setState(() {
          _shakingRow = null;
          _message = '';
        });
      }
    });

    _revealController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    _revealAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _revealController, curve: Curves.linear),
    );
    _revealController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _revealController.reset();
        setState(() => _revealingRow = null);
        if (_game.isGameOver) {
          if (_game.isWon) {
            _sound.playWin();
          } else {
            _sound.playLose();
          }
          
          final durationMs = _startTime != null ? DateTime.now().difference(_startTime!).inMilliseconds : null;
          if (widget.onGameComplete != null) {
            final score = LeaderboardService.calculateLeaderboardScore(
              gameId: 'nerdle',
              isWin: _game.isWon,
              attempts: _game.guesses.length,
              maxAttempts: NerdleGame.maxAttempts,
              durationMs: durationMs,
            );
            widget.onGameComplete!(score, durationMs ?? 0);
          } else if (widget.isDailyMode) {
            TicketService().markDailyPlayed('nerdle');
            StatsService().saveDailyStat(
              gameId: 'nerdle',
              isWin: _game.isWon,
              attempts: _game.guesses.length,
              maxAttempts: NerdleGame.maxAttempts,
              targetValue: _game.targetEquation,
              durationMs: durationMs,
            );
            LeaderboardService().submitScore(
              gameId: 'nerdle',
              score: LeaderboardService.calculateLeaderboardScore(
                gameId: 'nerdle',
                isWin: _game.isWon,
                attempts: _game.guesses.length,
                maxAttempts: NerdleGame.maxAttempts,
                durationMs: durationMs,
              ),
              attempts: _game.guesses.length,
              maxAttempts: NerdleGame.maxAttempts,
              durationMs: durationMs,
              isWin: _game.isWon,
            );
          }
          
          Future.delayed(
              const Duration(milliseconds: 500), _showGameOverDialog);
        }
      }
    });

    _initGame();
  }

  Future<void> _initGame() async {
    String eq;
    if (widget.isDailyMode) {


      eq = DailyChallengeService.getSeededNerdleEquation(NerdleGame.equations);
    } else {
      eq = NerdleGame.getRandomEquation();
    }
    
    setState(() {
      _game = NerdleGame(targetEquation: eq);
      _isLoading = false;
      _startTime = DateTime.now();
    });
  }

  @override
  void dispose() {
    _shakeController.dispose();
    _revealController.dispose();
    super.dispose();
  }

  void _onCharTap(String char) {
    if (_game.isGameOver || _revealController.isAnimating) return;
    final added = _game.addCharacter(char);
    if (added) {
      _sound.playKeyTap();
      setState(() {
        _bouncingCell = _game.currentGuess.length - 1;
        _message = '';
      });
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted) setState(() => _bouncingCell = null);
      });
    }
  }

  void _onDeleteTap() {
    if (_game.isGameOver || _revealController.isAnimating) return;
    final removed = _game.removeCharacter();
    if (removed) {
      _sound.playDelete();
      setState(() => _message = '');
    }
  }

  void _onEnterTap() {
    if (_game.isGameOver || _revealController.isAnimating) return;

    final result = _game.submitGuess();

    setState(() {
      switch (result) {
        case GuessResult.notEnoughChars:
          _message = 'Yeterli karakter yok!';
          _shakingRow = _game.guesses.length;
          _shakeController.forward();
          _sound.playError();
        case GuessResult.noEquals:
          _message = '= işareti gerekli!';
          _shakingRow = _game.guesses.length;
          _shakeController.forward();
          _sound.playError();
        case GuessResult.invalidEquation:
          _message = 'Geçersiz denklem!';
          _shakingRow = _game.guesses.length;
          _shakeController.forward();
          _sound.playError();
        case GuessResult.wrongAnswer:
          _message = 'Denklem eşit değil!';
          _shakingRow = _game.guesses.length;
          _shakeController.forward();
          _sound.playError();
        case GuessResult.correct:
          _message = 'Tebrikler! 🎉';
          _revealingRow = _game.guesses.length - 1;
          _revealController.forward();
          _sound.playFlip();
        case GuessResult.outOfAttempts:
          _message = 'Hakkın bitti!';
          _revealingRow = _game.guesses.length - 1;
          _revealController.forward();
          _sound.playFlip();
        case GuessResult.validGuess:
          _message = '';
          _revealingRow = _game.guesses.length - 1;
          _revealController.forward();
          _sound.playFlip();
        case GuessResult.gameOver:
          break;
      }
    });
  }

  void _showGameOverDialog() {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          backgroundColor: const Color(0xFF1B1B2F),
          contentPadding: const EdgeInsets.all(28),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 500),
                curve: Curves.elasticOut,
                builder: (context, value, child) =>
                    Transform.scale(scale: value, child: child),
                child: Text(
                  _game.isWon ? '🧮' : '😔',
                  style: const TextStyle(fontSize: 56),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _game.isWon ? 'Dahisin!' : 'Maalesef!',
                style: GoogleFonts.nunito(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: _game.isWon
                      ? const Color(0xFF6BCB77)
                      : const Color(0xFFFF6B6B),
                ),
              ),
              const SizedBox(height: 8),
              if (_game.isWon)
                Text(
                  '${_game.guesses.length}/${NerdleGame.maxAttempts} denemede çözdün!',
                  style: GoogleFonts.nunito(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: Colors.white70,
                  ),
                )
              else
                Column(
                  children: [
                    Text(
                      'Doğru cevap:',
                      style: GoogleFonts.nunito(
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        color: Colors.white54,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _game.targetEquation,
                      style: GoogleFonts.nunito(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF6BCB77),
                        letterSpacing: 3,
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).pop();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6C5CE7),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: Text(widget.onGameComplete != null ? 'Sonraki' : 'Ana Sayfa',
                      style: GoogleFonts.nunito(
                          fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF1B1B2F),
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return GameExitWrapper(gameId: 'nerdle', isDailyMode: widget.isDailyMode, onGameComplete: widget.onGameComplete, child: Scaffold(
      backgroundColor: const Color(0xFF1B1B2F),
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            // Mesaj alanı
            SizedBox(
              height: 40,
              child: Center(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: _message.isNotEmpty
                      ? Container(
                          key: ValueKey(_message),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 18, vertical: 7),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            _message,
                            style: GoogleFonts.nunito(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ),
            ),
            // Grid
            Expanded(child: Center(child: _buildGrid())),
            // Klavye
            _buildKeyboard(),
            const SizedBox(height: 12),
          ],
        ),
      ),
    ));
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
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
          Text(
            'NERDLE',
            style: GoogleFonts.nunito(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: 4,
            ),
          ),
          const Spacer(),
          const SizedBox(width: 34),
        ],
      ),
    );
  }

  // ─── 9x6 Grid ────────────────────────────────────────────────────
  Widget _buildGrid() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(NerdleGame.maxAttempts, (row) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 5),
            child: _buildRow(row),
          );
        }),
      ),
    );
  }

  Widget _buildRow(int row) {
    Widget rowWidget = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(NerdleGame.equationLength, (col) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2.5),
          child: _buildCell(row, col),
        );
      }),
    );

    // Sallama animasyonu
    if (_shakingRow == row && _shakeController.isAnimating) {
      return AnimatedBuilder(
        animation: _shakeAnimation,
        builder: (context, child) {
          final progress = _shakeAnimation.value;
          final offset = sin(progress * pi * 4) * 8 * (1 - progress);
          return Transform.translate(
            offset: Offset(offset, 0),
            child: child,
          );
        },
        child: rowWidget,
      );
    }

    return rowWidget;
  }

  Widget _buildCell(int row, int col) {
    String char = '';
    LetterStatus status = LetterStatus.empty;
    bool isCurrentRow = row == _game.guesses.length && !_game.isGameOver;
    bool hasChar = false;

    if (row < _game.guesses.length) {
      char = _game.guesses[row][col];
      status = _game.guessStatuses[row][col];
      hasChar = true;
    } else if (isCurrentRow && col < _game.currentGuess.length) {
      char = _game.currentGuess[col];
      hasChar = true;
    }

    // Reveal animasyonu
    bool isRevealing = _revealingRow == row && _revealController.isAnimating;
    double cellProgress = 0.0;
    if (isRevealing) {
      final cellDelay = col * 0.11;
      cellProgress = ((_revealAnimation.value * 1.5 - cellDelay)).clamp(0.0, 1.0);
    }

    // Renk belirleme
    Color bgColor;
    Color borderColor;
    Color textColor;

    if (isRevealing && cellProgress > 0.5) {
      // Flip'in ikinci yarısı — renkli
      final colors = _getStatusColors(status);
      bgColor = colors[0];
      borderColor = colors[1];
      textColor = Colors.white;
    } else if (isRevealing && cellProgress > 0.0) {
      bgColor = const Color(0xFF2A2A40);
      borderColor = Colors.white.withValues(alpha: 0.2);
      textColor = Colors.white;
    } else {
      if (status != LetterStatus.empty) {
        final colors = _getStatusColors(status);
        bgColor = colors[0];
        borderColor = colors[1];
        textColor = Colors.white;
      } else {
        bgColor = const Color(0xFF2A2A40);
        borderColor = hasChar
            ? Colors.white.withValues(alpha: 0.3)
            : Colors.white.withValues(alpha: 0.08);
        textColor = Colors.white;
      }
    }

    // Bounce
    bool shouldBounce = isCurrentRow &&
        _bouncingCell != null &&
        col == _bouncingCell &&
        hasChar;

    Widget cell = Container(
      width: 36,
      height: 48,
      decoration: BoxDecoration(
        color: bgColor,
        border: Border.all(color: borderColor, width: 2),
        borderRadius: BorderRadius.circular(8),
      ),
      alignment: Alignment.center,
      child: Text(
        char,
        style: GoogleFonts.nunito(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: textColor,
        ),
      ),
    );

    if (shouldBounce) {
      cell = TweenAnimationBuilder<double>(
        key: ValueKey('bounce_${row}_${col}_$char'),
        tween: Tween(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 150),
        builder: (context, value, child) {
          final scale =
              value < 0.5 ? 1.0 + value * 0.2 : 1.0 + (1.0 - value) * 0.2;
          return Transform.scale(scale: scale, child: child);
        },
        child: cell,
      );
    }

    // Flip
    if (isRevealing && cellProgress > 0.0) {
      final flipValue = cellProgress;
      final angle =
          flipValue <= 0.5 ? flipValue * pi : (1.0 - flipValue) * pi;
      cell = Transform(
        alignment: Alignment.center,
        transform: Matrix4.identity()
          ..setEntry(3, 2, 0.001)
          ..rotateX(angle),
        child: cell,
      );
    }

    return cell;
  }

  List<Color> _getStatusColors(LetterStatus status) {
    switch (status) {
      case LetterStatus.correct:
        return [const Color(0xFF6BCB77), const Color(0xFF6BCB77)];
      case LetterStatus.present:
        return [const Color(0xFF9B59B6), const Color(0xFF9B59B6)]; // Mor
      case LetterStatus.absent:
        return [const Color(0xFF3D3D50), const Color(0xFF3D3D50)];
      case LetterStatus.empty:
        return [const Color(0xFF2A2A40), Colors.white.withValues(alpha: 0.08)];
    }
  }

  // ─── Özel Klavye ──────────────────────────────────────────────────
  Widget _buildKeyboard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxWidth = constraints.maxWidth;

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Satır 1: Sayılar 0-9
              _buildKeyRow(
                ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'],
                maxWidth,
              ),
              const SizedBox(height: 6),
              // Satır 2: Operatörler + Delete + Enter
              _buildKeyRow(
                ['+', '-', '*', '/', '=', 'DEL', 'ENTER'],
                maxWidth,
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildKeyRow(List<String> keys, double maxWidth) {
    // ENTER ve DEL daha geniş olsun
    int totalUnits = 0;
    for (final key in keys) {
      if (key == 'ENTER') {
        totalUnits += 3;
      } else if (key == 'DEL') {
        totalUnits += 2;
      } else {
        totalUnits += 2;
      }
    }

    final gap = 4.0 * (keys.length - 1);
    final unitWidth = (maxWidth - gap) / totalUnits;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: keys.asMap().entries.map((entry) {
        final key = entry.value;
        final isLast = entry.key == keys.length - 1;

        double keyWidth;
        if (key == 'ENTER') {
          keyWidth = unitWidth * 3;
        } else if (key == 'DEL') {
          keyWidth = unitWidth * 2;
        } else {
          keyWidth = unitWidth * 2;
        }

        return Padding(
          padding: EdgeInsets.only(right: isLast ? 0 : 4),
          child: _buildKey(key, keyWidth),
        );
      }).toList(),
    );
  }

  Widget _buildKey(String key, double width) {
    Color bgColor;
    Color textColor = Colors.white;
    IconData? icon;

    if (key == 'ENTER') {
      bgColor = const Color(0xFF6BCB77);
      icon = Icons.keyboard_return_rounded;
    } else if (key == 'DEL') {
      bgColor = const Color(0xFFE17055);
      icon = Icons.backspace_rounded;
    } else {
      // Normal karakter — duruma göre renklendir
      final status = _game.keyStatuses[key];
      if (status != null) {
        final colors = _getStatusColors(status);
        bgColor = colors[0];
      } else {
        bgColor = Colors.white.withValues(alpha: 0.12);
      }
    }

    return GestureDetector(
      onTap: () {
        if (key == 'ENTER') {
          _onEnterTap();
        } else if (key == 'DEL') {
          _onDeleteTap();
        } else {
          _onCharTap(key);
        }
      },
      child: Container(
        width: width,
        height: 48,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: icon != null
            ? Icon(icon, color: textColor, size: 20)
            : Text(
                key,
                style: GoogleFonts.nunito(
                  fontSize: _isOperator(key) ? 22 : 18,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                ),
              ),
      ),
    );
  }

  bool _isOperator(String c) => '+-*/='.contains(c);
}
