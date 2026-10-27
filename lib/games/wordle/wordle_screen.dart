import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/sound_service.dart';
import '../../services/daily_challenge_service.dart';
import '../../services/stats_service.dart';
import '../../services/ticket_service.dart';
import '../../services/leaderboard_service.dart';
import '../../services/personal_best_service.dart';
import '../../services/language_service.dart';
import '../../services/score_scale.dart';
import '../../services/app_strings.dart';
import '../../services/coin_service.dart';
import '../../widgets/game_exit_wrapper.dart';
import '../../widgets/game_result_sheet.dart';
import '../../widgets/coin_offer_dialog.dart';
import '../common/game_common.dart';
import '../common/guess_board.dart';
import 'wordle_game.dart';

class WordleScreen extends StatefulWidget {
  final bool isDailyMode;
  final void Function(double score, [int durationMs])? onGameComplete;
  const WordleScreen({super.key, this.isDailyMode = true, this.onGameComplete});

  @override
  State<WordleScreen> createState() => _WordleScreenState();
}

class _WordleScreenState extends State<WordleScreen> with TickerProviderStateMixin {
  static const Color _bg = Color(0xFF121826);
  static const GuessPalette _palette = GuessPalette(correct: Color(0xFF4CAF6A), present: Color(0xFFE2B63C));

  static const List<List<String>> _rowsTr = [
    ['E', 'R', 'T', 'Y', 'U', 'I', 'O', 'P', 'Ğ', 'Ü'],
    ['A', 'S', 'D', 'F', 'G', 'H', 'J', 'K', 'L', 'Ş', 'İ'],
    ['ENTER', 'Z', 'C', 'V', 'B', 'N', 'M', 'Ö', 'Ç', 'DEL'],
  ];
  static const List<List<String>> _rowsEn = [
    ['Q', 'W', 'E', 'R', 'T', 'Y', 'U', 'I', 'O', 'P'],
    ['A', 'S', 'D', 'F', 'G', 'H', 'J', 'K', 'L'],
    ['ENTER', 'Z', 'X', 'C', 'V', 'B', 'N', 'M', 'DEL'],
  ];

  late WordleGame _game;
  bool _isLoading = true;
  String _message = '';
  final SoundService _sound = SoundService();
  final Stopwatch _stopwatch = Stopwatch();

  final Set<int> _hinted = {};
  static const int _maxHints = 2;

  late final AnimationController _shake = AnimationController(vsync: this, duration: const Duration(milliseconds: 450));
  late final AnimationController _reveal = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  );
  int? _shakingRow;
  int? _revealingRow;
  int? _bouncingCell;

  bool get _tr => LanguageService().isTurkish;

  // İpucu yalnızca bilet modunda; Daily Run sıralamasını coin etkilemez
  bool get _ticketMode => widget.onGameComplete == null && !widget.isDailyMode;

  @override
  void initState() {
    super.initState();
    _shake.addStatusListener((s) {
      if (s == AnimationStatus.completed) {
        _shake.reset();
        setState(() => _shakingRow = null);
      }
    });
    _reveal.addStatusListener((s) {
      if (s != AnimationStatus.completed) return;
      _reveal.reset();
      setState(() => _revealingRow = null);
      if (_game.isGameOver) _onGameOver();
    });
    _initGame();
  }

  Future<void> _initGame() async {
    await WordleGame.loadWords();
    final word = widget.isDailyMode
        ? DailyChallengeService.getSeededWordleWord(WordleGame.allWords)
        : WordleGame.getRandomWord();
    if (!mounted) return;
    setState(() {
      _game = WordleGame(targetWord: word);
      _isLoading = false;
    });
    _stopwatch.start();
  }

  @override
  void dispose() {
    _shake.dispose();
    _reveal.dispose();
    super.dispose();
  }

  bool get _locked => _isLoading || _game.isGameOver || _reveal.isAnimating;

  void _onLetter(String letter) {
    if (_locked || !_game.addLetter(letter)) return;
    _sound.playKeyTap();
    setState(() {
      _bouncingCell = _game.currentGuess.length - 1;
      _message = '';
    });
    Future.delayed(const Duration(milliseconds: 120), () {
      if (mounted) setState(() => _bouncingCell = null);
    });
  }

  void _onDelete() {
    if (_locked || !_game.removeLetter()) return;
    _sound.playDelete();
    setState(() => _message = '');
  }

  void _onEnter() {
    if (_locked) return;
    final result = _game.submitGuess();
    void reject(String msg) {
      _sound.playError();
      setState(() {
        _message = msg;
        _shakingRow = _game.guesses.length;
      });
      _shake.forward(from: 0);
      Future.delayed(const Duration(milliseconds: 1600), () {
        if (mounted && _message == msg) setState(() => _message = '');
      });
    }

    switch (result) {
      case GuessResult.notEnoughLetters:
        reject(AppStrings.notEnoughLetters);
      case GuessResult.invalidWord:
        reject(AppStrings.invalidWord);
      case GuessResult.correct:
      case GuessResult.outOfAttempts:
      case GuessResult.validGuess:
        _sound.playFlip();
        setState(() {
          _message = '';
          _revealingRow = _game.guesses.length - 1;
        });
        _reveal.forward(from: 0);
      case GuessResult.gameOver:
        break;
    }
  }

  /// Henüz yeşil bulunmamış bir harfi coin karşılığı açar.
  Future<void> _useHint() async {
    if (_locked || _hinted.length >= _maxHints) return;
    final found = <int>{
      for (final row in _game.guessStatuses)
        for (var i = 0; i < row.length; i++)
          if (row[i] == LetterStatus.correct) i,
    };
    final candidates = [
      for (var i = 0; i < _game.wordLength; i++)
        if (!found.contains(i) && !_hinted.contains(i)) i,
    ];
    if (candidates.isEmpty) return;
    final ok = await showCoinOffer(
      context,
      icon: Icons.lightbulb_rounded,
      title: AppStrings.hint,
      description: AppStrings.wordleHintDesc,
      confirmLabel: AppStrings.hint,
      price: CoinService.hintPrice,
      item: 'wordle_hint',
    );
    if (!ok || !mounted) return;
    final pos = candidates.first;
    final letter = _game.targetWord[pos];
    setState(() {
      _hinted.add(pos);
      _game.keyboardStatuses[letter] = LetterStatus.correct;
      _message = AppStrings.wordleHintResult(pos + 1, letter);
    });
  }

  void _onGameOver() {
    _stopwatch.stop();
    _game.isWon ? _sound.playWin() : _sound.playLose();
    final durationMs = _stopwatch.elapsedMilliseconds;
    final score = LeaderboardService.calculateLeaderboardScore(
      gameId: 'wordle',
      isWin: _game.isWon,
      attempts: _game.guesses.length,
      maxAttempts: _game.maxAttempts,
      durationMs: durationMs,
    );
    if (widget.onGameComplete != null) {
      widget.onGameComplete!(score, durationMs);
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
        score: score,
        attempts: _game.guesses.length,
        maxAttempts: _game.maxAttempts,
        durationMs: durationMs,
        isWin: _game.isWon,
      );
    } else {
      PersonalBestService().submit('wordle', score);
    }

    Future.delayed(const Duration(milliseconds: 450), () {
      if (!mounted) return;
      final statuses = [for (final r in _game.guessStatuses) r.map((s) => s.index).toList()];
      GameResultSheet.show(
        context,
        GameResultSheet(
          title: _game.isWon ? AppStrings.congratulations : (_tr ? 'Kelime buydu' : 'The word was'),
          headline: ScoreScale.normalize('wordle', score).toStringAsFixed(0),
          caption: _tr ? 'Puan (100 üzerinden)' : 'Score (out of 100)',
          accent: _palette.correct,
          isDailyRun: widget.onGameComplete != null,
          extra: Column(
            children: [
              _answerTiles(),
              const SizedBox(height: 12),
              Text(
                guessEmojiGrid(statuses),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, height: 1.2),
              ),
            ],
          ),
          stats: [
            GameResultStat(
              _tr ? 'Deneme' : 'Tries',
              '${_game.isWon ? _game.guesses.length : 'X'}/${_game.maxAttempts}',
            ),
            GameResultStat(_tr ? 'Süre' : 'Time', '${(durationMs / 1000).round()} sn'),
          ],
        ),
      );
    });
  }

  Widget _answerTiles() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final ch in _game.targetWord.split(''))
          Container(
            width: 38,
            height: 38,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _game.isWon ? _palette.correct : _palette.absent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              ch,
              style: GoogleFonts.nunito(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white),
            ),
          ),
      ],
    );
  }

  int _keyStatus(String k) => (_game.keyboardStatuses[k] ?? LetterStatus.empty).index;

  @override
  Widget build(BuildContext context) {
    return GameExitWrapper(
      gameId: 'wordle',
      isDailyMode: widget.isDailyMode,
      onGameComplete: widget.onGameComplete,
      child: Scaffold(
        backgroundColor: _bg,
        body: SafeArea(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: Color(0xFF4CAF6A)))
              : Column(
                  children: [
                    GameTopBar(
                      title: 'Wordle',
                      subtitle: _tr ? '5 harfli kelimeyi 6 denemede bul' : 'Find the 5-letter word in 6 tries',
                      accent: _palette.correct,
                      trailing: '${_game.guesses.length}/${_game.maxAttempts}',
                      action: _ticketMode && !_game.isGameOver && _hinted.length < _maxHints
                          ? IconButton(
                              tooltip: AppStrings.hint,
                              onPressed: _useHint,
                              icon: const Icon(Icons.lightbulb_rounded, color: Color(0xFFE2B63C)),
                            )
                          : null,
                    ),
                    GuessToast(_message),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                        child: GuessBoard(
                          rows: _game.maxAttempts,
                          cols: _game.wordLength,
                          guesses: _game.guesses,
                          statuses: [for (final r in _game.guessStatuses) r.map((s) => s.index).toList()],
                          current: _game.currentGuess,
                          isOver: _game.isGameOver,
                          palette: _palette,
                          reveal: _reveal,
                          revealingRow: _revealingRow,
                          shake: _shake,
                          shakingRow: _shakingRow,
                          bouncingCell: _bouncingCell,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(6, 0, 6, 10),
                      child: GuessKeyboard(
                        rows: _tr ? _rowsTr : _rowsEn,
                        statusOf: _keyStatus,
                        palette: _palette,
                        onKey: _onLetter,
                        onEnter: _onEnter,
                        onDelete: _onDelete,
                        enterLabel: AppStrings.enterKey,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
