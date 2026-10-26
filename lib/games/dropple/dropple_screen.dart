import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../widgets/game_exit_wrapper.dart';
import '../../widgets/game_result_sheet.dart';
import '../../widgets/chunky_button.dart';
import '../../services/sound_service.dart';
import '../../services/daily_challenge_service.dart';
import '../../services/language_service.dart';
import '../common/game_common.dart';
import 'dropple_game.dart';

class DroppleScreen extends StatefulWidget {
  final bool isDailyMode;
  final void Function(double score, [int durationMs])? onGameComplete;
  const DroppleScreen({super.key, this.isDailyMode = true, this.onGameComplete});

  @override
  State<DroppleScreen> createState() => _DroppleScreenState();
}

enum _Phase { aim, flying, landed }

class _DroppleScreenState extends State<DroppleScreen> with SingleTickerProviderStateMixin {
  static const Color _accent = Color(0xFFFFB627);
  static const Color _bg = Color(0xFF14102A);

  late final DroppleGame _game;
  late final Ticker _ticker;
  final SoundService _sound = SoundService();
  final Stopwatch _stopwatch = Stopwatch()..start();

  int _round = 0;
  _Phase _phase = _Phase.aim;
  double? _guess;
  int _pathIndex = 0;
  final List<double> _scores = [];
  final List<double> _misses = [];

  bool get _tr => LanguageService().isTurkish;
  DropRound get _current => _game.rounds[_round];
  double get _total => _scores.fold(0.0, (a, b) => a + b);

  @override
  void initState() {
    super.initState();
    _game = DroppleGame(widget.isDailyMode ? Random(DailyChallengeService.getSeededSeed('dropple')) : Random());
    _ticker = createTicker(_onTick);
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _onTick(Duration elapsed) {
    // Yol noktaları 4/300 saniye aralıklı; gerçek zamanlı oynat
    final idx = (elapsed.inMicroseconds / 1e6 * 75).floor();
    if (idx >= _current.path.length - 1) {
      _ticker.stop();
      _land();
      return;
    }
    setState(() => _pathIndex = idx);
  }

  void _setGuess(double x) {
    if (_phase != _Phase.aim) return;
    setState(() => _guess = x.clamp(0.03, 0.97));
  }

  void _drop() {
    if (_guess == null || _phase != _Phase.aim) return;
    _sound.playKeyTap();
    setState(() {
      _phase = _Phase.flying;
      _pathIndex = 0;
    });
    _ticker.start();
  }

  void _land() {
    final score = DroppleGame.roundScore(_current.landingX, _guess!);
    score >= 16 ? _sound.playCorrect() : _sound.playFlip();
    setState(() {
      _pathIndex = _current.path.length - 1;
      _phase = _Phase.landed;
      _scores.add(score);
      _misses.add((_current.landingX - _guess!).abs());
    });
  }

  void _next() {
    if (_round + 1 >= DroppleGame.totalRounds) {
      _finish();
      return;
    }
    _sound.playKeyTap();
    setState(() {
      _round++;
      _phase = _Phase.aim;
      _guess = null;
      _pathIndex = 0;
    });
  }

  void _finish() {
    _stopwatch.stop();
    final score = _total;
    reportGameScore(
      gameId: 'dropple',
      isDailyMode: widget.isDailyMode,
      onGameComplete: widget.onGameComplete,
      score: score,
      durationMs: _stopwatch.elapsedMilliseconds,
      attempts: DroppleGame.totalRounds,
      maxAttempts: DroppleGame.totalRounds,
    );
    final avg = _misses.reduce((a, b) => a + b) / _misses.length * 100;
    GameResultSheet.show(
      context,
      GameResultSheet(
        title: avg < 4 ? (_tr ? 'Fizik dehası!' : 'Physics genius!') : (_tr ? 'Top yere indi' : 'Touchdown'),
        headline: score.toStringAsFixed(0),
        caption: _tr ? 'Puan (100 üzerinden)' : 'Score (out of 100)',
        accent: _accent,
        isDailyRun: widget.onGameComplete != null,
        stats: [
          GameResultStat(_tr ? 'Ort. sapma' : 'Avg. miss', '%${avg.toStringAsFixed(1)}'),
          GameResultStat(_tr ? 'En iyi tur' : 'Best round', _scores.reduce(max).toStringAsFixed(0)),
          GameResultStat(_tr ? 'Tur' : 'Rounds', '${DroppleGame.totalRounds}'),
        ],
      ),
    );
  }

  String get _hint {
    switch (_phase) {
      case _Phase.aim:
        return _guess == null
            ? (_tr ? 'Topun düşeceği yere dokun' : 'Tap where the ball will land')
            : (_tr ? 'Hazırsan bırak!' : 'Ready? Drop it!');
      case _Phase.flying:
        return '...';
      case _Phase.landed:
        final miss = (_misses.last * 100).toStringAsFixed(1);
        return _tr ? '%$miss sapma · +${_scores.last.toStringAsFixed(0)}' : '$miss% off · +${_scores.last.toStringAsFixed(0)}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return GameExitWrapper(
      gameId: 'dropple',
      isDailyMode: widget.isDailyMode,
      onGameComplete: widget.onGameComplete,
      child: Scaffold(
        backgroundColor: _bg,
        body: SafeArea(
          child: Column(
            children: [
              GameTopBar(
                title: 'Dropple',
                subtitle: _tr ? 'Top nereye düşecek?' : 'Where will it land?',
                trailing: _total.toStringAsFixed(0),
                accent: _accent,
              ),
              RoundDots(total: DroppleGame.totalRounds, current: _round, done: _scores.length, accent: _accent),
              const SizedBox(height: 8),
              Expanded(
                child: LayoutBuilder(builder: (context, c) {
                  final w = min(c.maxWidth - 32, c.maxHeight / DroppleGame.worldHeight);
                  final h = w * DroppleGame.worldHeight;
                  return Center(
                    child: GestureDetector(
                      onTapDown: (d) => _setGuess(d.localPosition.dx / w),
                      onHorizontalDragUpdate: (d) => _setGuess(d.localPosition.dx / w),
                      child: CustomPaint(
                        size: Size(w, h),
                        painter: _DropPainter(
                          round: _current,
                          guess: _guess,
                          ball: _phase == _Phase.aim ? null : _current.path[_pathIndex],
                          showActual: _phase == _Phase.landed,
                          accent: _accent,
                        ),
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 10),
              Text(_hint,
                  style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white70)),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
                child: _phase == _Phase.landed
                    ? ChunkyButton(
                        face: _accent,
                        lip: const Color(0xFFC77F00),
                        height: 56,
                        onTap: _next,
                        child: Text(
                          _round + 1 >= DroppleGame.totalRounds ? (_tr ? 'SONUÇ' : 'RESULT') : (_tr ? 'SONRAKİ' : 'NEXT'),
                          style: GoogleFonts.nunito(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white),
                        ),
                      )
                    : ChunkyButton(
                        face: const Color(0xFF3DDC84),
                        lip: const Color(0xFF1E9E55),
                        height: 56,
                        onTap: _guess != null && _phase == _Phase.aim ? _drop : null,
                        child: Text(_tr ? 'BIRAK' : 'DROP',
                            style: GoogleFonts.nunito(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white)),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DropPainter extends CustomPainter {
  final DropRound round;
  final double? guess;
  final Offset? ball;
  final bool showActual;
  final Color accent;

  _DropPainter({required this.round, required this.guess, required this.ball, required this.showActual, required this.accent});

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    Offset w(Offset p) => p * s;
    final rect = Offset.zero & size;

    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(20)),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF2B2160), Color(0xFF1B1640)],
        ).createShader(rect),
    );

    // Zemin
    final floor = DroppleGame.floorY * s;
    canvas.drawRRect(
      RRect.fromRectAndCorners(Rect.fromLTRB(0, floor, s, size.height),
          bottomLeft: const Radius.circular(20), bottomRight: const Radius.circular(20)),
      Paint()..color = const Color(0xFF3DDC84),
    );
    canvas.drawRect(Rect.fromLTRB(0, floor, s, floor + 4), Paint()..color = const Color(0xFF8BF0B5));

    // Rampalar
    for (final (a, b) in round.ramps) {
      canvas.drawLine(
        w(a),
        w(b),
        Paint()
          ..color = const Color(0xFFB9A8FF)
          ..strokeWidth = s * 0.02
          ..strokeCap = StrokeCap.round,
      );
    }

    // Fırlatıcı ve hız oku
    final l = w(round.launch);
    final dir = round.velocity / round.velocity.distance;
    final arrowEnd = l + dir * (round.velocity.distance * 0.12 * s);
    canvas.drawLine(
      l,
      arrowEnd,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.85)
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round,
    );
    final perp = Offset(-dir.dy, dir.dx);
    final head = Path()
      ..moveTo(arrowEnd.dx + dir.dx * 10, arrowEnd.dy + dir.dy * 10)
      ..lineTo(arrowEnd.dx + perp.dx * 7, arrowEnd.dy + perp.dy * 7)
      ..lineTo(arrowEnd.dx - perp.dx * 7, arrowEnd.dy - perp.dy * 7)
      ..close();
    canvas.drawPath(head, Paint()..color = Colors.white.withValues(alpha: 0.85));
    canvas.drawCircle(l, s * 0.04, Paint()..color = const Color(0xFF5A4FB0));

    // Tahmin işareti
    if (guess != null) {
      final gx = guess! * s;
      final dash = Paint()
        ..color = accent.withValues(alpha: 0.6)
        ..strokeWidth = 2;
      for (var y = floor - s * 0.5; y < floor; y += 12) {
        canvas.drawLine(Offset(gx, y), Offset(gx, y + 6), dash);
      }
      final tri = Path()
        ..moveTo(gx, floor)
        ..lineTo(gx - 10, floor - 16)
        ..lineTo(gx + 10, floor - 16)
        ..close();
      canvas.drawPath(tri, Paint()..color = accent);
    }

    // Gerçek iniş
    if (showActual) {
      final ax = round.landingX * s;
      canvas.drawCircle(Offset(ax, floor + 10), 7, Paint()..color = const Color(0xFFFF5D73));
      if (guess != null) {
        canvas.drawLine(
          Offset(guess! * s, floor + 10),
          Offset(ax, floor + 10),
          Paint()
            ..color = Colors.white
            ..strokeWidth = 2,
        );
      }
    }

    // Top
    if (ball != null) {
      canvas.drawCircle(
        w(ball!),
        DroppleGame.ballRadius * s,
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(-0.4, -0.4),
            colors: [Colors.white, accent],
          ).createShader(Rect.fromCircle(center: w(ball!), radius: DroppleGame.ballRadius * s)),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _DropPainter old) => true;
}
