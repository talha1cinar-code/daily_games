import 'dart:async';
import 'package:flutter/material.dart';
import '../../widgets/game_exit_wrapper.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/daily_challenge_service.dart';
import '../../services/stats_service.dart';
import '../../services/ticket_service.dart';
import '../../services/leaderboard_service.dart';
import 'linele_game.dart';
import '../../services/language_service.dart';
import '../../services/app_strings.dart';

class LineleScreen extends StatefulWidget {
  final bool isDailyMode;
  final void Function(double score, [int durationMs])? onGameComplete;
  const LineleScreen({super.key, this.isDailyMode = false, this.onGameComplete});

  @override
  State<LineleScreen> createState() => _LineleScreenState();
}

class _LineleScreenState extends State<LineleScreen>
    with SingleTickerProviderStateMixin {
  LineleGame? _game;
  bool _isLoading = true;
  DateTime? _startTime;
  Timer? _timer;
  Duration _elapsed = Duration.zero;

  // Key for the grid so we can get its RenderBox
  final GlobalKey _gridKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _initGame();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _initGame() async {
    LineleGame game;

    if (widget.isDailyMode) {
      final seed = DailyChallengeService.getSeededLineleSeed();
      game = LineleGame.generateMaze(size: 12, seed: seed);
    } else {
      game = LineleGame.generateMaze(size: 12);
    }

    setState(() {
      _game = game;
      _isLoading = false;
      _startTime = DateTime.now();
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_game != null && !_game!.isComplete && mounted) {
        setState(() {
          _elapsed = DateTime.now().difference(_startTime!);
        });
      }
    });
  }

  /// Convert a screen-space [Offset] (relative to the grid widget)
  /// into a grid [Point].
  Point? _offsetToPoint(Offset local) {
    final game = _game;
    if (game == null) return null;

    final box = _gridKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return null;

    final size = box.size;
    final cellW = size.width / game.gridSize;
    final cellH = size.height / game.gridSize;

    final x = (local.dx / cellW).floor();
    final y = (local.dy / cellH).floor();

    if (x < 0 || y < 0 || x >= game.gridSize || y >= game.gridSize) {
      return null;
    }
    return Point(x, y);
  }

  void _onPanDown(DragDownDetails d) {
    final p = _offsetToPoint(d.localPosition);
    if (p != null && _game != null && _game!.tapOrDrag(p)) {
      setState(() {});
      _maybeFinish();
    }
  }

  void _onPanUpdate(DragUpdateDetails d) {
    final p = _offsetToPoint(d.localPosition);
    if (p != null && _game != null && _game!.tapOrDrag(p)) {
      setState(() {});
      _maybeFinish();
    }
  }

  void _maybeFinish() {
    if (_game != null && _game!.isComplete) {
      _timer?.cancel();
      final ms = DateTime.now().difference(_startTime!).inMilliseconds;
      final isWin = _game!.isWin;

      if (widget.onGameComplete != null) {
        final score = LeaderboardService.calculateLeaderboardScore(
          gameId: 'linele',
          isWin: isWin,
          durationMs: ms,
        );
        widget.onGameComplete!(score, ms);
      } else if (widget.isDailyMode) {
        StatsService().saveDailyStat(
          gameId: 'linele',
          isWin: isWin,
          attempts: 1,
          maxAttempts: 1,
          score: 0,
          durationMs: ms,
          targetValue: '${_game!.gridSize}x${_game!.gridSize}',
        );

        TicketService().markDailyPlayed('linele');
        LeaderboardService().submitScore(
          gameId: 'linele',
          score: LeaderboardService.calculateLeaderboardScore(
            gameId: 'linele',
            isWin: isWin,
            durationMs: ms,
          ),
          attempts: 1,
          maxAttempts: 1,
          durationMs: ms,
          isWin: isWin,
        );
      }

      if (isWin) {
        _showWinDialog();
      } else {
        _showLoseDialog();
      }
    }
  }

  void _showWinDialog() {
    final mm = _elapsed.inMinutes.toString().padLeft(2, '0');
    final ss = (_elapsed.inSeconds % 60).toString().padLeft(2, '0');

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1B1B2F),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          '${AppStrings.congratulations} 🎉',
          style: GoogleFonts.nunito(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
        content: Text(
          LanguageService().isTurkish ? 'Labirentten başarıyla çıktın!\nSüre: $mm:$ss' : 'You escaped the maze!\nTime: $mm:$ss',
          style: GoogleFonts.nunito(color: Colors.white70, fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: Text(
              LanguageService().isTurkish ? 'Devam Et' : 'Continue',
              style: GoogleFonts.nunito(
                color: Colors.blueAccent,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showLoseDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1B1B2F),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          LanguageService().currentLanguage == 'tr' ? 'Oyun Bitti' : 'Game Over',
          style: GoogleFonts.nunito(
            color: Colors.redAccent,
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
        content: Text(
          LanguageService().isTurkish ? 'Çıkmaz yola girdin! Geri dönüş yok.' : 'You hit a dead end! No way back.',
          style: GoogleFonts.nunito(color: Colors.white70, fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: Text(
              LanguageService().isTurkish ? 'Çık' : 'Exit',
              style: GoogleFonts.nunito(
                color: Colors.redAccent,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _resetGame() {
    _game?.reset();
    setState(() {
      _startTime = DateTime.now();
      _elapsed = Duration.zero;
    });
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_game != null && !_game!.isComplete && mounted) {
        setState(() {
          _elapsed = DateTime.now().difference(_startTime!);
        });
      }
    });
  }

  // =================================================================
  //  BUILD
  // =================================================================

  @override
  Widget build(BuildContext context) {
    final mm = _elapsed.inMinutes.toString().padLeft(2, '0');
    final ss = (_elapsed.inSeconds % 60).toString().padLeft(2, '0');

    return GameExitWrapper(gameId: 'linele', isDailyMode: widget.isDailyMode, onGameComplete: widget.onGameComplete, child: Scaffold(
        backgroundColor: const Color(0xFF151522),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          title: Text(
            widget.isDailyMode ? (LanguageService().isTurkish ? 'Linele (Günlük)' : 'Linele (Daily)') : 'Linele',
            style: GoogleFonts.nunito(fontWeight: FontWeight.w800, fontSize: 24),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
            onPressed: () => Navigator.maybePop(context),
          ),
          actions: [
            // Only allow reset if not daily mode, or allow reset if you want?
            // The prompt says "çizgi çekerken bu çizgi geri alınamayacak", so reset might be cheating if daily mode allows retry.
            // Let's keep reset button, but maybe disable if isComplete.
            if (!widget.isDailyMode)
              IconButton(
                icon: const Icon(Icons.refresh_rounded),
                tooltip: LanguageService().isTurkish ? 'Sıfırla' : 'Reset',
                onPressed: _resetGame,
              ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.blueAccent))
          : SafeArea(
              child: Column(
                children: [
                  const SizedBox(height: 16),

                  // ── Timer ──
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.timer_outlined,
                            color: Colors.white70, size: 22),
                        const SizedBox(width: 8),
                        Text(
                          '$mm:$ss',
                          style: GoogleFonts.nunito(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const Spacer(),

                  // ── Game Board ──
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: GestureDetector(
                        key: _gridKey,
                        onPanDown: _onPanDown,
                        onPanUpdate: _onPanUpdate,
                        child: CustomPaint(
                          painter: _LinelePainter(game: _game!),
                          child: Container(), // needed to fill the area
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ── Info Text ──
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      LanguageService().currentLanguage == 'tr' ? 'S yeşil başlangıç noktasıdır.\nKırmızı noktalardan birine ulaş, çıkmaz yola girme!' : 'S is the green start point.\nReach one of the red points, avoid dead ends!',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.nunito(
                        color: Colors.white38,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  
                  const Spacer(),
                ],
              ),
            ),
      ));
  }
}

// ===================================================================
//  PAINTER
// ===================================================================

class _LinelePainter extends CustomPainter {
  final LineleGame game;

  _LinelePainter({required this.game});

  @override
  void paint(Canvas canvas, Size size) {
    final cellW = size.width / game.gridSize;
    final cellH = size.height / game.gridSize;
    final radius = cellW * 0.06;

    // ---------- paints ----------
    final cellFill = Paint()
      ..color = const Color(0xFF1E1E36)
      ..style = PaintingStyle.fill;

    final visitedFill = Paint()
      ..color = Colors.blueAccent.withValues(alpha: 0.25)
      ..style = PaintingStyle.fill;

    final wallPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;

    final linePaint = Paint()
      ..color = Colors.blueAccent
      ..style = PaintingStyle.stroke
      ..strokeWidth = cellW * 0.28
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // ---------- draw cells ----------
    for (int y = 0; y < game.gridSize; y++) {
      for (int x = 0; x < game.gridSize; x++) {
        final rect = RRect.fromLTRBR(
          x * cellW,
          y * cellH,
          (x + 1) * cellW,
          (y + 1) * cellH,
          Radius.circular(radius),
        );
        final p = Point(x, y);

        canvas.drawRRect(rect, cellFill);

        // Highlight visited cells
        if (game.currentPath.contains(p)) {
          canvas.drawRRect(rect, visitedFill);
        }
      }
    }

    // ---------- draw walls ----------
    for (final wall in game.wallEdges) {
      // Wall between p1 and p2
      final p1 = wall.p1;
      final p2 = wall.p2;

      if (p1.x == p2.x) {
        // Horizontal wall
        final yLine = (p1.y > p2.y ? p1.y : p2.y) * cellH;
        final xStart = p1.x * cellW;
        final xEnd = (p1.x + 1) * cellW;
        canvas.drawLine(Offset(xStart, yLine), Offset(xEnd, yLine), wallPaint);
      } else {
        // Vertical wall
        final xLine = (p1.x > p2.x ? p1.x : p2.x) * cellW;
        final yStart = p1.y * cellH;
        final yEnd = (p1.y + 1) * cellH;
        canvas.drawLine(Offset(xLine, yStart), Offset(xLine, yEnd), wallPaint);
      }
    }
    
    // Draw grid border
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), wallPaint);

    // ---------- draw start & exits ----------
    final textPainter = TextPainter(
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    );

    void drawMarker(Point p, String text, Color color) {
      final cx = p.x * cellW + cellW / 2;
      final cy = p.y * cellH + cellH / 2;
      final r = cellW * 0.32;

      canvas.drawCircle(Offset(cx, cy), r, Paint()..color = color.withValues(alpha: 0.2));
      canvas.drawCircle(
        Offset(cx, cy),
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..color = color
          ..strokeWidth = 2,
      );

      textPainter.text = TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: cellH * 0.35,
          fontWeight: FontWeight.bold,
          fontFamily: 'Nunito',
        ),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(cx - textPainter.width / 2, cy - textPainter.height / 2),
      );
    }

    drawMarker(game.startPoint, 'S', Colors.greenAccent);
    for (final exit in game.exits) {
      drawMarker(exit, 'E', Colors.redAccent);
    }

    // ---------- draw path line ----------
    if (game.currentPath.length >= 2) {
      final path = Path();
      for (int i = 0; i < game.currentPath.length; i++) {
        final p = game.currentPath[i];
        final cx = p.x * cellW + cellW / 2;
        final cy = p.y * cellH + cellH / 2;
        if (i == 0) {
          path.moveTo(cx, cy);
        } else {
          path.lineTo(cx, cy);
        }
      }
      canvas.drawPath(path, linePaint);
    }

    // ---------- head dot (last path point) ----------
    if (game.currentPath.isNotEmpty) {
      final last = game.currentPath.last;
      final cx = last.x * cellW + cellW / 2;
      final cy = last.y * cellH + cellH / 2;

      canvas.drawCircle(
        Offset(cx, cy),
        cellW * 0.18,
        Paint()..color = Colors.white,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _LinelePainter old) => true;
}
