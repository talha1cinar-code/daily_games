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
import 'shadowle_game.dart';

class ShadowleScreen extends StatefulWidget {
  final bool isDailyMode;
  final void Function(double score, [int durationMs])? onGameComplete;
  const ShadowleScreen({super.key, this.isDailyMode = true, this.onGameComplete});

  @override
  State<ShadowleScreen> createState() => _ShadowleScreenState();
}

class _ShadowleScreenState extends State<ShadowleScreen> {
  static const Color _bg = Color(0xFF1A1426);
  static const Color _accent = Color(0xFFFF8FC7);
  static const Color _good = Color(0xFF3DDC84);
  static const Color _bad = Color(0xFFFF5D73);

  late final ShadowleGame _game;
  final SoundService _sound = SoundService();
  final Stopwatch _stopwatch = Stopwatch()..start();

  int _round = 0;
  int? _picked;
  final List<double> _scores = [];

  bool get _tr => LanguageService().isTurkish;
  ShadowRound get _current => _game.rounds[_round];
  double get _total => _scores.fold(0.0, (a, b) => a + b);

  @override
  void initState() {
    super.initState();
    _game = ShadowleGame(widget.isDailyMode ? Random(DailyChallengeService.getSeededSeed('shadowle')) : Random());
  }

  void _pick(int i) {
    if (_picked != null) return;
    final ok = i == _current.answer;
    ok ? _sound.playCorrect() : _sound.playError();
    setState(() {
      _picked = i;
      _scores.add(ok ? ShadowleGame.roundScore : 0);
    });
  }

  void _next() {
    if (_round + 1 >= ShadowleGame.totalRounds) {
      _finish();
      return;
    }
    _sound.playKeyTap();
    setState(() {
      _round++;
      _picked = null;
    });
  }

  void _finish() {
    _stopwatch.stop();
    final score = _total;
    reportGameScore(
      gameId: 'shadowle',
      isDailyMode: widget.isDailyMode,
      onGameComplete: widget.onGameComplete,
      score: score,
      durationMs: _stopwatch.elapsedMilliseconds,
      attempts: ShadowleGame.totalRounds,
      maxAttempts: ShadowleGame.totalRounds,
    );
    final right = _scores.where((s) => s > 0).length;
    GameResultSheet.show(
      context,
      GameResultSheet(
        title: right == ShadowleGame.totalRounds ? (_tr ? 'Röntgen gözler!' : 'X-ray eyes!') : (_tr ? 'Gölgeler tamam' : 'Shadows done'),
        headline: score.toStringAsFixed(0),
        caption: _tr ? 'Puan (100 üzerinden)' : 'Score (out of 100)',
        accent: _accent,
        isDailyRun: widget.onGameComplete != null,
        stats: [
          GameResultStat(_tr ? 'Doğru' : 'Correct', '$right/${ShadowleGame.totalRounds}'),
          GameResultStat(_tr ? 'Süre' : 'Time', '${(_stopwatch.elapsedMilliseconds / 1000).round()} sn'),
        ],
      ),
    );
  }

  String get _question {
    switch (_current.view) {
      case ShadowView.top:
        return _tr ? 'Tepeden bakınca ne görürsün?' : 'What do you see from above?';
      case ShadowView.front:
      case ShadowView.side:
        return _tr ? 'Gözün olduğu yerden bakınca ne görürsün?' : 'What do you see from where the eye is?';
    }
  }

  @override
  Widget build(BuildContext context) {
    return GameExitWrapper(
      gameId: 'shadowle',
      isDailyMode: widget.isDailyMode,
      onGameComplete: widget.onGameComplete,
      child: Scaffold(
        backgroundColor: _bg,
        body: SafeArea(
          child: Column(
            children: [
              GameTopBar(
                title: 'Shadowle',
                subtitle: _tr ? 'Hangi gölge?' : 'Which shadow?',
                trailing: _total.toStringAsFixed(0),
                accent: _accent,
              ),
              RoundDots(total: ShadowleGame.totalRounds, current: _round, done: _scores.length, accent: _accent),
              const SizedBox(height: 10),
              Text(_question, style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.white)),
              Expanded(
                flex: 5,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: CustomPaint(
                    size: Size.infinite,
                    painter: _IsoPainter(_current.voxels, _current.view, _accent),
                  ),
                ),
              ),
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
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: border, width: 4),
              ),
              child: CellsView(
                cells: _current.options[i],
                color: const Color(0xFFE6DDF5),
                gridSize: ShadowleGame.n,
                showGrid: true,
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(children: [for (var i = 0; i < 4; i++) option(i)]),
    );
  }

  Widget _buildBottom() {
    final done = _picked != null;
    final ok = done && _picked == _current.answer;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Column(
        children: [
          SizedBox(
            height: 24,
            child: done
                ? Text(ok ? (_tr ? 'Doğru! +20' : 'Correct! +20') : (_tr ? 'Doğrusu yeşil olan' : 'The green one was right'),
                    style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w900, color: ok ? _good : Colors.white70))
                : null,
          ),
          const SizedBox(height: 6),
          ChunkyButton(
            face: done ? _good : Colors.white24,
            lip: done ? const Color(0xFF1E9E55) : Colors.white10,
            height: 56,
            onTap: done ? _next : null,
            child: Text(
              _round + 1 >= ShadowleGame.totalRounds ? (_tr ? 'SONUÇ' : 'RESULT') : (_tr ? 'SONRAKİ' : 'NEXT'),
              style: GoogleFonts.nunito(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

/// İzometrik küp çizimi: +x sağ-aşağı, +y sol-aşağı, +z yukarı.
/// Görünen yüzler: üst (+z), sağ (+x) ve sol (+y).
class _IsoPainter extends CustomPainter {
  final Set<Voxel> voxels;
  final ShadowView view;
  final Color accent;

  _IsoPainter(this.voxels, this.view, this.accent);

  static const double _cos30 = 0.8660254;

  Offset _raw(double x, double y, double z) => Offset((x - y) * _cos30, (x + y) * 0.5 - z);

  /// Gözün ve okun dünya koordinatları
  (List<double>, List<double>) get _arrow {
    switch (view) {
      case ShadowView.top:
        return ([1.5, 1.5, 5.4], [1.5, 1.5, 3.6]);
      case ShadowView.front:
        return ([1.5, 5.6, 1.5], [1.5, 3.7, 1.5]);
      case ShadowView.side:
        return ([5.6, 1.5, 1.5], [3.7, 1.5, 1.5]);
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final (eye, tip) = _arrow;
    // Çizimi sığdırmak için sınırlar: 3x3x3 kutu + göz
    final pts = <Offset>[
      for (final x in [0.0, 3.0])
        for (final y in [0.0, 3.0])
          for (final z in [0.0, 3.0]) _raw(x, y, z),
      _raw(eye[0], eye[1], eye[2]),
    ];
    final minX = pts.map((p) => p.dx).reduce(min), maxX = pts.map((p) => p.dx).reduce(max);
    final minY = pts.map((p) => p.dy).reduce(min), maxY = pts.map((p) => p.dy).reduce(max);
    final scale = min(size.width / (maxX - minX + 0.6), size.height / (maxY - minY + 0.6));
    final origin = Offset(
      size.width / 2 - (minX + maxX) / 2 * scale,
      size.height / 2 - (minY + maxY) / 2 * scale,
    );
    Offset p(double x, double y, double z) => origin + _raw(x, y, z) * scale;

    // Zemin ızgarası
    final floor = Paint()
      ..color = Colors.white12
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    for (var i = 0; i <= 3; i++) {
      canvas.drawLine(p(i.toDouble(), 0, 0), p(i.toDouble(), 3, 0), floor);
      canvas.drawLine(p(0, i.toDouble(), 0), p(3, i.toDouble(), 0), floor);
    }

    final top = Paint()..color = const Color(0xFFFFD6EC);
    final right = Paint()..color = const Color(0xFFE77FB6);
    final left = Paint()..color = const Color(0xFFB4508A);
    final edge = Paint()
      ..color = const Color(0xFF2B2140)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeJoin = StrokeJoin.round;

    final sorted = voxels.toList()..sort((a, b) => (a.$1 + a.$2 + a.$3).compareTo(b.$1 + b.$2 + b.$3));
    for (final (xi, yi, zi) in sorted) {
      final x = xi.toDouble(), y = yi.toDouble(), z = zi.toDouble();
      final faces = [
        ([p(x, y, z + 1), p(x + 1, y, z + 1), p(x + 1, y + 1, z + 1), p(x, y + 1, z + 1)], top),
        ([p(x + 1, y, z), p(x + 1, y + 1, z), p(x + 1, y + 1, z + 1), p(x + 1, y, z + 1)], right),
        ([p(x, y + 1, z), p(x + 1, y + 1, z), p(x + 1, y + 1, z + 1), p(x, y + 1, z + 1)], left),
      ];
      for (final (poly, paint) in faces) {
        final path = Path()..addPolygon(poly, true);
        canvas.drawPath(path, paint);
        canvas.drawPath(path, edge);
      }
    }

    // Göz ve ok
    final a = p(eye[0], eye[1], eye[2]);
    final b = p(tip[0], tip[1], tip[2]);
    final arrow = Paint()
      ..color = accent
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    final dir = (b - a) / (b - a).distance;
    final start = a + dir * 18;
    canvas.drawLine(start, b, arrow);
    final normal = Offset(-dir.dy, dir.dx);
    canvas.drawPath(
      Path()
        ..moveTo(b.dx + dir.dx * 10, b.dy + dir.dy * 10)
        ..lineTo(b.dx - dir.dx * 6 + normal.dx * 10, b.dy - dir.dy * 6 + normal.dy * 10)
        ..lineTo(b.dx - dir.dx * 6 - normal.dx * 10, b.dy - dir.dy * 6 - normal.dy * 10)
        ..close(),
      Paint()..color = accent,
    );
    final tp = TextPainter(text: const TextSpan(text: '👁', style: TextStyle(fontSize: 26)), textDirection: TextDirection.ltr)
      ..layout();
    tp.paint(canvas, a - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant _IsoPainter old) => old.voxels != voxels || old.view != view;
}
