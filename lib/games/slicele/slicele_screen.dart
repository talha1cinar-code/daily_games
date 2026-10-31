import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../widgets/game_exit_wrapper.dart';
import '../../widgets/game_result_sheet.dart';
import '../../services/sound_service.dart';
import '../../services/ticket_service.dart';
import '../../services/stats_service.dart';
import '../../services/leaderboard_service.dart';
import '../../services/personal_best_service.dart';
import '../../services/daily_challenge_service.dart';
import '../../services/language_service.dart';
import 'slicele_game.dart';

class SliceleScreen extends StatefulWidget {
  final bool isDailyMode;
  final void Function(double score, [int durationMs])? onGameComplete;
  const SliceleScreen({super.key, this.isDailyMode = true, this.onGameComplete});

  @override
  State<SliceleScreen> createState() => _SliceleScreenState();
}

class _SliceleScreenState extends State<SliceleScreen> with TickerProviderStateMixin {
  static const Color _accent = Color(0xFFFF7A59);
  static const Color _bg = Color(0xFF17131C);

  late final SliceleGame _game;
  final SoundService _sound = SoundService();
  final Stopwatch _stopwatch = Stopwatch()..start();

  int _round = 0;
  final List<double> _roundScores = [];
  final List<double> _roundPercents = [];

  // Dönen şekil
  late final Ticker _ticker;
  double _theta = 0;
  Duration _lastTick = Duration.zero;

  // Kesim
  Offset? _dragStart;
  Offset? _dragEnd;
  SliceResult? _result;
  Offset? _cutA, _cutB; // şekil koordinatlarında
  late final AnimationController _split;
  String? _hint;

  bool get _tr => LanguageService().isTurkish;
  SliceleRound get _current => _game.rounds[_round];
  double get _total => _roundScores.fold(0.0, (a, b) => a + b);

  @override
  void initState() {
    super.initState();
    final rng = widget.isDailyMode
        ? Random(DailyChallengeService.getSeededSliceleSeed())
        : Random();
    _game = SliceleGame(rng);
    _split = AnimationController(vsync: this, duration: const Duration(milliseconds: 450));
    _ticker = createTicker(_onTick)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _split.dispose();
    super.dispose();
  }

  void _onTick(Duration elapsed) {
    final dt = (elapsed - _lastTick).inMicroseconds / 1e6;
    _lastTick = elapsed;
    if (_current.spin == 0 || _result != null) return;
    setState(() => _theta += _current.spin * dt);
  }

  // Ekran → şekil koordinatı
  Offset _toShape(Offset p, Size size) {
    final c = size.center(Offset.zero);
    final k = size.shortestSide * 0.4;
    final v = (p - c) / k;
    final cosT = cos(-_theta), sinT = sin(-_theta);
    return Offset(v.dx * cosT - v.dy * sinT, v.dx * sinT + v.dy * cosT);
  }

  void _onPanEnd(Size size) {
    final a = _dragStart, b = _dragEnd;
    if (a == null || b == null || _result != null) return;
    final minLen = size.shortestSide * 0.25;
    if ((b - a).distance < minLen) {
      setState(() {
        _dragStart = _dragEnd = null;
        _hint = _tr ? 'Daha uzun bir çizgi çek' : 'Swipe a longer line';
      });
      return;
    }
    final sa = _toShape(a, size), sb = _toShape(b, size);
    final res = SliceleGame.slice(_current.shape, sa, sb);
    if (res == null) {
      _sound.playError();
      setState(() {
        _dragStart = _dragEnd = null;
        _hint = _tr ? 'Çizgi şeklin içinden geçmeli' : 'The line must cross the shape';
      });
      return;
    }
    final score = SliceleGame.roundScore(res.smallerPercent, _current.targetPercent);
    score >= 16 ? _sound.playCorrect() : _sound.playFlip();
    setState(() {
      _result = res;
      _cutA = sa;
      _cutB = sb;
      _hint = null;
      _roundScores.add(score);
      _roundPercents.add(res.smallerPercent);
    });
    _split.forward(from: 0);
  }

  void _next() {
    if (_round + 1 >= SliceleGame.totalRounds) {
      _finish();
      return;
    }
    _sound.playKeyTap();
    setState(() {
      _round++;
      _result = null;
      _dragStart = _dragEnd = null;
      _cutA = _cutB = null;
      _theta = 0;
    });
  }

  void _finish() {
    _stopwatch.stop();
    final durationMs = _stopwatch.elapsedMilliseconds;
    final score = _total;
    _sound.playGameEnd(score);
    _saveScore(score, durationMs);
    final avgDiff = List.generate(
          _roundPercents.length,
          (i) => (_roundPercents[i] - _game.rounds[i].targetPercent).abs(),
        ).fold(0.0, (a, b) => a + b) /
        _roundPercents.length;
    GameResultSheet.show(
      context,
      GameResultSheet(
        title: avgDiff < 2
            ? (_tr ? 'Cerrah hassasiyeti!' : 'Surgical precision!')
            : (_tr ? 'Kesim tamam' : 'All sliced'),
        headline: score.toStringAsFixed(0),
        caption: _tr ? 'Puan (100 üzerinden)' : 'Score (out of 100)',
        accent: _accent,
        isDailyRun: widget.onGameComplete != null,
        stats: [
          GameResultStat(_tr ? 'Ort. sapma' : 'Avg. miss', '%${avgDiff.toStringAsFixed(1)}'),
          GameResultStat(_tr ? 'En iyi tur' : 'Best round', _roundScores.reduce(max).toStringAsFixed(0)),
          GameResultStat(_tr ? 'Tur' : 'Rounds', '${SliceleGame.totalRounds}'),
        ],
      ),
    );
  }

  void _saveScore(double score, int durationMs) {
    if (widget.onGameComplete != null) {
      widget.onGameComplete!(score, durationMs);
    } else if (widget.isDailyMode) {
      TicketService().markDailyPlayed('slicele');
      StatsService().saveDailyStat(
        gameId: 'slicele',
        isWin: true,
        score: score,
        attempts: SliceleGame.totalRounds,
        maxAttempts: SliceleGame.totalRounds,
        durationMs: durationMs,
      );
      LeaderboardService().submitScore(
        gameId: 'slicele',
        score: score,
        attempts: SliceleGame.totalRounds,
        maxAttempts: SliceleGame.totalRounds,
        durationMs: durationMs,
        isWin: true,
      );
    } else {
      PersonalBestService().submit('slicele', score);
    }
  }

  String _goalText() {
    final t = _current.targetPercent;
    if (t == 50) {
      return _current.spin != 0
          ? (_tr ? 'Dönerken tam ortadan kes' : 'Cut it in half while it spins')
          : (_tr ? 'Tam ortadan ikiye kes' : 'Cut it exactly in half');
    }
    return _tr ? '%${t.toStringAsFixed(0)}\'lik bir parça kes' : 'Cut off a ${t.toStringAsFixed(0)}% piece';
  }

  @override
  Widget build(BuildContext context) {
    return GameExitWrapper(
      gameId: 'slicele',
      isDailyMode: widget.isDailyMode,
      onGameComplete: widget.onGameComplete,
      child: Scaffold(
        backgroundColor: _bg,
        body: SafeArea(
          child: Column(
            children: [
              _buildTopBar(),
              _buildRoundDots(),
              const SizedBox(height: 16),
              Text(
                _goalText(),
                style: GoogleFonts.nunito(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white),
              ),
              const SizedBox(height: 4),
              SizedBox(
                height: 20,
                child: Text(
                  _hint ?? (_result == null ? (_tr ? 'Parmağını şeklin üzerinden kaydır' : 'Swipe across the shape') : ''),
                  style: GoogleFonts.nunito(fontSize: 14, color: _hint != null ? Colors.orangeAccent : Colors.white54),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: LayoutBuilder(builder: (context, constraints) {
                    final size = Size(constraints.maxWidth, constraints.maxHeight);
                    return GestureDetector(
                      onPanStart: (d) {
                        if (_result != null) return;
                        setState(() {
                          _dragStart = d.localPosition;
                          _dragEnd = d.localPosition;
                          _hint = null;
                        });
                      },
                      onPanUpdate: (d) {
                        if (_result != null) return;
                        setState(() => _dragEnd = d.localPosition);
                      },
                      onPanEnd: (_) => _onPanEnd(size),
                      child: AnimatedBuilder(
                        animation: _split,
                        builder: (context, _) => CustomPaint(
                          size: size,
                          painter: _SlicePainter(
                            shape: _current.shape,
                            theta: _theta,
                            dragStart: _dragStart,
                            dragEnd: _dragEnd,
                            result: _result,
                            cutA: _cutA,
                            cutB: _cutB,
                            split: Curves.easeOutBack.transform(_split.value),
                            accent: _accent,
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
              _buildBottom(),
            ],
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
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white70, size: 20),
            ),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Slicele',
                  style: GoogleFonts.nunito(fontSize: 24, fontWeight: FontWeight.w800, color: Colors.white)),
              Text(_tr ? 'Tek kesim, tam isabet' : 'One cut, dead on',
                  style: GoogleFonts.nunito(fontSize: 12, color: Colors.white54)),
            ],
          ),
          const Spacer(),
          Text(
            _total.toStringAsFixed(0),
            style: GoogleFonts.nunito(fontSize: 22, fontWeight: FontWeight.w900, color: _accent),
          ),
        ],
      ),
    );
  }

  Widget _buildRoundDots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(SliceleGame.totalRounds, (i) {
        final done = i < _roundScores.length;
        final current = i == _round;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: current ? 28 : 10,
          height: 10,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: done ? _accent : (current ? Colors.white : Colors.white24),
            borderRadius: BorderRadius.circular(5),
          ),
        );
      }),
    );
  }

  Widget _buildBottom() {
    final res = _result;
    return SizedBox(
      height: 120,
      child: res == null
          ? null
          : Column(
              children: [
                Text(
                  '${res.smallerPercent.toStringAsFixed(1)}%  /  ${(100 - res.smallerPercent).toStringAsFixed(1)}%',
                  style: GoogleFonts.nunito(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white),
                ),
                Text(
                  '+${_roundScores.last.toStringAsFixed(0)} ${_tr ? 'puan' : 'pts'}',
                  style: GoogleFonts.nunito(fontSize: 15, fontWeight: FontWeight.w700, color: _accent),
                ),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _next,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _accent,
                        foregroundColor: _bg,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      child: Text(
                        _round + 1 >= SliceleGame.totalRounds
                            ? (_tr ? 'Sonucu gör' : 'See result')
                            : (_tr ? 'Sonraki şekil' : 'Next shape'),
                        style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _SlicePainter extends CustomPainter {
  final List<Offset> shape;
  final double theta;
  final Offset? dragStart, dragEnd;
  final SliceResult? result;
  final Offset? cutA, cutB;
  final double split;
  final Color accent;

  _SlicePainter({
    required this.shape,
    required this.theta,
    required this.dragStart,
    required this.dragEnd,
    required this.result,
    required this.cutA,
    required this.cutB,
    required this.split,
    required this.accent,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final k = size.shortestSide * 0.4;

    Offset toScreen(Offset p) {
      final x = p.dx * cos(theta) - p.dy * sin(theta);
      final y = p.dx * sin(theta) + p.dy * cos(theta);
      return c + Offset(x, y) * k;
    }

    Path pathOf(List<Offset> poly, Offset shift) {
      final path = Path();
      for (var i = 0; i < poly.length; i++) {
        final p = toScreen(poly[i]) + shift;
        i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
      }
      return path..close();
    }

    final res = result;
    if (res == null) {
      final path = pathOf(shape, Offset.zero);
      canvas.drawShadow(path, Colors.black, 8, false);
      canvas.drawPath(
        path,
        Paint()
          ..shader = LinearGradient(
            colors: [accent, const Color(0xFFFFB86B)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ).createShader(Rect.fromCircle(center: c, radius: k)),
      );
      if (dragStart != null && dragEnd != null) {
        canvas.drawLine(
          dragStart!,
          dragEnd!,
          Paint()
            ..color = Colors.white
            ..strokeWidth = 3
            ..strokeCap = StrokeCap.round,
        );
      }
      return;
    }

    // Kesimden sonra parçaları normal yönünde ayır
    final dir = (cutB! - cutA!);
    final normal = Offset(-dir.dy, dir.dx) / dir.distance;
    final nScreen = toScreen(normal) - toScreen(Offset.zero);
    final shift = nScreen / nScreen.distance * 14 * split;
    final smallerIsA = res.percentA <= 50;

    void piece(List<Offset> poly, Offset s, bool highlight, double pct) {
      final path = pathOf(poly, s);
      canvas.drawPath(
        path,
        Paint()..color = highlight ? accent : const Color(0xFF8E7F99),
      );
      final tp = TextPainter(
        text: TextSpan(
          text: '${pct.toStringAsFixed(1)}%',
          style: GoogleFonts.nunito(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final at = toScreen(SliceleGame.centroid(poly)) + s;
      tp.paint(canvas, at - Offset(tp.width / 2, tp.height / 2));
    }

    piece(res.pieceA, shift, smallerIsA, res.percentA);
    piece(res.pieceB, -shift, !smallerIsA, 100 - res.percentA);

    // Kesim çizgisi (uzatılmış)
    final a = toScreen(cutA!), b = toScreen(cutB!);
    final d = (b - a) / (b - a).distance * size.longestSide;
    canvas.drawLine(
      a - d,
      a + d,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.35 * (1 - split.clamp(0.0, 1.0)) + 0.1)
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(covariant _SlicePainter old) => true;
}
