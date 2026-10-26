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
import 'icele_game.dart';

class IceleScreen extends StatefulWidget {
  final bool isDailyMode;
  final void Function(double score, [int durationMs])? onGameComplete;
  const IceleScreen({super.key, this.isDailyMode = true, this.onGameComplete});

  @override
  State<IceleScreen> createState() => _IceleScreenState();
}

class _IceleScreenState extends State<IceleScreen> {
  static const Color _accent = Color(0xFF6FD6FF);
  static const Color _bg = Color(0xFF0E2236);

  late final IceleGame _game;
  final SoundService _sound = SoundService();
  final Stopwatch _stopwatch = Stopwatch()..start();

  int _round = 0;
  late int _pos;
  int _moves = 0;
  bool _locked = false;
  final List<double> _scores = [];

  bool get _tr => LanguageService().isTurkish;
  IcePuzzle get _puzzle => _game.puzzles[_round];
  double get _total => _scores.fold(0.0, (a, b) => a + b);

  @override
  void initState() {
    super.initState();
    _game = IceleGame(widget.isDailyMode ? Random(DailyChallengeService.getSeededSeed('icele')) : Random());
    _pos = _puzzle.start;
  }

  void _move(Slide dir) {
    if (_locked) return;
    final next = _puzzle.slide(_pos, dir);
    if (next == _pos) {
      _sound.playError();
      return;
    }
    _sound.playFlip();
    setState(() {
      _pos = next;
      _moves++;
    });
    if (_pos == _puzzle.goal) _solved();
  }

  void _solved() {
    _locked = true;
    _sound.playWin();
    final score = IceleGame.roundScore(_puzzle.par, _moves, solved: true);
    setState(() => _scores.add(score));
    Future.delayed(const Duration(milliseconds: 900), _nextRound);
  }

  void _giveUpRound() {
    if (_locked) return;
    _locked = true;
    _sound.playLose();
    setState(() => _scores.add(0));
    Future.delayed(const Duration(milliseconds: 400), _nextRound);
  }

  void _reset() {
    if (_locked || _moves == 0) return;
    _sound.playDelete();
    setState(() {
      _pos = _puzzle.start;
      _moves = 0;
    });
  }

  void _nextRound() {
    if (!mounted) return;
    if (_round + 1 >= IceleGame.totalRounds) {
      _finish();
      return;
    }
    setState(() {
      _round++;
      _pos = _puzzle.start;
      _moves = 0;
      _locked = false;
    });
  }

  void _finish() {
    _stopwatch.stop();
    final score = _total;
    reportGameScore(
      gameId: 'icele',
      isDailyMode: widget.isDailyMode,
      onGameComplete: widget.onGameComplete,
      score: score,
      durationMs: _stopwatch.elapsedMilliseconds,
      attempts: IceleGame.totalRounds,
      maxAttempts: IceleGame.totalRounds,
      isWin: score > 0,
    );
    final perfect = List.generate(_scores.length, (i) => _scores[i] >= IceleGame.maxRoundScore - 0.01).where((p) => p).length;
    GameResultSheet.show(
      context,
      GameResultSheet(
        title: perfect == IceleGame.totalRounds ? (_tr ? 'Buz pateni ustası!' : 'Ice master!') : (_tr ? 'Buz eridi' : 'Thawed out'),
        headline: score.toStringAsFixed(0),
        caption: _tr ? 'Puan (100 üzerinden)' : 'Score (out of 100)',
        accent: _accent,
        isDailyRun: widget.onGameComplete != null,
        stats: [
          GameResultStat(_tr ? 'Par\'da çözülen' : 'At par', '$perfect/${IceleGame.totalRounds}'),
          GameResultStat(_tr ? 'Süre' : 'Time', '${(_stopwatch.elapsedMilliseconds / 1000).round()}s'),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GameExitWrapper(
      gameId: 'icele',
      isDailyMode: widget.isDailyMode,
      onGameComplete: widget.onGameComplete,
      child: Scaffold(
        backgroundColor: _bg,
        body: SafeArea(
          child: Column(
            children: [
              GameTopBar(
                title: 'Icele',
                subtitle: _tr ? 'Kay, dur, hedefe ulaş' : 'Slide, stop, reach the flag',
                trailing: _total.toStringAsFixed(0),
                accent: _accent,
              ),
              RoundDots(total: IceleGame.totalRounds, current: _round, done: _scores.length, accent: _accent),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _counter(_tr ? 'Hamle' : 'Moves', '$_moves', _moves > _puzzle.par ? Colors.orangeAccent : Colors.white),
                  _counter('Par', '${_puzzle.par}', Colors.white),
                ],
              ),
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: GestureDetector(
                      onPanEnd: (d) {
                        final v = d.velocity.pixelsPerSecond;
                        if (v.distance < 150) return;
                        if (v.dx.abs() > v.dy.abs()) {
                          _move(v.dx > 0 ? Slide.right : Slide.left);
                        } else {
                          _move(v.dy > 0 ? Slide.down : Slide.up);
                        }
                      },
                      child: AspectRatio(aspectRatio: 1, child: _buildBoard()),
                    ),
                  ),
                ),
              ),
              Text(
                _tr ? 'Kaydırarak taşı it. Taş ancak bir engele çarpınca durur.' : 'Swipe to push. It only stops when it hits something.',
                textAlign: TextAlign.center,
                style: GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white54),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                child: Row(
                  children: [
                    Expanded(
                      child: ChunkyButton(
                        face: const Color(0xFF4F8BFF),
                        lip: const Color(0xFF2E5BC4),
                        height: 50,
                        onTap: _moves > 0 && !_locked ? _reset : null,
                        child: Text(_tr ? 'BAŞTAN' : 'RESET',
                            style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.white)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ChunkyButton(
                        face: const Color(0xFF5A6080),
                        lip: const Color(0xFF3A3F58),
                        height: 50,
                        onTap: _locked ? null : _giveUpRound,
                        child: Text(_tr ? 'GEÇ' : 'SKIP',
                            style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.white)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _counter(String label, String value, Color color) => Column(
        children: [
          Text(value, style: GoogleFonts.nunito(fontSize: 24, fontWeight: FontWeight.w900, color: color)),
          Text(label, style: GoogleFonts.nunito(fontSize: 12, color: Colors.white54)),
        ],
      );

  Widget _buildBoard() {
    final p = _puzzle;
    return LayoutBuilder(builder: (context, c) {
      final cell = c.maxWidth / p.size;
      Offset at(int i) => Offset((i % p.size) * cell, (i ~/ p.size) * cell);
      return Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFD9F4FF), Color(0xFF9FD8F2)],
          ),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Stack(
          children: [
            // Buz çizgileri
            for (var i = 0; i < p.size * p.size; i++)
              Positioned(
                left: at(i).dx,
                top: at(i).dy,
                width: cell,
                height: cell,
                child: Container(
                  decoration: BoxDecoration(border: Border.all(color: Colors.white.withValues(alpha: 0.45), width: 0.5)),
                ),
              ),
            // Hedef
            Positioned(
              left: at(p.goal).dx,
              top: at(p.goal).dy,
              width: cell,
              height: cell,
              child: Center(child: Icon(Icons.flag_rounded, color: const Color(0xFFFF5D73), size: cell * 0.7)),
            ),
            // Kayalar
            for (final r in p.rocks)
              Positioned(
                left: at(r).dx + cell * 0.06,
                top: at(r).dy + cell * 0.06,
                width: cell * 0.88,
                height: cell * 0.88,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF8A93A8), Color(0xFF545C70)],
                    ),
                    borderRadius: BorderRadius.circular(cell * 0.28),
                    boxShadow: const [BoxShadow(color: Color(0x55000000), offset: Offset(0, 3), blurRadius: 3)],
                  ),
                ),
              ),
            // Kayan taş
            AnimatedPositioned(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              left: at(_pos).dx + cell * 0.12,
              top: at(_pos).dy + cell * 0.12,
              width: cell * 0.76,
              height: cell * 0.76,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const RadialGradient(
                    center: Alignment(-0.3, -0.4),
                    colors: [Color(0xFF6FA8FF), Color(0xFF2A55C9)],
                  ),
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: const [BoxShadow(color: Color(0x66000000), offset: Offset(0, 4), blurRadius: 4)],
                ),
              ),
            ),
          ],
        ),
      );
    });
  }
}
