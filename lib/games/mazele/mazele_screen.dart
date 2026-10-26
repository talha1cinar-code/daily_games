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
import 'mazele_game.dart';

class MazeleScreen extends StatefulWidget {
  final bool isDailyMode;
  final void Function(double score, [int durationMs])? onGameComplete;
  const MazeleScreen({super.key, this.isDailyMode = true, this.onGameComplete});

  @override
  State<MazeleScreen> createState() => _MazeleScreenState();
}

enum _Phase { ready, view, walk, done }

class _MazeleScreenState extends State<MazeleScreen> with SingleTickerProviderStateMixin {
  static const Color _bg = Color(0xFF120F1F);
  static const Color _accent = Color(0xFFB66DFF);
  static const Color _goal = Color(0xFFFFC94D);

  late final MazeleGame _game;
  late final AnimationController _view;
  final SoundService _sound = SoundService();
  final Stopwatch _stopwatch = Stopwatch()..start();

  int _round = 0;
  _Phase _phase = _Phase.ready;
  int _pos = 0;
  int _bumps = 0;
  final List<int> _trail = [];

  /// Çarpılan duvarlar kalıcı olarak görünür: (hücre, yön)
  final Set<(int, int)> _hitWalls = {};
  final List<double> _scores = [];

  bool get _tr => LanguageService().isTurkish;
  MazeRound get _current => _game.rounds[_round];
  double get _total => _scores.fold(0.0, (a, b) => a + b);

  @override
  void initState() {
    super.initState();
    _game = MazeleGame(widget.isDailyMode ? Random(DailyChallengeService.getSeededSeed('mazele')) : Random());
    _view = AnimationController(vsync: this)
      ..addStatusListener((s) {
        if (s == AnimationStatus.completed && mounted && _phase == _Phase.view) {
          setState(() => _phase = _Phase.walk);
        }
      });
    _resetRound();
  }

  @override
  void dispose() {
    _view.dispose();
    super.dispose();
  }

  void _resetRound() {
    _pos = _current.start;
    _bumps = 0;
    _trail
      ..clear()
      ..add(_pos);
    _hitWalls.clear();
    _phase = _Phase.ready;
  }

  void _show() {
    _sound.playGo();
    setState(() => _phase = _Phase.view);
    _view.duration = Duration(milliseconds: _current.viewMs);
    _view.forward(from: 0);
  }

  void _move(int dir) {
    if (_phase != _Phase.walk) return;
    final next = _current.maze.move(_pos, dir);
    if (next == null) {
      _sound.playError();
      setState(() {
        _bumps++;
        _hitWalls.add((_pos, dir));
      });
      if (MazeleGame.roundScore(_bumps) <= 0) _endRound();
      return;
    }
    _sound.playKeyTap();
    setState(() {
      _pos = next;
      _trail.add(next);
    });
    if (_pos == _current.goal) _endRound();
  }

  void _endRound() {
    final score = MazeleGame.roundScore(_bumps);
    if (_pos == _current.goal) {
      score >= 20 ? _sound.playCorrect() : _sound.playFlip();
    }
    setState(() {
      _phase = _Phase.done;
      _scores.add(_pos == _current.goal ? score : 0);
    });
  }

  void _next() {
    if (_round + 1 >= MazeleGame.totalRounds) {
      _finish();
      return;
    }
    _sound.playKeyTap();
    setState(() {
      _round++;
      _resetRound();
    });
  }

  void _finish() {
    _stopwatch.stop();
    final score = _total;
    reportGameScore(
      gameId: 'mazele',
      isDailyMode: widget.isDailyMode,
      onGameComplete: widget.onGameComplete,
      score: score,
      durationMs: _stopwatch.elapsedMilliseconds,
      attempts: MazeleGame.totalRounds,
      maxAttempts: MazeleGame.totalRounds,
    );
    final clean = _scores.where((s) => s >= MazeleGame.maxRoundScore).length;
    GameResultSheet.show(
      context,
      GameResultSheet(
        title: clean >= 3 ? (_tr ? 'Gözü kapalı bile!' : 'Even blindfolded!') : (_tr ? 'Labirentler tamam' : 'Mazes done'),
        headline: score.toStringAsFixed(0),
        caption: _tr ? 'Puan (100 üzerinden)' : 'Score (out of 100)',
        accent: _accent,
        isDailyRun: widget.onGameComplete != null,
        stats: [
          GameResultStat(_tr ? 'Çarpmadan' : 'No bumps', '$clean/${MazeleGame.totalRounds}'),
          GameResultStat(_tr ? 'Süre' : 'Time', '${(_stopwatch.elapsedMilliseconds / 1000).round()} sn'),
        ],
      ),
    );
  }

  String get _hint {
    switch (_phase) {
      case _Phase.ready:
        return _tr ? 'Yolu ezberle, sonra karanlıkta bayrağa yürü' : 'Memorise the path, then walk to the flag in the dark';
      case _Phase.view:
        return _tr ? 'Ezberle...' : 'Memorise...';
      case _Phase.walk:
        return _tr ? 'Duvarlar kayboldu! Her çarpış -5' : 'Walls are gone! Each bump -5';
      case _Phase.done:
        return _pos == _current.goal
            ? '${_tr ? 'Vardın!' : 'Made it!'} +${_scores.last.toStringAsFixed(0)}'
            : (_tr ? 'Çok çarptın, tur bitti' : 'Too many bumps, round over');
    }
  }

  @override
  Widget build(BuildContext context) {
    return GameExitWrapper(
      gameId: 'mazele',
      isDailyMode: widget.isDailyMode,
      onGameComplete: widget.onGameComplete,
      child: Scaffold(
        backgroundColor: _bg,
        body: SafeArea(
          child: Column(
            children: [
              GameTopBar(
                title: 'Mazele',
                subtitle: _tr ? 'Karanlıkta labirent' : 'Maze in the dark',
                trailing: _total.toStringAsFixed(0),
                accent: _accent,
              ),
              RoundDots(total: MazeleGame.totalRounds, current: _round, done: _scores.length, accent: _accent),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  _hint,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.nunito(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white70),
                ),
              ),
              const SizedBox(height: 8),
              _buildViewBar(),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Center(
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: GestureDetector(
                        onPanEnd: (d) {
                          final v = d.velocity.pixelsPerSecond;
                          if (v.distance < 150) return;
                          _move(v.dx.abs() > v.dy.abs()
                              ? (v.dx > 0 ? Maze.right : Maze.left)
                              : (v.dy > 0 ? Maze.down : Maze.up));
                        },
                        child: CustomPaint(
                          painter: _MazePainter(
                            round: _current,
                            pos: _pos,
                            trail: List.of(_trail),
                            hitWalls: Set.of(_hitWalls),
                            showWalls: _phase == _Phase.view || _phase == _Phase.done,
                            accent: _accent,
                            goal: _goal,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              _buildBottom(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildViewBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 48),
      child: AnimatedBuilder(
        animation: _view,
        builder: (context, _) => ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: _phase == _Phase.view ? 1 - _view.value : 0,
            minHeight: 6,
            backgroundColor: Colors.white10,
            valueColor: const AlwaysStoppedAnimation(_accent),
          ),
        ),
      ),
    );
  }

  Widget _buildBottom() {
    if (_phase == _Phase.ready || _phase == _Phase.done) {
      final done = _phase == _Phase.done;
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: SizedBox(
          height: 170,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              ChunkyButton(
                face: done ? const Color(0xFF7CF5C4) : _accent,
                lip: done ? const Color(0xFF2FA07A) : const Color(0xFF7A3BC2),
                height: 56,
                onTap: done ? _next : _show,
                child: Text(
                  done
                      ? (_round + 1 >= MazeleGame.totalRounds ? (_tr ? 'SONUÇ' : 'RESULT') : (_tr ? 'SONRAKİ' : 'NEXT'))
                      : (_tr ? 'GÖSTER' : 'SHOW'),
                  style: GoogleFonts.nunito(fontSize: 20, fontWeight: FontWeight.w900, color: done ? _bg : Colors.white),
                ),
              ),
            ],
          ),
        ),
      );
    }
    // Yön tuşları
    Widget pad(IconData icon, int dir) => Padding(
          padding: const EdgeInsets.all(4),
          child: Material(
            color: _phase == _Phase.walk ? Colors.white.withValues(alpha: 0.1) : Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => _move(dir),
              child: SizedBox(width: 64, height: 50, child: Icon(icon, color: Colors.white, size: 30)),
            ),
          ),
        );
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: SizedBox(
        height: 170,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            pad(Icons.keyboard_arrow_up_rounded, Maze.up),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                pad(Icons.keyboard_arrow_left_rounded, Maze.left),
                pad(Icons.keyboard_arrow_down_rounded, Maze.down),
                pad(Icons.keyboard_arrow_right_rounded, Maze.right),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MazePainter extends CustomPainter {
  final MazeRound round;
  final int pos;
  final List<int> trail;
  final Set<(int, int)> hitWalls;
  final bool showWalls;
  final Color accent;
  final Color goal;

  _MazePainter({
    required this.round,
    required this.pos,
    required this.trail,
    required this.hitWalls,
    required this.showWalls,
    required this.accent,
    required this.goal,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final m = round.maze;
    final n = m.n;
    final cell = size.width / n;
    Offset centerOf(int i) => Offset((i % n + 0.5) * cell, (i ~/ n + 0.5) * cell);

    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(14)),
      Paint()..color = Colors.white.withValues(alpha: 0.04),
    );
    // Izgara noktaları: karanlıkta yön bulmaya yardım eder
    for (var r = 0; r <= n; r++) {
      for (var c = 0; c <= n; c++) {
        canvas.drawCircle(Offset(c * cell, r * cell), 2.5, Paint()..color = Colors.white24);
      }
    }

    // İz
    if (trail.length > 1) {
      final path = Path()..moveTo(centerOf(trail.first).dx, centerOf(trail.first).dy);
      for (final t in trail.skip(1)) {
        path.lineTo(centerOf(t).dx, centerOf(t).dy);
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = accent.withValues(alpha: 0.35)
          ..style = PaintingStyle.stroke
          ..strokeWidth = cell * 0.18
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }

    void wall(int i, int dir, Paint p) {
      final x = (i % n) * cell, y = (i ~/ n) * cell;
      switch (dir) {
        case Maze.up:
          canvas.drawLine(Offset(x, y), Offset(x + cell, y), p);
        case Maze.down:
          canvas.drawLine(Offset(x, y + cell), Offset(x + cell, y + cell), p);
        case Maze.left:
          canvas.drawLine(Offset(x, y), Offset(x, y + cell), p);
        case Maze.right:
          canvas.drawLine(Offset(x + cell, y), Offset(x + cell, y + cell), p);
      }
    }

    final wallPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    // Dış çerçeve hep görünür; karanlıkta yalnızca iç duvarlar gizlenir
    canvas.drawRect(Offset.zero & size, Paint()
      ..color = Colors.white70
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5);
    if (showWalls) {
      for (var i = 0; i < n * n; i++) {
        for (final d in const [Maze.up, Maze.right, Maze.down, Maze.left]) {
          if (m.hasWall(i, d)) wall(i, d, wallPaint);
        }
      }
    }
    final hitPaint = Paint()
      ..color = const Color(0xFFFF5D73)
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;
    for (final (i, d) in hitWalls) {
      wall(i, d, hitPaint);
    }

    // Hedef bayrak ve oyuncu
    final g = centerOf(round.goal);
    canvas.drawCircle(g, cell * 0.3, Paint()..color = goal.withValues(alpha: 0.25));
    canvas.drawCircle(g, cell * 0.16, Paint()..color = goal);
    canvas.drawCircle(centerOf(pos), cell * 0.28, Paint()..color = accent);
    canvas.drawCircle(centerOf(pos), cell * 0.12, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant _MazePainter old) => true;
}
