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
import '../../services/app_strings.dart';
import '../../services/coin_service.dart';
import '../../widgets/coin_offer_dialog.dart';
import 'stackle_game.dart';

class StackleScreen extends StatefulWidget {
  final bool isDailyMode;
  final void Function(double score, [int durationMs])? onGameComplete;
  const StackleScreen({super.key, this.isDailyMode = true, this.onGameComplete});

  @override
  State<StackleScreen> createState() => _StackleScreenState();
}

class _Fall {
  final StackBlock block;
  final int floor;
  final int colorIndex;
  double dy = 0, vy = 0, angle = 0;
  final double spin;
  _Fall(this.block, this.floor, this.colorIndex, this.spin);
}

class _StackleScreenState extends State<StackleScreen> with SingleTickerProviderStateMixin {
  static const double blockHeight = 26;

  final StackleGame _game = StackleGame();
  final SoundService _sound = SoundService();
  final Stopwatch _stopwatch = Stopwatch();
  late final Ticker _ticker;
  late final double _baseHue;

  Duration _last = Duration.zero;
  double _x = -0.05;
  int _dir = 1;
  final List<_Fall> _falls = [];
  double _camera = 0;
  Size _size = Size.zero;
  bool _started = false;
  int _bestCombo = 0;
  bool _continued = false;

  // Coin ile devam yalnızca bilet modunda; Daily Run sıralamasını etkilemez
  bool get _ticketMode => widget.onGameComplete == null && !widget.isDailyMode;

  // Mükemmel yerleşim efekti
  double _ringT = 1;
  String? _comboLabel;

  bool get _tr => LanguageService().isTurkish;

  @override
  void initState() {
    super.initState();
    final rng = widget.isDailyMode
        ? Random(DailyChallengeService.getSeededStackleSeed())
        : Random();
    _baseHue = rng.nextDouble() * 360;
    _ticker = createTicker(_onTick)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  double get _groundY => _size.height - 90;

  Color _colorFor(int i) =>
      HSVColor.fromAHSV(1, (_baseHue + i * 9) % 360, 0.55, 0.95).toColor();

  void _onTick(Duration elapsed) {
    final dt = min((elapsed - _last).inMicroseconds / 1e6, 0.05);
    _last = elapsed;
    if (_size == Size.zero) return;

    if (_started && !_game.isOver) {
      final w = _game.top.width;
      _x += _dir * _game.speed * dt;
      if (_x > 1.1 - w) {
        _x = 1.1 - w;
        _dir = -1;
      } else if (_x < -0.1) {
        _x = -0.1;
        _dir = 1;
      }
    }

    for (final f in _falls) {
      f.vy += 2600 * dt;
      f.dy += f.vy * dt;
      f.angle += f.spin * dt;
    }
    _falls.removeWhere((f) => f.dy > _size.height + 400);

    final topY = _groundY - (_game.placed.length + 1) * blockHeight;
    final target = max(0.0, _size.height * 0.38 - topY);
    _camera += (target - _camera) * min(1.0, dt * 6);
    if (_ringT < 1) _ringT = min(1, _ringT + dt * 2.2);

    setState(() {});
  }

  void _onTap() {
    if (_game.isOver) return;
    if (!_started) {
      _started = true;
      _stopwatch.start();
      return;
    }
    final floor = _game.placed.length;
    final res = _game.place(_x);
    switch (res.outcome) {
      case PlaceOutcome.perfect:
        _sound.playFlip();
        _ringT = 0;
        _bestCombo = max(_bestCombo, _game.combo);
        _comboLabel = _game.combo > 1
            ? '${_tr ? 'Mükemmel' : 'Perfect'} ×${_game.combo}'
            : (_tr ? 'Mükemmel!' : 'Perfect!');
        break;
      case PlaceOutcome.placed:
        _sound.playKeyTap();
        _comboLabel = null;
        _falls.add(_Fall(res.chunk!, floor, floor, (_x < _game.placed[floor - 1].left ? -1 : 1) * 2.0));
        break;
      case PlaceOutcome.miss:
        _sound.playError();
        _comboLabel = null;
        _falls.add(_Fall(res.chunk!, floor, floor, _dir * 1.5));
        if (_ticketMode && !_continued && _game.floors > 0) {
          _offerContinue();
        } else {
          _finish();
        }
        return;
    }
    // Sonraki blok karşı taraftan gelir
    final w = _game.top.width;
    if (_game.placed.length.isEven) {
      _x = -0.1;
      _dir = 1;
    } else {
      _x = 1.1 - w;
      _dir = -1;
    }
  }

  Future<void> _offerContinue() async {
    await Future.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    final ok = await showCoinOffer(
      context,
      icon: Icons.layers_rounded,
      title: AppStrings.secondChance,
      description: AppStrings.secondChanceDesc,
      confirmLabel: AppStrings.keepGoing,
      price: CoinService.extraLifePrice,
      item: 'stackle_continue',
    );
    if (!mounted) return;
    if (!ok) {
      _finish();
      return;
    }
    _continued = true;
    setState(() {
      _game.isOver = false;
      _game.combo = 0;
      _x = -0.1;
      _dir = 1;
    });
  }

  void _finish() {
    _stopwatch.stop();
    final durationMs = _stopwatch.elapsedMilliseconds;
    final score = _game.score;
    _saveScore(score, durationMs);
    Future.delayed(const Duration(milliseconds: 1100), () {
      if (!mounted) return;
      _sound.playGameEnd(score);
      GameResultSheet.show(
        context,
        GameResultSheet(
          title: _game.floors >= 30
              ? (_tr ? 'Gökdelen!' : 'Skyscraper!')
              : (_tr ? 'Kule yıkıldı' : 'Tower toppled'),
          headline: '${_game.floors}',
          caption: _tr ? 'Kat' : 'Floors',
          accent: _colorFor(_game.floors),
          isDailyRun: widget.onGameComplete != null,
          stats: [
            GameResultStat(_tr ? 'Puan' : 'Score', score.toStringAsFixed(0)),
            GameResultStat(_tr ? 'Mükemmel' : 'Perfect', '${_game.perfects}'),
            GameResultStat(_tr ? 'En uzun kombo' : 'Best combo', '$_bestCombo'),
          ],
        ),
      );
    });
  }

  void _saveScore(double score, int durationMs) {
    if (widget.onGameComplete != null) {
      widget.onGameComplete!(score, durationMs);
    } else if (widget.isDailyMode) {
      TicketService().markDailyPlayed('stackle');
      StatsService().saveDailyStat(
        gameId: 'stackle',
        isWin: _game.floors > 0,
        score: score,
        attempts: _game.floors,
        durationMs: durationMs,
      );
      LeaderboardService().submitScore(
        gameId: 'stackle',
        score: score,
        attempts: _game.floors,
        durationMs: durationMs,
        isWin: _game.floors > 0,
      );
    } else {
      PersonalBestService().submit('stackle', score);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hue = (_baseHue + _game.floors * 9) % 360;
    return GameExitWrapper(
      gameId: 'stackle',
      isDailyMode: widget.isDailyMode,
      onGameComplete: widget.onGameComplete,
      child: Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                HSVColor.fromAHSV(1, hue, 0.45, 0.28).toColor(),
                const Color(0xFF0E0E14),
              ],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                _buildTopBar(),
                Expanded(
                  child: LayoutBuilder(builder: (context, constraints) {
                    _size = Size(constraints.maxWidth, constraints.maxHeight);
                    return GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTapDown: (_) => _onTap(),
                      child: Stack(
                        children: [
                          CustomPaint(
                            size: _size,
                            painter: _StackPainter(
                              game: _game,
                              movingLeft: _x,
                              showMoving: !_game.isOver,
                              falls: _falls,
                              camera: _camera,
                              groundY: _groundY,
                              blockHeight: blockHeight,
                              colorFor: _colorFor,
                              ringT: _ringT,
                            ),
                          ),
                          Positioned(
                            top: 24,
                            left: 0,
                            right: 0,
                            child: Column(
                              children: [
                                Text(
                                  '${_game.floors}',
                                  style: GoogleFonts.nunito(
                                    fontSize: 64,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white.withValues(alpha: 0.9),
                                  ),
                                ),
                                AnimatedOpacity(
                                  opacity: _comboLabel != null && _ringT < 1 ? 1 : 0,
                                  duration: const Duration(milliseconds: 200),
                                  child: Text(
                                    _comboLabel ?? '',
                                    style: GoogleFonts.nunito(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (!_started)
                            Positioned(
                              left: 0,
                              right: 0,
                              bottom: 140,
                              child: Text(
                                _tr ? 'Bloğu bırakmak için dokun\nBaşlamak için dokun' : 'Tap to drop the block\nTap to start',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.nunito(fontSize: 16, height: 1.5, color: Colors.white70),
                              ),
                            ),
                        ],
                      ),
                    );
                  }),
                ),
              ],
            ),
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
              Text('Stackle',
                  style: GoogleFonts.nunito(fontSize: 24, fontWeight: FontWeight.w800, color: Colors.white)),
              Text(_tr ? 'Gökyüzüne kadar' : 'All the way up',
                  style: GoogleFonts.nunito(fontSize: 12, color: Colors.white54)),
            ],
          ),
          const Spacer(),
          Text(
            '${_game.score.toStringAsFixed(0)} ${_tr ? 'puan' : 'pts'}',
            style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white70),
          ),
        ],
      ),
    );
  }
}

class _StackPainter extends CustomPainter {
  final StackleGame game;
  final double movingLeft;
  final bool showMoving;
  final List<_Fall> falls;
  final double camera;
  final double groundY;
  final double blockHeight;
  final Color Function(int) colorFor;
  final double ringT;

  _StackPainter({
    required this.game,
    required this.movingLeft,
    required this.showMoving,
    required this.falls,
    required this.camera,
    required this.groundY,
    required this.blockHeight,
    required this.colorFor,
    required this.ringT,
  });

  void _block(Canvas canvas, Rect r, Color color) {
    canvas.drawRect(r, Paint()..color = color);
    // Üst yüz ışığı ve alt gölge, düz dikdörtgene biraz derinlik verir
    canvas.drawRect(
      Rect.fromLTWH(r.left, r.top, r.width, 5),
      Paint()..color = Color.lerp(color, Colors.white, 0.35)!,
    );
    canvas.drawRect(
      Rect.fromLTWH(r.left, r.bottom - 3, r.width, 3),
      Paint()..color = Color.lerp(color, Colors.black, 0.25)!,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    double yFor(int floor) => groundY - (floor + 1) * blockHeight + camera;

    // Zemin
    canvas.drawRect(
      Rect.fromLTWH(0, yFor(0) + blockHeight, w, size.height),
      Paint()..color = Colors.black.withValues(alpha: 0.35),
    );

    for (var i = 0; i < game.placed.length; i++) {
      final y = yFor(i);
      if (y > size.height || y < -blockHeight) continue;
      final b = game.placed[i];
      _block(canvas, Rect.fromLTWH(b.left * w, y, b.width * w, blockHeight), colorFor(i));
    }

    if (showMoving) {
      final floor = game.placed.length;
      _block(
        canvas,
        Rect.fromLTWH(movingLeft * w, yFor(floor), game.top.width * w, blockHeight),
        colorFor(floor),
      );
    }

    for (final f in falls) {
      final r = Rect.fromLTWH(f.block.left * w, yFor(f.floor) + f.dy, f.block.width * w, blockHeight);
      canvas.save();
      canvas.translate(r.center.dx, r.center.dy);
      canvas.rotate(f.angle);
      _block(canvas, Rect.fromCenter(center: Offset.zero, width: r.width, height: r.height), colorFor(f.colorIndex));
      canvas.restore();
    }

    // Mükemmel yerleşimde genişleyen çerçeve
    if (ringT < 1 && game.placed.length > 1) {
      final i = game.placed.length - 1;
      final b = game.placed[i];
      final grow = 18 * ringT;
      canvas.drawRect(
        Rect.fromLTWH(b.left * w - grow, yFor(i) - grow, b.width * w + grow * 2, blockHeight + grow * 2),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..color = Colors.white.withValues(alpha: 1 - ringT),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _StackPainter old) => true;
}
