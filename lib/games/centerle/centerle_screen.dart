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
import 'centerle_game.dart';

class CenterleScreen extends StatefulWidget {
  final bool isDailyMode;
  final void Function(double score, [int durationMs])? onGameComplete;
  const CenterleScreen({super.key, this.isDailyMode = true, this.onGameComplete});

  @override
  State<CenterleScreen> createState() => _CenterleScreenState();
}

class _CenterleScreenState extends State<CenterleScreen> {
  static const Color _bg = Color(0xFF0E1A24);
  static const Color _accent = Color(0xFFFF7A59);
  static const Color _guessColor = Color(0xFF7CF5C4);

  late final CenterleGame _game;
  final SoundService _sound = SoundService();
  final Stopwatch _stopwatch = Stopwatch()..start();

  int _round = 0;
  Point<double>? _guess;
  bool _revealed = false;
  final List<double> _scores = [];
  final List<double> _misses = [];

  bool get _tr => LanguageService().isTurkish;
  CenterRound get _current => _game.rounds[_round];
  double get _total => _scores.fold(0.0, (a, b) => a + b);

  @override
  void initState() {
    super.initState();
    _game = CenterleGame(widget.isDailyMode ? Random(DailyChallengeService.getSeededSeed('centerle')) : Random());
  }

  void _place(Offset local, double side) {
    if (_revealed) return;
    final p = Point((local.dx / side).clamp(0.0, 1.0), (local.dy / side).clamp(0.0, 1.0));
    setState(() => _guess = p);
  }

  void _submit() {
    if (_guess == null) return;
    final score = CenterleGame.roundScore(_current.center, _guess!);
    score >= 16 ? _sound.playCorrect() : (score > 0 ? _sound.playFlip() : _sound.playError());
    setState(() {
      _revealed = true;
      _scores.add(score);
      _misses.add(_current.center.distanceTo(_guess!));
    });
  }

  void _next() {
    if (_round + 1 >= CenterleGame.totalRounds) {
      _finish();
      return;
    }
    _sound.playKeyTap();
    setState(() {
      _round++;
      _guess = null;
      _revealed = false;
    });
  }

  void _finish() {
    _stopwatch.stop();
    final score = _total;
    reportGameScore(
      gameId: 'centerle',
      isDailyMode: widget.isDailyMode,
      onGameComplete: widget.onGameComplete,
      score: score,
      durationMs: _stopwatch.elapsedMilliseconds,
      attempts: CenterleGame.totalRounds,
      maxAttempts: CenterleGame.totalRounds,
    );
    final best = _misses.reduce(min) * 100;
    GameResultSheet.show(
      context,
      GameResultSheet(
        title: score >= 80 ? (_tr ? 'Pergel gibi!' : 'Compass-precise!') : (_tr ? 'Merkezler tamam' : 'Centres done'),
        headline: score.toStringAsFixed(0),
        caption: _tr ? 'Puan (100 üzerinden)' : 'Score (out of 100)',
        accent: _accent,
        isDailyRun: widget.onGameComplete != null,
        stats: [
          GameResultStat(_tr ? 'En yakın' : 'Closest', '%${best.toStringAsFixed(1)}'),
          GameResultStat(_tr ? 'Tur' : 'Rounds', '${CenterleGame.totalRounds}'),
        ],
      ),
    );
  }

  String get _instruction {
    switch (_current.type) {
      case CenterType.segment:
        return _tr ? 'Çizginin tam ortasına dokun' : 'Tap the exact middle of the line';
      case CenterType.circle:
        return _tr ? 'Çemberin merkezine dokun' : 'Tap the centre of the circle';
      case CenterType.square:
        return _tr ? 'Karenin merkezine dokun' : 'Tap the centre of the square';
      case CenterType.arc:
        return _tr ? 'Bu yay hangi çemberin parçası? Merkezini bul' : 'This arc belongs to a circle: find its centre';
      case CenterType.threePoints:
        return _tr ? 'Üç noktadan geçen çemberin merkezi nerede?' : 'Where is the centre of the circle through all 3 dots?';
    }
  }

  @override
  Widget build(BuildContext context) {
    return GameExitWrapper(
      gameId: 'centerle',
      isDailyMode: widget.isDailyMode,
      onGameComplete: widget.onGameComplete,
      child: Scaffold(
        backgroundColor: _bg,
        body: SafeArea(
          child: Column(
            children: [
              GameTopBar(
                title: 'Centerle',
                subtitle: _tr ? 'Tam merkezi bul' : 'Find the exact centre',
                trailing: _total.toStringAsFixed(0),
                accent: _accent,
              ),
              RoundDots(total: CenterleGame.totalRounds, current: _round, done: _scores.length, accent: _accent),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  _instruction,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.nunito(fontSize: 17, fontWeight: FontWeight.w900, color: Colors.white),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Center(
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: LayoutBuilder(builder: (context, box) {
                        final side = box.maxWidth;
                        return GestureDetector(
                          onTapDown: (d) => _place(d.localPosition, side),
                          onPanUpdate: (d) => _place(d.localPosition, side),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.04),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: CustomPaint(
                              size: Size.square(side),
                              painter: _CenterPainter(
                                round: _current,
                                guess: _guess,
                                revealed: _revealed,
                                accent: _accent,
                                guessColor: _guessColor,
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                ),
              ),
              _revealed ? _buildResult() : _buildConfirm(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConfirm() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        children: [
          Text(
            _guess == null
                ? (_tr ? 'Dokun, gerekirse sürükleyerek düzelt' : 'Tap, then drag to fine-tune')
                : (_tr ? 'Emin misin?' : 'Sure?'),
            style: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white54),
          ),
          const SizedBox(height: 10),
          ChunkyButton(
            face: _accent,
            lip: const Color(0xFFC0502F),
            height: 56,
            onTap: _guess == null ? null : _submit,
            child: Text(_tr ? 'ONAYLA' : 'CONFIRM',
                style: GoogleFonts.nunito(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildResult() {
    final miss = _misses.last * 100;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        children: [
          Text(
            miss < 0.6
                ? (_tr ? 'Tam merkez! +20' : 'Dead centre! +20')
                : '${_tr ? 'Sapma' : 'Miss'} %${miss.toStringAsFixed(1)} · +${_scores.last.toStringAsFixed(0)}',
            style: GoogleFonts.nunito(fontSize: 17, fontWeight: FontWeight.w900, color: Colors.white),
          ),
          const SizedBox(height: 10),
          ChunkyButton(
            face: _guessColor,
            lip: const Color(0xFF2FA07A),
            height: 56,
            onTap: _next,
            child: Text(
              _round + 1 >= CenterleGame.totalRounds ? (_tr ? 'SONUÇ' : 'RESULT') : (_tr ? 'SONRAKİ' : 'NEXT'),
              style: GoogleFonts.nunito(fontSize: 20, fontWeight: FontWeight.w900, color: _bg),
            ),
          ),
        ],
      ),
    );
  }
}

class _CenterPainter extends CustomPainter {
  final CenterRound round;
  final Point<double>? guess;
  final bool revealed;
  final Color accent;
  final Color guessColor;

  _CenterPainter({
    required this.round,
    required this.guess,
    required this.revealed,
    required this.accent,
    required this.guessColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    Offset o(Point<double> p) => Offset(p.x * s, p.y * s);
    final line = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    final dot = Paint()..color = Colors.white;

    switch (round.type) {
      case CenterType.segment:
        canvas.drawLine(o(round.points[0]), o(round.points[1]), line);
      case CenterType.circle:
        canvas.drawCircle(o(round.center), round.radius * s, line);
      case CenterType.square:
        canvas.drawPath(Path()..addPolygon([for (final p in round.points) o(p)], true), line..strokeJoin = StrokeJoin.round);
      case CenterType.arc:
        canvas.drawArc(Rect.fromCircle(center: o(round.center), radius: round.radius * s), round.arcStart, round.arcSweep,
            false, line);
      case CenterType.threePoints:
        for (final p in round.points) {
          canvas.drawCircle(o(p), 8, dot);
        }
    }

    if (revealed) {
      // Gerçek merkez ve (gerekirse) tam şekil
      final ghost = Paint()
        ..color = accent.withValues(alpha: 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      if (round.type == CenterType.arc || round.type == CenterType.threePoints) {
        canvas.drawCircle(o(round.center), round.radius * s, ghost);
      }
      if (guess != null) {
        canvas.drawLine(o(round.center), o(guess!), Paint()
          ..color = Colors.white38
          ..strokeWidth = 2);
      }
      canvas.drawCircle(o(round.center), 9, Paint()..color = accent);
    }

    if (guess != null) {
      final g = o(guess!);
      final p = Paint()
        ..color = guessColor
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(g - const Offset(14, 0), g + const Offset(14, 0), p);
      canvas.drawLine(g - const Offset(0, 14), g + const Offset(0, 14), p);
      canvas.drawCircle(g, 5, Paint()..color = guessColor);
    }
  }

  @override
  bool shouldRepaint(covariant _CenterPainter old) => true;
}
