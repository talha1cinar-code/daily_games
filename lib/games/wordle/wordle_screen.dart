import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../../services/settings_service.dart';
import '../../services/sound_service.dart';
import '../../services/daily_challenge_service.dart';
import '../../services/stats_service.dart';
import '../../services/ticket_service.dart';
import '../../services/leaderboard_service.dart';
import '../../widgets/game_exit_wrapper.dart';
import 'wordle_game.dart';
import 'widgets/wordle_grid.dart';
import 'widgets/wordle_keyboard.dart';

class WordleScreen extends StatefulWidget {
  final bool isDailyMode;
  final void Function(double score, [int durationMs])? onGameComplete;
  const WordleScreen({super.key, this.isDailyMode = true, this.onGameComplete});

  @override
  State<WordleScreen> createState() => _WordleScreenState();
}

class _WordleScreenState extends State<WordleScreen>
    with TickerProviderStateMixin {
  late WordleGame _game;
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
  
  // SÃ¼re Ã¶lÃ§Ã¼mÃ¼
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
      duration: const Duration(milliseconds: 1800),
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
            // Daily Run modunda: skoru hesapla ama Firebase'e yazma
            final score = LeaderboardService.calculateLeaderboardScore(
              gameId: 'wordle',
              isWin: _game.isWon,
              attempts: _game.guesses.length,
              maxAttempts: _game.maxAttempts,
              durationMs: durationMs,
            );
            widget.onGameComplete!(score, durationMs ?? 0);
          } else if (widget.isDailyMode) {
            TicketService().markDailyPlayed('wordle');
            StatsService().saveDailyStat(
              gameId: 'wordle',
              isWin: _game.isWon,
              attempts: _game.guesses.length,
              maxAttempts: _game.maxAttempts,
              targetValue: _game.targetWord,
              durationMs: durationMs,
            );
            LeaderboardService().submitScore(
              gameId: 'wordle',
              score: LeaderboardService.calculateLeaderboardScore(
                gameId: 'wordle',
                isWin: _game.isWon,
                attempts: _game.guesses.length,
                maxAttempts: _game.maxAttempts,
                durationMs: durationMs,
              ),
              attempts: _game.guesses.length,
              maxAttempts: _game.maxAttempts,
              durationMs: durationMs,
              isWin: _game.isWon,
            );
          }
          
          Future.delayed(const Duration(milliseconds: 500), _showGameOverDialog);
        }
      }
    });

    _initGame();
  }

  Future<void> _initGame() async {
    await WordleGame.loadWords();
    
    String word;
    if (widget.isDailyMode) {
      // Ã–nce Firebase override, yoksa seed tabanlÄ± deterministik seÃ§im
      String? firebaseWord = await DailyChallengeService().getWordleChallenge();
      word = firebaseWord ?? DailyChallengeService.getSeededWordleWord(WordleGame.allWords);
    } else {
      word = WordleGame.getRandomWord();
    }
    
    setState(() {
      _game = WordleGame(targetWord: word);
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

  void _onLetterTap(String letter) {
    if (_game.isGameOver || _revealController.isAnimating) return;
    final added = _game.addLetter(letter);
    if (added) {
      _sound.playKeyTap();
      setState(() {
        _bouncingCell = _game.currentGuess.length - 1;
        _message = '';
      });
      // Bounce'u sÄ±fÄ±rla
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted) setState(() => _bouncingCell = null);
      });
    }
  }

  void _onDeleteTap() {
    if (_game.isGameOver || _revealController.isAnimating) return;
    final removed = _game.removeLetter();
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
        case GuessResult.notEnoughLetters:
          _message = 'Yeterli harf yok!';
          _shakingRow = _game.guesses.length;
          _shakeController.forward();
          _sound.playError();
        case GuessResult.invalidWord:
          _message = 'GeÃ§ersiz kelime!';
          _shakingRow = _game.guesses.length;
          _shakeController.forward();
          _sound.playError();
        case GuessResult.correct:
          _message = 'Tebrikler! ğŸ‰';
          _revealingRow = _game.guesses.length - 1;
          _revealController.forward();
          _sound.playFlip();
        case GuessResult.outOfAttempts:
          _message = 'HakkÄ±n bitti!';
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          backgroundColor: Colors.white,
          contentPadding: const EdgeInsets.all(28),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Emoji
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 500),
                curve: Curves.elasticOut,
                builder: (context, value, child) {
                  return Transform.scale(
                    scale: value,
                    child: child,
                  );
                },
                child: Text(
                  _game.isWon ? 'ğŸ‰' : 'ğŸ˜”',
                  style: const TextStyle(fontSize: 64),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _game.isWon ? 'Tebrikler!' : 'Maalesef!',
                style: GoogleFonts.nunito(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: _game.isWon
                      ? AppColors.wordleCorrect
                      : AppColors.accent,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _game.isWon
                    ? '${_game.guesses.length}/${_game.maxAttempts} denemede bildin!'
                    : 'DoÄŸru kelime: ${_game.targetWord}',
                style: GoogleFonts.nunito(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).pop();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    widget.onGameComplete != null ? 'Sonraki' : 'Ana Sayfa',
                    style: GoogleFonts.nunito(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
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
      return GameExitWrapper(
        gameId: 'wordle',
        isDailyMode: widget.isDailyMode, onGameComplete: widget.onGameComplete,
        child: Scaffold(
          backgroundColor: AppColors.background,
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(color: AppColors.primary),
                const SizedBox(height: 16),
                Text(
                  'Kelimeler yÃ¼kleniyor...',
                  style: GoogleFonts.nunito(
                    color: AppColors.textSecondary,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return GameExitWrapper(
      gameId: 'wordle',
      isDailyMode: widget.isDailyMode, onGameComplete: widget.onGameComplete,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Column(
            children: [
              // Ãœst bar
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded),
                      onPressed: () => Navigator.maybePop(context),
                    ),
                    const Spacer(),
                    Text(
                      'WORDLE',
                      style: GoogleFonts.nunito(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                        letterSpacing: 4,
                      ),
                    ),
                  const Spacer(),
                  // Ses butonu
                  GestureDetector(
                    onTap: () {
                      SettingsService().toggleSfx();
                      setState(() {}); // UI güncellemesi için
                    },
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(
                        !SettingsService().isSfxEnabled
                            ? Icons.volume_off_rounded
                            : Icons.volume_up_rounded,
                        color: AppColors.textSecondary,
                        size: 18,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Mesaj alanÄ±
            SizedBox(
              height: 44,
              child: Center(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: _message.isNotEmpty
                      ? Container(
                          key: ValueKey(_message),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.textPrimary,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            _message,
                            style: GoogleFonts.nunito(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ),
            ),
            // Izgara
            Expanded(
              child: Center(
                child: WordleGrid(
                  game: _game,
                  shakeAnimation: _shakeAnimation,
                  shakingRow: _shakingRow,
                  revealAnimation: _revealAnimation,
                  revealingRow: _revealingRow,
                  bouncingCell: _bouncingCell,
                ),
              ),
            ),
            // Klavye
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 16),
              child: WordleKeyboard(
                keyStatuses: _game.keyboardStatuses,
                onLetterTap: _onLetterTap,
                onEnterTap: _onEnterTap,
                onDeleteTap: _onDeleteTap,
              ),
            ),
          ],
        ),
      ),
    ),
    );
  }
}

