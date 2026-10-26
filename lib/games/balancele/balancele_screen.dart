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
import 'balancele_game.dart';

class BalanceleScreen extends StatefulWidget {
  final bool isDailyMode;
  final void Function(double score, [int durationMs])? onGameComplete;
  const BalanceleScreen({super.key, this.isDailyMode = true, this.onGameComplete});

  @override
  State<BalanceleScreen> createState() => _BalanceleScreenState();
}

class _BalanceleScreenState extends State<BalanceleScreen> with SingleTickerProviderStateMixin {
  static const Color _bg = Color(0xFF1B1530);
  static const Color _accent = Color(0xFFFF9F43);
  static const Color _fixedColor = Color(0xFF8E9AAF);

  late final BalanceleGame _game;
  late final AnimationController _tilt;
  final SoundService _sound = SoundService();
  final Stopwatch _stopwatch = Stopwatch()..start();

  int _round = 0;
  int _tries = 0;

  /// Oyuncu ağırlıklarının yeri (null: tepside)
  List<int?> _placed = [];
  int? _selected = 0;

  /// Terazinin varmak istediği eğim (radyan); kilitliyken 0
  double _from = 0, _to = 0;
  bool _locked = true;
  bool _busy = false;

  /// Tur bitti: null sürüyor, true dengelendi, false hakkı bitti
  bool? _solved;
  final List<double> _scores = [];

  bool get _tr => LanguageService().isTurkish;
  BalanceRound get _current => _game.rounds[_round];
  double get _total => _scores.fold(0.0, (a, b) => a + b);
  List<Weight> get _placedWeights => [
        for (var i = 0; i < _placed.length; i++)
          if (_placed[i] != null) Weight(_current.tray[i], _placed[i]!),
      ];
  bool get _allPlaced => _placed.every((p) => p != null);

  @override
  void initState() {
    super.initState();
    _game = BalanceleGame(widget.isDailyMode ? Random(DailyChallengeService.getSeededSeed('balancele')) : Random());
    _tilt = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100));
    _resetRound();
  }

  @override
  void dispose() {
    _tilt.dispose();
    super.dispose();
  }

  void _resetRound() {
    _placed = List.filled(_current.tray.length, null);
    _selected = 0;
    _tries = 0;
    _solved = null;
    _locked = true;
    _from = _to = 0;
    _tilt.value = 1;
  }

  double get _angle {
    final t = Curves.elasticOut.transform(_tilt.value);
    return _from + (_to - _from) * t;
  }

  Future<void> _animateTo(double target) async {
    _from = _angle;
    _to = target;
    await _tilt.forward(from: 0);
  }

  void _tapPeg(int pos) {
    if (_busy || _solved != null) return;
    _sound.playFlip();
    setState(() {
      if (_selected != null) {
        _placed[_selected!] = pos;
        final next = _placed.indexWhere((p) => p == null);
        _selected = next == -1 ? null : next;
      } else {
        // Seçili ağırlık yoksa o kancadaki son oyuncu ağırlığını tepsiye geri al
        final i = _placed.lastIndexOf(pos);
        if (i != -1) {
          _placed[i] = null;
          _selected = i;
        }
      }
    });
  }

  void _tapTray(int i) {
    if (_busy || _solved != null) return;
    _sound.playKeyTap();
    setState(() {
      if (_placed[i] != null) _placed[i] = null;
      _selected = i;
    });
  }

  Future<void> _release() async {
    if (_busy || !_allPlaced) return;
    _busy = true;
    final torque = BalanceleGame.torqueOf(_current.fixed) + BalanceleGame.torqueOf(_placedWeights);
    setState(() => _locked = false);
    final target = (torque * 0.035).clamp(-0.26, 0.26);
    await _animateTo(torque == 0 ? 0 : target.toDouble());
    if (!mounted) return;
    if (torque == 0) {
      _sound.playCorrect();
      setState(() {
        _solved = true;
        _scores.add(BalanceleGame.tryScores[_tries]);
      });
    } else {
      _sound.playError();
      _tries++;
      if (_tries >= BalanceleGame.maxTries) {
        await Future.delayed(const Duration(milliseconds: 700));
        if (!mounted) return;
        // Bir çözümü göster
        final sol = BalanceleGame.solve(_current);
        setState(() {
          _solved = false;
          _scores.add(0);
          for (var i = 0; i < sol.length; i++) {
            _placed[i] = sol[i].pos;
          }
        });
        await _animateTo(0);
      } else {
        await Future.delayed(const Duration(milliseconds: 600));
        if (!mounted) return;
        await _animateTo(0);
        if (!mounted) return;
        setState(() => _locked = true);
      }
    }
    _busy = false;
  }

  void _next() {
    if (_round + 1 >= BalanceleGame.totalRounds) {
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
      gameId: 'balancele',
      isDailyMode: widget.isDailyMode,
      onGameComplete: widget.onGameComplete,
      score: score,
      durationMs: _stopwatch.elapsedMilliseconds,
      attempts: BalanceleGame.totalRounds,
      maxAttempts: BalanceleGame.totalRounds,
    );
    final firstTry = _scores.where((s) => s == BalanceleGame.tryScores.first).length;
    GameResultSheet.show(
      context,
      GameResultSheet(
        title: firstTry >= 4 ? (_tr ? 'Kusursuz denge!' : 'Perfect balance!') : (_tr ? 'Terazi tamam' : 'Scales done'),
        headline: score.toStringAsFixed(0),
        caption: _tr ? 'Puan (100 üzerinden)' : 'Score (out of 100)',
        accent: _accent,
        isDailyRun: widget.onGameComplete != null,
        stats: [
          GameResultStat(_tr ? 'İlk denemede' : 'First try', '$firstTry/${BalanceleGame.totalRounds}'),
          GameResultStat(_tr ? 'Süre' : 'Time', '${(_stopwatch.elapsedMilliseconds / 1000).round()} sn'),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GameExitWrapper(
      gameId: 'balancele',
      isDailyMode: widget.isDailyMode,
      onGameComplete: widget.onGameComplete,
      child: Scaffold(
        backgroundColor: _bg,
        body: SafeArea(
          child: Column(
            children: [
              GameTopBar(
                title: 'Balancele',
                subtitle: _tr ? 'Teraziyi dengele' : 'Balance the scale',
                trailing: _total.toStringAsFixed(0),
                accent: _accent,
              ),
              RoundDots(total: BalanceleGame.totalRounds, current: _round, done: _scores.length, accent: _accent),
              const SizedBox(height: 12),
              Text(
                _tr ? 'Ağırlığı seç, sonra bir kancaya dokun' : 'Pick a weight, then tap a peg',
                style: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white60),
              ),
              const SizedBox(height: 6),
              _buildTries(),
              Expanded(child: _buildScale()),
              _buildTray(),
              _buildBottom(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTries() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < BalanceleGame.maxTries; i++)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: Icon(
              Icons.favorite_rounded,
              size: 18,
              color: i < BalanceleGame.maxTries - _tries ? const Color(0xFFFF5D73) : Colors.white12,
            ),
          ),
      ],
    );
  }

  Widget _buildScale() {
    return LayoutBuilder(builder: (context, box) {
      final geo = _ScaleGeometry(box.biggest);
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapUp: (d) {
          final pos = geo.pegAt(d.localPosition.dx);
          if (pos != null) _tapPeg(pos);
        },
        child: AnimatedBuilder(
          animation: _tilt,
          builder: (context, _) => CustomPaint(
            size: box.biggest,
            painter: _ScalePainter(
              geo: geo,
              fixed: _current.fixed,
              placed: _placedWeights,
              angle: _angle,
              locked: _locked,
              accent: _accent,
              fixedColor: _fixedColor,
              solved: _solved,
            ),
          ),
        ),
      );
    });
  }

  Widget _buildTray() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < _current.tray.length; i++)
            GestureDetector(
              onTap: () => _tapTray(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                margin: const EdgeInsets.symmetric(horizontal: 8),
                width: 74,
                height: 58,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _placed[i] != null ? Colors.white.withValues(alpha: 0.06) : _accent,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _selected == i && _solved == null ? Colors.white : Colors.transparent,
                    width: 3,
                  ),
                ),
                child: Text(
                  '${_current.tray[i]} kg',
                  style: GoogleFonts.nunito(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: _placed[i] != null ? Colors.white38 : _bg,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBottom() {
    final done = _solved != null;
    String label;
    if (done) {
      label = _round + 1 >= BalanceleGame.totalRounds ? (_tr ? 'SONUÇ' : 'RESULT') : (_tr ? 'SONRAKİ' : 'NEXT');
    } else {
      label = _tr ? 'BIRAK' : 'RELEASE';
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        children: [
          SizedBox(
            height: 24,
            child: done
                ? Text(
                    _solved!
                        ? '${_tr ? 'Dengede!' : 'Balanced!'} +${_scores.last.toStringAsFixed(0)}'
                        : (_tr ? 'Hakların bitti, işte bir çözüm' : 'Out of tries, here is a solution'),
                    style: GoogleFonts.nunito(
                        fontSize: 16, fontWeight: FontWeight.w900, color: _solved! ? const Color(0xFF7CF5C4) : Colors.white70),
                  )
                : null,
          ),
          const SizedBox(height: 6),
          ChunkyButton(
            face: done ? const Color(0xFF7CF5C4) : _accent,
            lip: done ? const Color(0xFF2FA07A) : const Color(0xFFC46A1E),
            height: 56,
            onTap: done ? _next : (_allPlaced && !_busy ? _release : null),
            child: Text(label, style: GoogleFonts.nunito(fontSize: 20, fontWeight: FontWeight.w900, color: _bg)),
          ),
        ],
      ),
    );
  }
}

/// Terazi ölçüleri: kancaların ekrandaki x konumu ve dokunma eşlemesi
class _ScaleGeometry {
  final Size size;
  _ScaleGeometry(this.size);

  Offset get pivot => Offset(size.width / 2, size.height * 0.66);
  double get halfBeam => min(size.width * 0.44, 210);
  double get step => halfBeam / (BalanceleGame.maxDistance + 0.5);

  double xOf(int pos) => pos * step;

  int? pegAt(double x) {
    final rel = (x - pivot.dx) / step;
    final p = rel.round();
    if (p == 0 || p.abs() > BalanceleGame.maxDistance || (rel - p).abs() > 0.5) return null;
    return p;
  }
}

class _ScalePainter extends CustomPainter {
  final _ScaleGeometry geo;
  final List<Weight> fixed;
  final List<Weight> placed;
  final double angle;
  final bool locked;
  final Color accent;
  final Color fixedColor;
  final bool? solved;

  _ScalePainter({
    required this.geo,
    required this.fixed,
    required this.placed,
    required this.angle,
    required this.locked,
    required this.accent,
    required this.fixedColor,
    required this.solved,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final p = geo.pivot;
    final hb = geo.halfBeam;

    // Ayak (üçgen)
    final stand = Path()
      ..moveTo(p.dx, p.dy)
      ..lineTo(p.dx - 34, p.dy + 74)
      ..lineTo(p.dx + 34, p.dy + 74)
      ..close();
    canvas.drawPath(stand, Paint()..color = const Color(0xFF3A3156));
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromCenter(center: p + const Offset(0, 78), width: 120, height: 10), const Radius.circular(5)),
      Paint()..color = const Color(0xFF3A3156),
    );

    // Kilit takozları: denemeden önce terazi kıpırdamaz
    if (locked) {
      for (final s in [-1, 1]) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(p.dx + s * (hb - 18) - 14, p.dy + 8, 28, 66),
            const Radius.circular(6),
          ),
          Paint()..color = const Color(0xFF5A4A86),
        );
      }
    }

    canvas.save();
    canvas.translate(p.dx, p.dy);
    canvas.rotate(angle);

    // Kiriş
    final beamColor = solved == true ? const Color(0xFF7CF5C4) : const Color(0xFFD9CFF5);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTRB(-hb, -6, hb, 6), const Radius.circular(6)),
      Paint()..color = beamColor,
    );
    // Kancalar ve mesafe etiketleri
    for (var d = 1; d <= BalanceleGame.maxDistance; d++) {
      for (final s in [-1, 1]) {
        final x = geo.xOf(d * s);
        canvas.drawCircle(Offset(x, 0), 4, Paint()..color = const Color(0xFF6F5FA8));
        _label(canvas, '$d', Offset(x, 18), 11, Colors.white38);
      }
    }
    canvas.drawCircle(Offset.zero, 8, Paint()..color = accent);

    // Ağırlıklar: her kancada üst üste dizilir; önce sabitler, sonra oyuncununkiler
    final stacks = <int, List<(Weight, bool)>>{};
    for (final w in fixed) {
      stacks.putIfAbsent(w.pos, () => []).add((w, false));
    }
    for (final w in placed) {
      stacks.putIfAbsent(w.pos, () => []).add((w, true));
    }
    for (final e in stacks.entries) {
      var y = -6.0;
      for (final (w, mine) in e.value) {
        final bw = 26.0 + w.kg * 3.2;
        final bh = 18.0 + w.kg * 2.2;
        final rect = Rect.fromLTWH(geo.xOf(e.key) - bw / 2, y - bh, bw, bh);
        canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(6)), Paint()..color = mine ? accent : fixedColor);
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect.deflate(1), const Radius.circular(6)),
          Paint()
            ..color = Colors.black.withValues(alpha: 0.18)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
        _label(canvas, '${w.kg}', rect.center, 14, const Color(0xFF1B1530));
        y -= bh + 2;
      }
    }
    canvas.restore();
  }

  void _label(Canvas canvas, String s, Offset center, double size, Color color) {
    final tp = TextPainter(
      text: TextSpan(text: s, style: GoogleFonts.nunito(fontSize: size, fontWeight: FontWeight.w900, color: color)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant _ScalePainter old) => true;
}
