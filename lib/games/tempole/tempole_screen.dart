import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../widgets/game_exit_wrapper.dart';
import '../../widgets/game_result_sheet.dart';
import '../../widgets/chunky_button.dart';
import '../../widgets/coin_badge.dart';
import '../../widgets/coin_offer_dialog.dart';
import '../../services/coin_service.dart';
import '../../services/sound_service.dart';
import '../../services/daily_challenge_service.dart';
import '../../services/language_service.dart';
import '../common/game_common.dart';
import 'tempole_game.dart';

class TempoleScreen extends StatefulWidget {
  final bool isDailyMode;
  final void Function(double score, [int durationMs])? onGameComplete;
  const TempoleScreen({super.key, this.isDailyMode = true, this.onGameComplete});

  @override
  State<TempoleScreen> createState() => _TempoleScreenState();
}

enum _Phase { ready, listening, input, reveal }

class _TempoleScreenState extends State<TempoleScreen> with SingleTickerProviderStateMixin {
  static const Color _bg = Color(0xFF17112E);
  static const Color _accent = Color(0xFFFF7AC6);
  static const Color _good = Color(0xFF3DDC84);
  static const Color _bad = Color(0xFFFF5D73);

  /// Son dokunuştan bu kadar sonra tur eksik vuruşlarla kapanır
  static const Duration _idleLimit = Duration(milliseconds: 2500);

  late final TempoleGame _game;
  final SoundService _sound = SoundService();
  final Stopwatch _stopwatch = Stopwatch()..start();
  late final AnimationController _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 180));

  _Phase _phase = _Phase.ready;
  int _round = 0;
  int _beat = 0;
  bool _replayUsed = false;
  final List<int> _taps = [];
  final List<double> _scores = [];
  final List<double> _errors = [];
  Timer? _idleTimer;

  bool get _tr => LanguageService().isTurkish;
  TempoRound get _current => _game.rounds[_round];
  double get _total => _scores.fold(0.0, (a, b) => a + b);
  bool get _isKeep => _current.type == TempoRoundType.keep;

  @override
  void initState() {
    super.initState();
    _game = TempoleGame(widget.isDailyMode ? Random(DailyChallengeService.getSeededSeed('tempole')) : Random());
  }

  @override
  void dispose() {
    _idleTimer?.cancel();
    _pulse.dispose();
    super.dispose();
  }

  void _hit() {
    _sound.playPad(1);
    _pulse.reverse(from: 1);
  }

  Future<void> _listen() async {
    setState(() {
      _phase = _Phase.listening;
      _beat = 0;
    });
    await Future.delayed(const Duration(milliseconds: 500));
    final clock = Stopwatch()..start();
    for (final offset in _current.listen) {
      final wait = offset - clock.elapsedMilliseconds;
      if (wait > 0) await Future.delayed(Duration(milliseconds: wait));
      if (!mounted) return;
      _hit();
      setState(() => _beat++);
    }
    await Future.delayed(const Duration(milliseconds: 350));
    if (!mounted) return;
    setState(() {
      _phase = _Phase.input;
      _beat = 0;
    });
  }

  // Coinli tekrar yalnızca bilet modunda; Daily Run ve düello sıralamasını coin etkilemez
  bool get _ticketMode => widget.onGameComplete == null && !widget.isDailyMode;

  Future<void> _replay() async {
    if (_phase != _Phase.input || _replayUsed || _taps.isNotEmpty) return;
    final ok = await showCoinOffer(
      context,
      icon: Icons.replay_rounded,
      title: _tr ? 'Bir daha dinle' : 'Listen again',
      description: _tr ? 'Bu turun ritmini bir kez daha çalar.' : "Plays this round's beat one more time.",
      confirmLabel: _tr ? 'Dinle' : 'Listen',
      price: CoinService.replayPrice,
      item: 'tempole_replay',
    );
    if (!ok || !mounted || _phase != _Phase.input || _taps.isNotEmpty) return;
    _replayUsed = true;
    _listen();
  }

  /// Zaman, dokunuş olayının kendi damgasından alınır; kare gecikmesi puana yansımaz
  void _onPad(PointerDownEvent event) {
    if (_phase != _Phase.input) return;
    _hit();
    _taps.add(event.timeStamp.inMilliseconds);
    _idleTimer?.cancel();
    if (_taps.length >= _current.target.length) {
      _endRound();
      return;
    }
    _idleTimer = Timer(_idleLimit, _endRound);
    setState(() => _beat = _taps.length);
  }

  void _endRound() {
    if (!mounted || _phase != _Phase.input) return;
    _idleTimer?.cancel();
    final score = TempoleGame.roundScore(_current, _taps);
    score >= 14 ? _sound.playCorrect() : (score > 0 ? _sound.playFlip() : _sound.playError());
    setState(() {
      _phase = _Phase.reveal;
      _beat = _taps.length;
      _scores.add(score);
      _errors.add(TempoleGame.averageError(_current, _taps) ?? 0);
    });
  }

  void _next() {
    if (_round + 1 >= TempoleGame.totalRounds) {
      _finish();
      return;
    }
    _sound.playKeyTap();
    setState(() {
      _round++;
      _phase = _Phase.ready;
      _beat = 0;
      _replayUsed = false;
      _taps.clear();
    });
  }

  void _finish() {
    _stopwatch.stop();
    final score = _total;
    reportGameScore(
      gameId: 'tempole',
      isDailyMode: widget.isDailyMode,
      onGameComplete: widget.onGameComplete,
      score: score,
      durationMs: _stopwatch.elapsedMilliseconds,
      attempts: TempoleGame.totalRounds,
      maxAttempts: TempoleGame.totalRounds,
    );
    final avg = _errors.reduce((a, b) => a + b) / _errors.length;
    GameResultSheet.show(
      context,
      GameResultSheet(
        title: score >= 80 ? (_tr ? 'Metronom gibisin!' : 'Human metronome!') : (_tr ? 'Ritim tamam' : 'Beat complete'),
        headline: score.toStringAsFixed(0),
        caption: _tr ? 'Puan (100 üzerinden)' : 'Score (out of 100)',
        accent: _accent,
        isDailyRun: widget.onGameComplete != null,
        stats: [
          GameResultStat(_tr ? 'Ort. sapma' : 'Avg. error', '${avg.round()} ms'),
          GameResultStat(_tr ? 'Süre' : 'Time', '${(_stopwatch.elapsedMilliseconds / 1000).round()} sn'),
        ],
      ),
    );
  }

  String get _prompt {
    switch (_phase) {
      case _Phase.ready:
        return _isKeep
            ? (_tr
                  ? 'Sabit tempoyu dinle, sonra aynı hızda ${_current.target.length} kez dokun.'
                  : 'Listen to the steady beat, then tap ${_current.target.length} times at the same speed.')
            : (_tr ? 'Ritmi dinle, sonra aynen tekrar et.' : 'Listen to the rhythm, then repeat it exactly.');
      case _Phase.listening:
        return _tr ? 'Dinle...' : 'Listen...';
      case _Phase.input:
        return _taps.isEmpty ? (_tr ? 'Hazır olunca dokun' : 'Tap when ready') : (_tr ? 'Devam et!' : 'Keep going!');
      case _Phase.reveal:
        return _taps.isEmpty
            ? (_tr ? 'Dokunmadın' : 'No taps')
            : '+${_scores.last.toStringAsFixed(0)}  ·  ${_tr ? 'sapma' : 'error'} ${_errors.last.round()} ms';
    }
  }

  @override
  Widget build(BuildContext context) {
    return GameExitWrapper(
      gameId: 'tempole',
      isDailyMode: widget.isDailyMode,
      onGameComplete: widget.onGameComplete,
      child: Scaffold(
        backgroundColor: _bg,
        body: SafeArea(
          child: Column(
            children: [
              GameTopBar(
                title: 'Tempole',
                subtitle: _tr ? 'Ritmi tuttur' : 'Hit the beat',
                trailing: _total.toStringAsFixed(0),
                accent: _accent,
              ),
              RoundDots(total: TempoleGame.totalRounds, current: _round, done: _scores.length, accent: _accent),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: SizedBox(
                  height: 48,
                  child: Center(
                    child: Text(
                      _prompt,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              _buildBeatDots(),
              Expanded(child: _phase == _Phase.reveal ? _buildTimeline() : _buildPad()),
              _buildBottom(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBeatDots() {
    final count = _phase == _Phase.listening ? _current.listen.length : _current.target.length;
    return SizedBox(
      height: 14,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < count; i++)
            Container(
              width: 12,
              height: 12,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: i < _beat ? _accent : Colors.white.withValues(alpha: 0.14),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPad() {
    final active = _phase == _Phase.input;
    return LayoutBuilder(
      builder: (context, c) {
        final size = min(min(c.maxWidth - 64, c.maxHeight - 24), 300.0);
        return Center(
          child: Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: _onPad,
            child: AnimatedBuilder(
              animation: _pulse,
              builder: (context, _) {
                final v = Curves.easeOut.transform(_pulse.value);
                return Transform.scale(
                  scale: 1 + v * 0.08,
                  child: Container(
                    width: size,
                    height: size,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          Color.lerp(active ? _accent : const Color(0xFF4A3B7A), Colors.white, v * 0.6)!,
                          Color.lerp(active ? const Color(0xFFB83B8E) : const Color(0xFF2A2150), _accent, v)!,
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: _accent.withValues(alpha: 0.2 + v * 0.5),
                          blurRadius: 20 + v * 40,
                        ),
                      ],
                    ),
                    child: Icon(
                      active ? Icons.touch_app_rounded : Icons.graphic_eq_rounded,
                      color: Colors.white.withValues(alpha: 0.85),
                      size: size * 0.3,
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildTimeline() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: Center(
        child: Container(
          height: 150,
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _tr ? 'Hedef' : 'Target',
                style: GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white70),
              ),
              Expanded(
                child: CustomPaint(
                  size: Size.infinite,
                  painter: _TimelinePainter(
                    target: _current.target,
                    taps: TempoleGame.relative(_taps),
                    targetColor: _accent,
                    good: _good,
                    bad: _bad,
                    goodMs: TempoleGame.perfectMs * 2,
                  ),
                ),
              ),
              Text(
                _tr ? 'Senin' : 'Yours',
                style: GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white70),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottom() {
    Widget button(String label, VoidCallback? onTap, Color face, Color lip) => ChunkyButton(
      face: face,
      lip: lip,
      height: 56,
      onTap: onTap,
      child: Text(
        label,
        style: GoogleFonts.nunito(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white),
      ),
    );
    final Widget child;
    switch (_phase) {
      case _Phase.ready:
        child = button(_tr ? 'DİNLE' : 'LISTEN', _listen, _accent, const Color(0xFFB83B8E));
      case _Phase.listening:
        child = button(_tr ? 'DİNLE' : 'LISTEN', null, Colors.white24, Colors.white10);
      case _Phase.input:
        final canReplay = !_replayUsed && _taps.isEmpty;
        // Düğme yokken de yer kaplar; daire boyutu değişip ritmi şaşırtmasın
        child = !_ticketMode
            ? const SizedBox(height: 56)
            : ChunkyButton(
                face: canReplay ? const Color(0xFF4F8BFF) : Colors.white24,
                lip: canReplay ? const Color(0xFF2E5BC4) : Colors.white10,
                height: 56,
                onTap: canReplay ? _replay : null,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        _tr ? 'BİR DAHA DİNLE' : 'LISTEN AGAIN',
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.nunito(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white),
                      ),
                    ),
                    const SizedBox(width: 10),
                    const CoinIcon(size: 22),
                    const SizedBox(width: 4),
                    Text(
                      '${CoinService.replayPrice}',
                      style: GoogleFonts.nunito(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white),
                    ),
                  ],
                ),
              );
      case _Phase.reveal:
        child = button(
          _round + 1 >= TempoleGame.totalRounds ? (_tr ? 'SONUÇ' : 'RESULT') : (_tr ? 'SONRAKİ' : 'NEXT'),
          _next,
          _good,
          const Color(0xFF1E9E55),
        );
    }
    return Padding(padding: const EdgeInsets.fromLTRB(20, 8, 20, 20), child: child);
  }
}

/// Hedef vuruşlar üstte, oyuncunun dokunuşları altta; yakınsa yeşil, uzaksa kırmızı
class _TimelinePainter extends CustomPainter {
  final List<int> target;
  final List<int> taps;
  final Color targetColor;
  final Color good;
  final Color bad;
  final int goodMs;

  const _TimelinePainter({
    required this.target,
    required this.taps,
    required this.targetColor,
    required this.good,
    required this.bad,
    required this.goodMs,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final span = [if (target.isNotEmpty) target.last, if (taps.isNotEmpty) taps.last, 1].reduce(max);
    const inset = 8.0;
    double x(int ms) => inset + (size.width - inset * 2) * ms / span;
    final midTop = size.height * 0.3, midBottom = size.height * 0.7;
    final line = Paint()
      ..color = Colors.white.withValues(alpha: 0.15)
      ..strokeWidth = 2;
    canvas.drawLine(Offset(inset, midTop), Offset(size.width - inset, midTop), line);
    canvas.drawLine(Offset(inset, midBottom), Offset(size.width - inset, midBottom), line);

    final dot = Paint();
    for (final t in target) {
      canvas.drawCircle(Offset(x(t), midTop), 7, dot..color = targetColor);
    }
    for (var i = 0; i < taps.length; i++) {
      final off = i < target.length ? (taps[i] - target[i]).abs() : goodMs * 10;
      final color = Color.lerp(good, bad, ((off - goodMs) / (goodMs * 2)).clamp(0.0, 1.0))!;
      canvas.drawCircle(Offset(x(taps[i]), midBottom), 7, dot..color = color);
    }
  }

  @override
  bool shouldRepaint(covariant _TimelinePainter old) => old.taps != taps || old.target != target;
}
