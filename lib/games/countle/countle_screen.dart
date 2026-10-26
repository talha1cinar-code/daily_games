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
import 'countle_game.dart';

class CountleScreen extends StatefulWidget {
  final bool isDailyMode;
  final void Function(double score, [int durationMs])? onGameComplete;
  const CountleScreen({super.key, this.isDailyMode = true, this.onGameComplete});

  @override
  State<CountleScreen> createState() => _CountleScreenState();
}

enum _Phase { ready, flash, input, reveal }

class _CountleScreenState extends State<CountleScreen> {
  static const Color _bg = Color(0xFF14122B);
  static const Color _accent = Color(0xFFFFC94D);
  static const Color _target = Color(0xFFFFC94D);
  static const Color _other = Color(0xFF5B8CFF);

  late final CountleGame _game;
  final SoundService _sound = SoundService();
  final Stopwatch _stopwatch = Stopwatch()..start();

  int _round = 0;
  _Phase _phase = _Phase.ready;
  String _typed = '';
  final List<double> _scores = [];
  final List<double> _errors = [];

  bool get _tr => LanguageService().isTurkish;
  CountRound get _current => _game.rounds[_round];
  double get _total => _scores.fold(0.0, (a, b) => a + b);

  @override
  void initState() {
    super.initState();
    _game = CountleGame(widget.isDailyMode ? Random(DailyChallengeService.getSeededSeed('countle')) : Random());
  }

  Future<void> _show() async {
    _sound.playGo();
    setState(() => _phase = _Phase.flash);
    await Future.delayed(Duration(milliseconds: _current.flashMs));
    if (!mounted) return;
    setState(() => _phase = _Phase.input);
  }

  void _key(String k) {
    _sound.playKeyTap();
    setState(() {
      if (k == '<') {
        if (_typed.isNotEmpty) _typed = _typed.substring(0, _typed.length - 1);
      } else if (_typed.length < 3) {
        _typed = (_typed + k).replaceFirst(RegExp(r'^0+(?=\d)'), '');
      }
    });
  }

  void _submit() {
    final guess = int.tryParse(_typed);
    if (guess == null) return;
    final actual = _current.answer;
    final score = CountleGame.roundScore(actual, guess);
    score >= 16 ? _sound.playCorrect() : (score > 0 ? _sound.playFlip() : _sound.playError());
    setState(() {
      _phase = _Phase.reveal;
      _scores.add(score);
      _errors.add((actual - guess).abs() / actual);
    });
  }

  void _next() {
    if (_round + 1 >= CountleGame.totalRounds) {
      _finish();
      return;
    }
    _sound.playKeyTap();
    setState(() {
      _round++;
      _typed = '';
      _phase = _Phase.ready;
    });
  }

  void _finish() {
    _stopwatch.stop();
    final score = _total;
    reportGameScore(
      gameId: 'countle',
      isDailyMode: widget.isDailyMode,
      onGameComplete: widget.onGameComplete,
      score: score,
      durationMs: _stopwatch.elapsedMilliseconds,
      attempts: CountleGame.totalRounds,
      maxAttempts: CountleGame.totalRounds,
    );
    final exact = _errors.where((e) => e == 0).length;
    final avg = _errors.reduce((a, b) => a + b) / _errors.length * 100;
    GameResultSheet.show(
      context,
      GameResultSheet(
        title: exact >= 3 ? (_tr ? 'Kartal gözü!' : 'Eagle eye!') : (_tr ? 'Sayım bitti' : 'Count complete'),
        headline: score.toStringAsFixed(0),
        caption: _tr ? 'Puan (100 üzerinden)' : 'Score (out of 100)',
        accent: _accent,
        isDailyRun: widget.onGameComplete != null,
        stats: [
          GameResultStat(_tr ? 'Tam isabet' : 'Exact', '$exact/${CountleGame.totalRounds}'),
          GameResultStat(_tr ? 'Ort. sapma' : 'Avg. miss', '%${avg.toStringAsFixed(0)}'),
        ],
      ),
    );
  }

  String get _instruction {
    if (_current.onlyTarget) {
      return _tr ? 'Yalnızca SARI noktaları say' : 'Count only the YELLOW dots';
    }
    return _tr ? 'Tüm noktaları say' : 'Count all the dots';
  }

  @override
  Widget build(BuildContext context) {
    return GameExitWrapper(
      gameId: 'countle',
      isDailyMode: widget.isDailyMode,
      onGameComplete: widget.onGameComplete,
      child: Scaffold(
        backgroundColor: _bg,
        body: SafeArea(
          child: Column(
            children: [
              GameTopBar(
                title: 'Countle',
                subtitle: _tr ? 'Bir anda say' : 'Count in a flash',
                trailing: _total.toStringAsFixed(0),
                accent: _accent,
              ),
              RoundDots(total: CountleGame.totalRounds, current: _round, done: _scores.length, accent: _accent),
              const SizedBox(height: 12),
              Text(
                _instruction,
                style: GoogleFonts.nunito(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  color: _current.onlyTarget ? _target : Colors.white,
                ),
              ),
              Text(
                '${(_current.flashMs / 1000).toStringAsFixed(1)} ${_tr ? 'saniye görünecek' : 'seconds on screen'}',
                style: GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white38),
              ),
              Expanded(
                child: Padding(padding: const EdgeInsets.fromLTRB(20, 12, 20, 12), child: _buildField()),
              ),
              // Alt panel her aşamada aynı yükseklikte: nokta alanı küçülüp büyümesin
              SizedBox(height: _bottomHeight, child: _buildBottom()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildField() {
    final visible = _phase == _Phase.flash || _phase == _Phase.reveal;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white10),
      ),
      child: LayoutBuilder(
        builder: (context, box) {
          final side = min(box.maxWidth, box.maxHeight);
          return Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: side,
                height: side,
                // Gizli aşamalarda hiç çizilmez; sönme animasyonu yeni turun noktalarını ele vermesin
                child: CustomPaint(
                  painter: _DotsPainter(
                    visible ? _current.dots : const [],
                    dimOthers: _phase == _Phase.reveal && _current.onlyTarget,
                  ),
                ),
              ),
              if (_phase == _Phase.ready)
                Icon(Icons.visibility_rounded, size: 64, color: Colors.white.withValues(alpha: 0.15)),
              if (_phase == _Phase.input)
                Text(
                  '?',
                  style: GoogleFonts.nunito(fontSize: 96, fontWeight: FontWeight.w900, color: Colors.white12),
                ),
            ],
          );
        },
      ),
    );
  }

  static const double _bottomHeight = 300;

  Widget _buildBottom() {
    switch (_phase) {
      case _Phase.ready:
      case _Phase.flash:
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              ChunkyButton(
                face: _accent,
                lip: const Color(0xFFC7922A),
                height: 56,
                onTap: _phase == _Phase.ready ? _show : null,
                child: Text(
                  _tr ? 'GÖSTER' : 'SHOW',
                  style: GoogleFonts.nunito(fontSize: 20, fontWeight: FontWeight.w900, color: _bg),
                ),
              ),
            ],
          ),
        );
      case _Phase.input:
        return _buildKeypad();
      case _Phase.reveal:
        final actual = _current.answer;
        final guess = int.parse(_typed);
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '$actual',
                    style: GoogleFonts.nunito(fontSize: 40, fontWeight: FontWeight.w900, color: _accent),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    '${_tr ? 'Senin' : 'You'}: $guess',
                    style: GoogleFonts.nunito(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white70),
                  ),
                ],
              ),
              Text(
                guess == actual
                    ? (_tr ? 'Tam isabet! +20' : 'Spot on! +20')
                    : '${(guess - actual).abs()} ${_tr ? 'fark' : 'off'} · +${_scores.last.toStringAsFixed(0)}',
                style: GoogleFonts.nunito(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white60),
              ),
              const SizedBox(height: 14),
              ChunkyButton(
                face: _accent,
                lip: const Color(0xFFC7922A),
                height: 56,
                onTap: _next,
                child: Text(
                  _round + 1 >= CountleGame.totalRounds ? (_tr ? 'SONUÇ' : 'RESULT') : (_tr ? 'SONRAKİ' : 'NEXT'),
                  style: GoogleFonts.nunito(fontSize: 20, fontWeight: FontWeight.w900, color: _bg),
                ),
              ),
            ],
          ),
        );
    }
  }

  Widget _buildKeypad() {
    Widget key(String k, {Widget? child, Color? color}) => Expanded(
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Material(
          color: color ?? Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => k == 'ok' ? _submit() : _key(k),
            child: SizedBox.expand(
              child: Center(
                child:
                    child ??
                    Text(
                      k,
                      style: GoogleFonts.nunito(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white),
                    ),
              ),
            ),
          ),
        ),
      ),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        children: [
          Text(
            _typed.isEmpty ? (_tr ? 'Kaç tane?' : 'How many?') : _typed,
            maxLines: 1,
            style: GoogleFonts.nunito(
              fontSize: _typed.isEmpty ? 24 : 34,
              fontWeight: FontWeight.w900,
              color: _typed.isEmpty ? Colors.white38 : Colors.white,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 6),
          for (final row in const [
            ['1', '2', '3'],
            ['4', '5', '6'],
            ['7', '8', '9'],
          ])
            Expanded(child: Row(children: [for (final k in row) key(k)])),
          Expanded(
            child: Row(
              children: [
                key('<', child: const Icon(Icons.backspace_rounded, color: Colors.white70)),
                key('0'),
                key(
                  'ok',
                  color: _typed.isEmpty ? Colors.white12 : _accent,
                  child: Icon(Icons.check_rounded, size: 28, color: _typed.isEmpty ? Colors.white38 : _bg),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DotsPainter extends CustomPainter {
  final List<CountDot> dots;
  final bool dimOthers;

  _DotsPainter(this.dots, {required this.dimOthers});

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    for (final d in dots) {
      final color = d.color == 0 ? _CountleScreenState._target : _CountleScreenState._other;
      canvas.drawCircle(
        Offset(d.x * size.width, d.y * size.height),
        d.r * s,
        Paint()..color = d.color == 1 && dimOthers ? color.withValues(alpha: 0.25) : color,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _DotsPainter old) => old.dots != dots || old.dimOthers != dimOthers;
}
