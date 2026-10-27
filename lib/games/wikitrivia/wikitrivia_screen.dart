import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../widgets/game_exit_wrapper.dart';
import '../../widgets/game_result_sheet.dart';
import '../../services/sound_service.dart';
import '../../services/daily_challenge_service.dart';
import '../../services/language_service.dart';
import '../common/game_common.dart';
import 'wikitrivia_game.dart';
import 'wikitrivia_data.dart';

class WikitriviaScreen extends StatefulWidget {
  final bool isDailyMode;
  final void Function(double score, [int durationMs])? onGameComplete;
  const WikitriviaScreen({super.key, this.isDailyMode = true, this.onGameComplete});

  @override
  State<WikitriviaScreen> createState() => _WikitriviaScreenState();
}

class _WikitriviaScreenState extends State<WikitriviaScreen> {
  static const Color _bg = Color(0xFF1C1726);
  static const Color _accent = Color(0xFFFFB547);
  static const Color _paper = Color(0xFFF6EEDC);
  static const Color _ink = Color(0xFF3A2E22);
  static const Color _good = Color(0xFF3DDC84);
  static const Color _bad = Color(0xFFFF5D73);

  late final WikitriviaGame _game;
  final SoundService _sound = SoundService();
  final Stopwatch _stopwatch = Stopwatch()..start();
  final Map<HistoricalEvent, GlobalKey> _keys = {};

  /// Son yerleştirilen kart; kısa süre vurgulanır ve üstte sonucu gösterilir
  PlacementInfo? _last;
  bool _busy = false;
  int? _hoverSlot;
  Timer? _timer;

  bool get _tr => LanguageService().isTurkish;

  @override
  void initState() {
    super.initState();
    final pool = _tr ? defaultHistoricalEventsTr : defaultHistoricalEventsEn;
    final rng = widget.isDailyMode ? Random(DailyChallengeService.getSeededSeed('wikitrivia')) : Random();
    _game = WikitriviaGame(pool, rng);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  GlobalKey _keyOf(HistoricalEvent e) => _keys.putIfAbsent(e, GlobalKey.new);

  void _place(int slot) {
    if (_busy || _game.currentCard == null) return;
    final info = _game.place(slot);
    info.isCorrect ? _sound.playCorrect() : _sound.playError();
    setState(() {
      _last = info;
      _busy = true;
      _hoverSlot = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _keys[info.event]?.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          alignment: 0.5,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOut,
        );
      }
    });
    _timer = Timer(Duration(milliseconds: info.isCorrect ? 1000 : 1700), () {
      if (!mounted) return;
      if (_game.isGameOver) {
        _finish();
        return;
      }
      setState(() {
        _busy = false;
        _last = null;
      });
    });
  }

  void _finish() {
    _stopwatch.stop();
    final score = _game.score.toDouble();
    reportGameScore(
      gameId: 'wikitrivia',
      isDailyMode: widget.isDailyMode,
      onGameComplete: widget.onGameComplete,
      score: score,
      durationMs: _stopwatch.elapsedMilliseconds,
      attempts: _game.correct,
      maxAttempts: _game.deckTotal,
    );
    final String title;
    if (_game.isPerfect) {
      title = _tr ? 'Tarih ustası!' : 'History master!';
    } else if (_game.correct >= 7) {
      title = _tr ? 'Harika kronoloji' : 'Great chronology';
    } else {
      title = _tr ? 'Zaman çizelgen hazır' : 'Timeline complete';
    }
    GameResultSheet.show(
      context,
      GameResultSheet(
        title: title,
        headline: score.toStringAsFixed(0),
        caption: _tr ? 'Puan (100 üzerinden)' : 'Score (out of 100)',
        accent: _accent,
        isDailyRun: widget.onGameComplete != null,
        stats: [
          GameResultStat(_tr ? 'Doğru' : 'Correct', '${_game.correct}/${_game.deckTotal}'),
          GameResultStat(_tr ? 'Yanlış' : 'Wrong', '${_game.wrong}'),
          GameResultStat(_tr ? 'Süre' : 'Time', '${(_stopwatch.elapsedMilliseconds / 1000).round()} sn'),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GameExitWrapper(
      gameId: 'wikitrivia',
      isDailyMode: widget.isDailyMode,
      onGameComplete: widget.onGameComplete,
      child: Scaffold(
        backgroundColor: _bg,
        body: SafeArea(
          child: Column(
            children: [
              GameTopBar(
                title: 'Wikitrivia',
                subtitle: _tr ? 'Olayı zaman çizelgesine yerleştir' : 'Place the event on the timeline',
                trailing: '${_game.score}',
                accent: _accent,
              ),
              _buildStatus(),
              const SizedBox(height: 12),
              _buildCurrent(),
              const SizedBox(height: 10),
              Expanded(child: _buildTimeline()),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Can ve ilerleme ─────────────────────────────────────────────
  Widget _buildStatus() {
    final cardNo = min(_game.placed + (_busy ? 0 : 1), _game.deckTotal);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          for (var i = 0; i < WikitriviaGame.maxLives; i++)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
                child: Icon(
                  i < _game.remainingLives ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                  key: ValueKey(i < _game.remainingLives),
                  color: i < _game.remainingLives ? _bad : Colors.white24,
                  size: 24,
                ),
              ),
            ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _tr ? 'Kart $cardNo/${_game.deckTotal}' : 'Card $cardNo/${_game.deckTotal}',
              style: GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white70),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Üstteki kart (sıradaki ya da son sonuç) ─────────────────────
  Widget _buildCurrent() {
    final last = _last;
    final card = _game.currentCard;
    Widget child;
    if (last != null) {
      final color = last.isCorrect ? _good : _bad;
      child = _bigCard(
        key: ValueKey('r${last.event.title}'),
        event: last.event,
        border: color,
        footer: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(last.isCorrect ? Icons.check_circle_rounded : Icons.cancel_rounded, color: color, size: 20),
            const SizedBox(width: 6),
            Text(
              last.isCorrect
                  ? '${_tr ? 'Doğru!' : 'Correct!'}  +${WikitriviaGame.pointsPerCard}'
                  : (_tr ? 'Yanlış, doğru yerine kondu' : 'Wrong, moved to its spot'),
              style: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w900, color: color),
            ),
            const SizedBox(width: 10),
            _yearChip(last.event.year, color),
          ],
        ),
      );
    } else if (card != null) {
      final face = _bigCard(event: card, border: _accent, footer: _yearChip(null, _accent));
      child = Draggable<HistoricalEvent>(
        key: ValueKey('c${card.title}'),
        data: card,
        feedback: Material(
          color: Colors.transparent,
          child: SizedBox(
            width: MediaQuery.sizeOf(context).width - 80,
            child: Opacity(
              opacity: 0.95,
              child: _bigCard(event: card, border: _accent, footer: null, compact: true),
            ),
          ),
        ),
        childWhenDragging: Opacity(opacity: 0.35, child: face),
        onDragEnd: (_) => setState(() => _hoverSlot = null),
        child: face,
      );
    } else {
      child = const SizedBox(height: 120);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 280),
        transitionBuilder: (c, a) => FadeTransition(
          opacity: a,
          child: SlideTransition(
            position: Tween(begin: const Offset(0, -0.15), end: Offset.zero).animate(a),
            child: c,
          ),
        ),
        child: child,
      ),
    );
  }

  Widget _bigCard({
    Key? key,
    required HistoricalEvent event,
    required Color border,
    required Widget? footer,
    bool compact = false,
  }) {
    return Container(
      key: key,
      width: double.infinity,
      constraints: BoxConstraints(minHeight: compact ? 0 : 120),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
      decoration: BoxDecoration(
        color: _paper,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border, width: 3),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 16, offset: const Offset(0, 6))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            event.title,
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.nunito(fontSize: 17, fontWeight: FontWeight.w800, color: _ink, height: 1.25),
          ),
          if (footer != null) ...[const SizedBox(height: 12), footer],
        ],
      ),
    );
  }

  Widget _yearChip(int? year, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.6), width: 1.5),
      ),
      child: Text(
        year == null ? (_tr ? '? Yıl' : '? Year') : WikitriviaGame.formatYear(year, _tr),
        style: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w900, color: _ink),
      ),
    );
  }

  // ─── Dikey zaman çizelgesi ───────────────────────────────────────
  Widget _buildTimeline() {
    final canPlace = !_busy && _game.currentCard != null;
    final items = <Widget>[];
    for (var i = 0; i <= _game.timeline.length; i++) {
      items.add(_buildSlot(i, canPlace));
      if (i < _game.timeline.length) items.add(_buildEvent(_game.timeline[i]));
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.04), borderRadius: BorderRadius.circular(22)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: ListView(padding: const EdgeInsets.symmetric(vertical: 10), children: items),
      ),
    );
  }

  /// Sol sütun: yıl, orta sütun: çizgi, sağ: içerik. Satırlar arasında çizgi kesintisiz devam eder.
  Widget _rail({required Widget left, required Widget right, bool dot = false, Color dotColor = _accent}) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 70,
            child: Align(
              alignment: Alignment.centerRight,
              child: FittedBox(fit: BoxFit.scaleDown, child: left),
            ),
          ),
          SizedBox(
            width: 28,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(width: 3, color: Colors.white.withValues(alpha: 0.14)),
                if (dot)
                  Container(
                    width: 13,
                    height: 13,
                    decoration: BoxDecoration(
                      color: dotColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: _bg, width: 2.5),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: Padding(padding: const EdgeInsets.only(right: 12), child: right),
          ),
        ],
      ),
    );
  }

  Widget _buildEvent(HistoricalEvent e) {
    final last = _last;
    final isNew = last != null && identical(last.event, e);
    final color = isNew ? (last.isCorrect ? _good : _bad) : _accent;
    return KeyedSubtree(
      key: _keyOf(e),
      child: _rail(
        dot: true,
        dotColor: color,
        left: Text(
          WikitriviaGame.formatYear(e.year, _tr),
          style: GoogleFonts.nunito(fontSize: 15, fontWeight: FontWeight.w900, color: isNew ? color : Colors.white),
        ),
        right: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(vertical: 3),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isNew ? color.withValues(alpha: 0.18) : Colors.white.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: isNew ? color : Colors.transparent, width: 2),
          ),
          child: Text(
            e.title,
            style: GoogleFonts.nunito(fontSize: 13.5, fontWeight: FontWeight.w700, color: Colors.white, height: 1.25),
          ),
        ),
      ),
    );
  }

  Widget _buildSlot(int slot, bool canPlace) {
    if (!canPlace) return _rail(left: const SizedBox(), right: const SizedBox(height: 8));
    return DragTarget<HistoricalEvent>(
      onWillAcceptWithDetails: (_) {
        setState(() => _hoverSlot = slot);
        return true;
      },
      onLeave: (_) {
        if (_hoverSlot == slot) setState(() => _hoverSlot = null);
      },
      onAcceptWithDetails: (_) => _place(slot),
      builder: (context, candidate, rejected) {
        final hover = _hoverSlot == slot;
        return _rail(
          left: const SizedBox(),
          right: GestureDetector(
            onTap: () => _place(slot),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              height: hover ? 52 : 38,
              margin: const EdgeInsets.symmetric(vertical: 4),
              decoration: BoxDecoration(
                color: _accent.withValues(alpha: hover ? 0.3 : 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _accent.withValues(alpha: hover ? 0.9 : 0.45), width: 1.5),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.add_rounded, color: _accent, size: 18),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      _slotLabel(slot),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.w800, color: _accent),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _slotLabel(int slot) {
    final t = _game.timeline;
    if (slot == 0) return _tr ? 'En eski: buraya' : 'Earliest: here';
    if (slot == t.length) return _tr ? 'En yeni: buraya' : 'Latest: here';
    return _tr ? 'Buraya yerleştir' : 'Place here';
  }
}
