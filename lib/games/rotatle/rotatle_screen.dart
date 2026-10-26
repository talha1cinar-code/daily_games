import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../widgets/game_exit_wrapper.dart';
import '../../widgets/game_result_sheet.dart';
import '../../widgets/chunky_button.dart';
import '../../services/sound_service.dart';
import '../../services/daily_challenge_service.dart';
import '../../services/language_service.dart';
import '../common/game_common.dart';
import '../common/cells_view.dart';
import 'rotatle_game.dart';

class RotatleScreen extends StatefulWidget {
  final bool isDailyMode;
  final void Function(double score, [int durationMs])? onGameComplete;
  const RotatleScreen({super.key, this.isDailyMode = true, this.onGameComplete});

  @override
  State<RotatleScreen> createState() => _RotatleScreenState();
}

class _RotatleScreenState extends State<RotatleScreen> {
  static const Color _bg = Color(0xFF101C2E);
  static const Color _accent = Color(0xFF4F8BFF);
  static const Color _good = Color(0xFF3DDC84);
  static const Color _bad = Color(0xFFFF5D73);

  late final RotatleGame _game;
  final SoundService _sound = SoundService();
  final Stopwatch _stopwatch = Stopwatch()..start();
  final Stopwatch _roundWatch = Stopwatch();

  int _round = 0;
  int? _picked;
  final List<double> _scores = [];
  final List<bool> _correct = [];

  bool get _tr => LanguageService().isTurkish;
  RotateRound get _current => _game.rounds[_round];
  double get _total => _scores.fold(0.0, (a, b) => a + b);

  @override
  void initState() {
    super.initState();
    _game = RotatleGame(widget.isDailyMode ? Random(DailyChallengeService.getSeededSeed('rotatle')) : Random());
    _roundWatch.start();
  }

  void _pick(int i) {
    if (_picked != null) return;
    _roundWatch.stop();
    final ok = i == _current.answer;
    ok ? _sound.playCorrect() : _sound.playError();
    setState(() {
      _picked = i;
      _correct.add(ok);
      _scores.add(RotatleGame.roundScore(ok, _roundWatch.elapsedMilliseconds));
    });
  }

  void _next() {
    if (_round + 1 >= RotatleGame.totalRounds) {
      _finish();
      return;
    }
    _sound.playKeyTap();
    setState(() {
      _round++;
      _picked = null;
    });
    _roundWatch
      ..reset()
      ..start();
  }

  void _finish() {
    _stopwatch.stop();
    final score = _total;
    reportGameScore(
      gameId: 'rotatle',
      isDailyMode: widget.isDailyMode,
      onGameComplete: widget.onGameComplete,
      score: score,
      durationMs: _stopwatch.elapsedMilliseconds,
      attempts: RotatleGame.totalRounds,
      maxAttempts: RotatleGame.totalRounds,
    );
    final right = _correct.where((c) => c).length;
    GameResultSheet.show(
      context,
      GameResultSheet(
        title: right == RotatleGame.totalRounds ? (_tr ? 'Zihnin dönüyor!' : 'Your mind spins!') : (_tr ? 'Dönüşler tamam' : 'Rotations done'),
        headline: score.toStringAsFixed(0),
        caption: _tr ? 'Puan (100 üzerinden)' : 'Score (out of 100)',
        accent: _accent,
        isDailyRun: widget.onGameComplete != null,
        stats: [
          GameResultStat(_tr ? 'Doğru' : 'Correct', '$right/${RotatleGame.totalRounds}'),
          GameResultStat(_tr ? 'Süre' : 'Time', '${(_stopwatch.elapsedMilliseconds / 1000).round()} sn'),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GameExitWrapper(
      gameId: 'rotatle',
      isDailyMode: widget.isDailyMode,
      onGameComplete: widget.onGameComplete,
      child: Scaffold(
        backgroundColor: _bg,
        body: SafeArea(
          child: Column(
            children: [
              GameTopBar(
                title: 'Rotatle',
                subtitle: _tr ? 'Döndürülmüş olanı bul' : 'Find the rotated one',
                trailing: _total.toStringAsFixed(0),
                accent: _accent,
              ),
              RoundDots(total: RotatleGame.totalRounds, current: _round, done: _scores.length, accent: _accent),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  _tr
                      ? 'Hangisi bu şeklin sadece DÖNDÜRÜLMÜŞ hali? Diğerleri aynada çevrilmiş.'
                      : 'Which one is just this shape ROTATED? The others are mirrored.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.nunito(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                flex: 2,
                child: Center(
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: CellsView(cells: _current.reference, color: const Color(0xFFFFC94D)),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Expanded(flex: 4, child: _buildOptions()),
              _buildBottom(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOptions() {
    Widget option(int i) {
      final picked = _picked != null;
      Color border = Colors.transparent;
      if (picked && i == _current.answer) border = _good;
      if (picked && i == _picked && i != _current.answer) border = _bad;
      return Expanded(
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: GestureDetector(
            onTap: () => _pick(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: border, width: 4),
              ),
              child: CellsView(cells: _current.options[i], color: _accent),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Column(
        children: [
          Expanded(child: Row(children: [option(0), option(1)])),
          Expanded(child: Row(children: [option(2), option(3)])),
        ],
      ),
    );
  }

  Widget _buildBottom() {
    final done = _picked != null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Column(
        children: [
          SizedBox(
            height: 24,
            child: done
                ? Text(
                    _correct.last
                        ? '${_tr ? 'Doğru!' : 'Correct!'} +${_scores.last.toStringAsFixed(0)}'
                        : (_tr ? 'O aynalanmıştı' : 'That one was mirrored'),
                    style: GoogleFonts.nunito(
                        fontSize: 16, fontWeight: FontWeight.w900, color: _correct.last ? _good : Colors.white70),
                  )
                : null,
          ),
          const SizedBox(height: 6),
          ChunkyButton(
            face: done ? _good : Colors.white24,
            lip: done ? const Color(0xFF1E9E55) : Colors.white10,
            height: 56,
            onTap: done ? _next : null,
            child: Text(
              _round + 1 >= RotatleGame.totalRounds ? (_tr ? 'SONUÇ' : 'RESULT') : (_tr ? 'SONRAKİ' : 'NEXT'),
              style: GoogleFonts.nunito(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
