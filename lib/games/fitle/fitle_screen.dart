import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../widgets/game_exit_wrapper.dart';
import '../../widgets/game_result_sheet.dart';
import '../../widgets/chunky_button.dart';
import '../../services/sound_service.dart';
import '../../services/daily_challenge_service.dart';
import '../../services/language_service.dart';
import '../common/game_common.dart';
import 'fitle_game.dart';

class FitleScreen extends StatefulWidget {
  final bool isDailyMode;
  final void Function(double score, [int durationMs])? onGameComplete;

  /// Testlerde hazır oyun verilir; normalde arka planda üretilir
  @visibleForTesting
  final FitleGame? game;

  const FitleScreen({super.key, this.isDailyMode = true, this.onGameComplete, this.game});

  @override
  State<FitleScreen> createState() => _FitleScreenState();
}

class _FitleScreenState extends State<FitleScreen> with SingleTickerProviderStateMixin {
  static const Color _bg = Color(0xFF0F2027);
  static const Color _accent = Color(0xFF4DD6C1);
  static const Color _good = Color(0xFF3DDC84);
  static const int _maxDigits = 3;

  FitleGame? _game;
  final SoundService _sound = SoundService();
  final Stopwatch _stopwatch = Stopwatch()..start();
  late final AnimationController _reveal = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  int _round = 0;
  String _input = '';
  bool _revealed = false;
  final List<double> _scores = [];
  final List<int> _misses = [];

  bool get _tr => LanguageService().isTurkish;
  FitRound get _current => _game!.rounds[_round];
  double get _total => _scores.fold(0.0, (a, b) => a + b);
  int get _guess => int.tryParse(_input) ?? 0;

  @override
  void initState() {
    super.initState();
    _game = widget.game;
    if (_game != null) return;
    final seed = widget.isDailyMode ? DailyChallengeService.getSeededSeed('fitle') : Random().nextInt(1 << 31);
    compute(FitleGame.fromSeed, seed).then((game) {
      if (!mounted) return;
      _stopwatch.reset();
      setState(() => _game = game);
    });
  }

  @override
  void dispose() {
    _reveal.dispose();
    super.dispose();
  }

  void _digit(String d) {
    if (_revealed || _input.length >= _maxDigits || (_input.isEmpty && d == '0')) return;
    _sound.playKeyTap();
    setState(() => _input += d);
  }

  void _backspace() {
    if (_revealed || _input.isEmpty) return;
    _sound.playDelete();
    setState(() => _input = _input.substring(0, _input.length - 1));
  }

  void _submit() {
    if (_revealed || _guess <= 0) return;
    final score = FitleGame.roundScore(_guess, _current.answer);
    score >= 14 ? _sound.playCorrect() : (score > 0 ? _sound.playFlip() : _sound.playError());
    setState(() {
      _revealed = true;
      _scores.add(score);
      _misses.add((_guess - _current.answer).abs());
    });
    _reveal.forward(from: 0);
  }

  void _next() {
    if (_round + 1 >= FitleGame.totalRounds) {
      _finish();
      return;
    }
    _sound.playKeyTap();
    setState(() {
      _round++;
      _input = '';
      _revealed = false;
    });
    _reveal.value = 0;
  }

  void _finish() {
    _stopwatch.stop();
    final score = _total;
    reportGameScore(
      gameId: 'fitle',
      isDailyMode: widget.isDailyMode,
      onGameComplete: widget.onGameComplete,
      score: score,
      durationMs: _stopwatch.elapsedMilliseconds,
      attempts: FitleGame.totalRounds,
      maxAttempts: FitleGame.totalRounds,
    );
    final exact = _misses.where((m) => m == 0).length;
    GameResultSheet.show(
      context,
      GameResultSheet(
        title: score >= 75 ? (_tr ? 'Gözün terazi!' : 'Great eye!') : (_tr ? 'Şekiller doldu' : 'Shapes filled'),
        headline: score.toStringAsFixed(0),
        caption: _tr ? 'Puan (100 üzerinden)' : 'Score (out of 100)',
        accent: _accent,
        isDailyRun: widget.onGameComplete != null,
        stats: [
          GameResultStat(_tr ? 'Tam isabet' : 'Exact', '$exact/${FitleGame.totalRounds}'),
          GameResultStat(_tr ? 'Süre' : 'Time', '${(_stopwatch.elapsedMilliseconds / 1000).round()} sn'),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GameExitWrapper(
      gameId: 'fitle',
      isDailyMode: widget.isDailyMode,
      onGameComplete: widget.onGameComplete,
      child: Scaffold(
        backgroundColor: _bg,
        body: SafeArea(
          child: _game == null
              ? const Center(child: CircularProgressIndicator(color: _accent))
              : Column(
                  children: [
                    GameTopBar(
                      title: 'Fitle',
                      subtitle: _tr ? 'Kaç çember sığar?' : 'How many circles fit?',
                      trailing: _total.toStringAsFixed(0),
                      accent: _accent,
                    ),
                    RoundDots(total: FitleGame.totalRounds, current: _round, done: _scores.length, accent: _accent),
                    const SizedBox(height: 10),
                    _buildStatus(),
                    Expanded(child: _buildBoard()),
                    // Sabit yükseklik: tahmin ve sonuç arasında tahta boyutu değişip ölçeği bozmasın
                    SizedBox(height: 276, child: _revealed ? _buildResult() : _buildKeypad()),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildStatus() {
    return SizedBox(
      height: 44,
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: _input.isEmpty && !_revealed
              ? Text(
                  _tr ? 'Bu çemberden en fazla kaç tane sığar?' : 'How many of this circle can fit at most?',
                  style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white),
                )
              : Text(
                  _input,
                  style: GoogleFonts.nunito(fontSize: 34, fontWeight: FontWeight.w900, color: _accent, height: 1.1),
                ),
        ),
      ),
    );
  }

  Widget _buildBoard() {
    return LayoutBuilder(
      builder: (context, c) {
        final size = min(c.maxWidth - 24, c.maxHeight - 8);
        return Center(
          child: AnimatedBuilder(
            animation: _reveal,
            builder: (context, _) => CustomPaint(
              size: Size.square(size),
              painter: _BoardPainter(
                shape: _current.shape,
                radius: _current.radius,
                // Önce ölçek için tek çember, sonuçta dizilim tek tek dolar
                circles: _revealed
                    ? _current.packing.take((_reveal.value * _current.answer).ceil()).toList()
                    : [_current.sample],
                accent: _accent,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildKeypad() {
    Widget key(String label, {VoidCallback? onTap, Color face = const Color(0xFF2B4A55), IconData? icon}) => Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: ChunkyButton(
          face: onTap == null ? Colors.white24 : face,
          lip: onTap == null ? Colors.white10 : Color.lerp(face, Colors.black, 0.35)!,
          height: 54,
          radius: 14,
          onTap: onTap,
          child: icon != null
              ? Icon(icon, color: Colors.white, size: 26)
              : Text(
                  label,
                  style: GoogleFonts.nunito(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white),
                ),
        ),
      ),
    );

    Widget row(List<String> digits) => Row(children: [for (final d in digits) key(d, onTap: () => _digit(d))]);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          row(['1', '2', '3']),
          row(['4', '5', '6']),
          row(['7', '8', '9']),
          Row(
            children: [
              key('', icon: Icons.backspace_rounded, onTap: _input.isEmpty ? null : _backspace),
              key('0', onTap: () => _digit('0')),
              key('', icon: Icons.check_rounded, face: _good, onTap: _guess > 0 ? _submit : null),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildResult() {
    final miss = _misses.last;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Column(
        children: [
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${_current.answer}',
                    style: GoogleFonts.nunito(
                      fontSize: 52,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      height: 1.1,
                    ),
                  ),
                  Text(
                    _tr ? 'çember sığdırdık' : 'circles fit here',
                    style: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white60),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    miss == 0
                        ? '${_tr ? 'Tam isabet!' : 'Exact!'}  +${_scores.last.toStringAsFixed(0)}'
                        : '${_tr ? 'Tahminin' : 'You said'} $_guess  ·  +${_scores.last.toStringAsFixed(0)}',
                    style: GoogleFonts.nunito(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: miss == 0 ? _good : _accent,
                    ),
                  ),
                ],
              ),
            ),
          ),
          ChunkyButton(
            face: _good,
            lip: const Color(0xFF1E9E55),
            height: 56,
            onTap: _next,
            child: Text(
              _round + 1 >= FitleGame.totalRounds ? (_tr ? 'SONUÇ' : 'RESULT') : (_tr ? 'SONRAKİ' : 'NEXT'),
              style: GoogleFonts.nunito(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

class _BoardPainter extends CustomPainter {
  final List<Pt> shape;
  final double radius;
  final List<Pt> circles;
  final Color accent;

  const _BoardPainter({required this.shape, required this.radius, required this.circles, required this.accent});

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    Offset o(Pt p) => Offset(p.x * s, p.y * s);
    final path = Path()..addPolygon([for (final p in shape) o(p)], true);
    canvas.drawPath(path, Paint()..color = Colors.white.withValues(alpha: 0.07));
    canvas.drawPath(
      path,
      Paint()
        ..color = accent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeJoin = StrokeJoin.round,
    );

    final r = radius * s;
    for (final p in circles) {
      final c = o(p);
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..shader = const RadialGradient(
            colors: [Color(0xFFFFE27A), Color(0xFFFFB627)],
          ).createShader(Rect.fromCircle(center: c, radius: r)),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BoardPainter old) =>
      old.shape != shape || old.radius != radius || old.circles.length != circles.length;
}
