import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../widgets/game_exit_wrapper.dart';
import '../../widgets/game_result_sheet.dart';
import '../../services/sound_service.dart';
import '../../services/daily_challenge_service.dart';
import '../../services/ticket_service.dart';
import '../../services/stats_service.dart';
import '../../services/leaderboard_service.dart';
import '../../services/personal_best_service.dart';
import '../../services/language_service.dart';
import '../../services/score_scale.dart';
import '../../services/app_strings.dart';
import '../common/game_common.dart';
import '../common/guess_board.dart';
import 'nerdle_game.dart';

class NerdleScreen extends StatefulWidget {
  final bool isDailyMode;
  final void Function(double score, [int durationMs])? onGameComplete;
  const NerdleScreen({super.key, this.isDailyMode = true, this.onGameComplete});

  @override
  State<NerdleScreen> createState() => _NerdleScreenState();
}

class _NerdleScreenState extends State<NerdleScreen> with TickerProviderStateMixin {
  static const Color _bg = Color(0xFF151327);
  static const GuessPalette _palette = GuessPalette(
    correct: Color(0xFF3DBE8B),
    present: Color(0xFFA066F0),
    absent: Color(0xFF3B3A55),
    tile: Color(0xFF221F3B),
    tileBorder: Color(0xFF38345C),
    key: Color(0xFF4D4873),
  );

  static const List<List<String>> _rows = [
    ['1', '2', '3', '4', '5', '6', '7', '8', '9', '0'],
    ['+', '-', '*', '/', '=', 'DEL', 'ENTER'],
  ];

  late final NerdleGame _game;
  String _message = '';
  final SoundService _sound = SoundService();
  final Stopwatch _stopwatch = Stopwatch()..start();

  late final AnimationController _shake = AnimationController(vsync: this, duration: const Duration(milliseconds: 450));
  late final AnimationController _reveal = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  );
  int? _shakingRow;
  int? _revealingRow;
  int? _bouncingCell;

  bool get _tr => LanguageService().isTurkish;

  static String _show(String c) => switch (c) {
    '*' => '×',
    '/' => '÷',
    '-' => '−',
    _ => c,
  };

  @override
  void initState() {
    super.initState();
    final eq = widget.isDailyMode
        ? DailyChallengeService.getSeededNerdleEquation(NerdleGame.equations)
        : NerdleGame.getRandomEquation();
    _game = NerdleGame(targetEquation: eq);
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
  }

  @override
  void dispose() {
    _shake.dispose();
    _reveal.dispose();
    super.dispose();
  }

  bool get _locked => _game.isGameOver || _reveal.isAnimating;

  void _onChar(String c) {
    if (_locked || !_game.addCharacter(c)) return;
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
    if (_locked || !_game.removeCharacter()) return;
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
      case GuessResult.notEnoughChars:
        reject(_tr ? '9 karakter gerekli' : '9 characters needed');
      case GuessResult.noEquals:
        reject(_tr ? '= işareti gerekli' : '= sign required');
      case GuessResult.invalidEquation:
        reject(_tr ? 'Geçersiz denklem' : 'Invalid equation');
      case GuessResult.wrongAnswer:
        reject(_tr ? 'İki taraf eşit değil' : 'Sides are not equal');
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

  void _onGameOver() {
    _stopwatch.stop();
    _game.isWon ? _sound.playWin() : _sound.playLose();
    final durationMs = _stopwatch.elapsedMilliseconds;
    final score = LeaderboardService.calculateLeaderboardScore(
      gameId: 'nerdle',
      isWin: _game.isWon,
      attempts: _game.guesses.length,
      maxAttempts: NerdleGame.maxAttempts,
      durationMs: durationMs,
    );
    if (widget.onGameComplete != null) {
      widget.onGameComplete!(score, durationMs);
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
        score: score,
        attempts: _game.guesses.length,
        maxAttempts: NerdleGame.maxAttempts,
        durationMs: durationMs,
        isWin: _game.isWon,
      );
    } else {
      PersonalBestService().submit('nerdle', score);
    }

    Future.delayed(const Duration(milliseconds: 450), () {
      if (!mounted) return;
      final statuses = [for (final r in _game.guessStatuses) r.map((s) => s.index).toList()];
      GameResultSheet.show(
        context,
        GameResultSheet(
          title: _game.isWon ? (_tr ? 'Dahisin!' : 'Genius!') : (_tr ? 'Denklem buydu' : 'The equation was'),
          headline: ScoreScale.normalize('nerdle', score).toStringAsFixed(0),
          caption: _tr ? 'Puan (100 üzerinden)' : 'Score (out of 100)',
          accent: _palette.correct,
          isDailyRun: widget.onGameComplete != null,
          extra: Column(
            children: [
              Text(
                _game.targetEquation.split('').map(_show).join(' '),
                style: GoogleFonts.nunito(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: _game.isWon ? _palette.correct : Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                guessEmojiGrid(statuses, present: '🟪'),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, height: 1.2),
              ),
            ],
          ),
          stats: [
            GameResultStat(
              _tr ? 'Deneme' : 'Tries',
              '${_game.isWon ? _game.guesses.length : 'X'}/${NerdleGame.maxAttempts}',
            ),
            GameResultStat(_tr ? 'Süre' : 'Time', '${(durationMs / 1000).round()} sn'),
          ],
        ),
      );
    });
  }

  int _keyStatus(String k) => (_game.keyStatuses[k] ?? LetterStatus.empty).index;

  @override
  Widget build(BuildContext context) {
    return GameExitWrapper(
      gameId: 'nerdle',
      isDailyMode: widget.isDailyMode,
      onGameComplete: widget.onGameComplete,
      child: Scaffold(
        backgroundColor: _bg,
        body: SafeArea(
          child: Column(
            children: [
              GameTopBar(
                title: 'Nerdle',
                subtitle: _tr ? '9 karakterlik denklemi 6 denemede bul' : 'Find the 9-character equation in 6 tries',
                accent: _palette.correct,
                trailing: '${_game.guesses.length}/${NerdleGame.maxAttempts}',
              ),
              _legend(),
              GuessToast(_message),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: GuessBoard(
                    rows: NerdleGame.maxAttempts,
                    cols: NerdleGame.equationLength,
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
                    maxTile: 46,
                    display: _show,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 10),
                child: GuessKeyboard(
                  rows: _rows,
                  statusOf: _keyStatus,
                  palette: _palette,
                  onKey: _onChar,
                  onEnter: _onEnter,
                  onDelete: _onDelete,
                  enterLabel: AppStrings.enterKey,
                  keyHeight: 58,
                  fontSize: 22,
                  display: _show,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Renklerin anlamı: oyuncu ilk bakışta çözsün
  Widget _legend() {
    Widget item(Color c, String t) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(3)),
        ),
        const SizedBox(width: 5),
        Text(
          t,
          style: GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white60),
        ),
      ],
    );
    return Wrap(
      spacing: 14,
      runSpacing: 4,
      alignment: WrapAlignment.center,
      children: [
        item(_palette.correct, _tr ? 'Doğru yer' : 'Right spot'),
        item(_palette.present, _tr ? 'Var, yeri yanlış' : 'Wrong spot'),
        item(_palette.absent, _tr ? 'Yok' : 'Not in it'),
      ],
    );
  }
}
