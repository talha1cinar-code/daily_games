import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math' as math;
import 'dart:async';
import '../services/daily_run_service.dart';
import '../services/sound_service.dart';
import '../services/ad_service.dart';
import '../services/app_strings.dart';
import '../widgets/logo_background.dart';
import 'leaderboard_screen.dart';
import '../games/wordle/wordle_screen.dart';
import '../games/wikitrivia/wikitrivia_screen.dart';
import '../games/nerdle/nerdle_screen.dart';
import '../games/worldle/worldle_screen.dart';
import '../games/rgble/rgble_screen.dart';
import '../games/sound/sound_screen.dart';
import '../games/timele/timele_screen.dart';
import '../games/linele/linele_screen.dart';
import '../games/huedle/huedle_screen.dart';
import '../games/fille/fille_screen.dart';
import '../games/memorle/memorle_screen.dart';
import '../games/reactle/reactle_screen.dart';

class DailyRunScreen extends StatefulWidget {
  const DailyRunScreen({super.key});

  @override
  State<DailyRunScreen> createState() => _DailyRunScreenState();
}

class _DailyRunScreenState extends State<DailyRunScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  late AnimationController _slideController;
  late Animation<double> _slideAnimation;
  Timer? _timer;
  Duration? _timeLeft;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _slideAnimation = CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutBack,
    );

    _fadeController.forward();
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) _slideController.forward();
    });

    _updateTimer();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _updateTimer());
  }

  void _updateTimer() {
    final now = DailyRunService.turkeyNow;
    DateTime nextReset;
    if (now.hour < 17) {
      nextReset = DateTime.utc(now.year, now.month, now.day, 17);
    } else {
      nextReset = DateTime.utc(now.year, now.month, now.day + 1, 0);
    }
    
    if (mounted) {
      setState(() {
        _timeLeft = nextReset.difference(now);
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  void _startGame(String gameId) {
    SoundService().playKeyTap();
    DailyRunService().markGameStarted(gameId);

    Widget screen = _buildGameScreen(gameId);
    SoundService().enterMiniGame();

    Navigator.of(context)
        .push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => screen,
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
    )
        .then((_) {
      if (mounted) {
        SoundService().exitMiniGame();
        setState(() {});

        final progress = DailyRunService().getProgress();
        if (progress.isCompleted) {
          AdService().showInterstitialAd(
            onAdClosed: () {
              if (mounted) _showCompletionDialog();
            }
          );
        } else if (progress.currentGameIndex == 5) {
          // 5. oyundan sonra reklam göster (index 5 olunca 5 oyun bitmiş demektir)
          AdService().showInterstitialAd();
        }
      }
    });
  }

  Widget _buildGameScreen(String gameId) {
    void onComplete(double score, [int durationMs = 0]) {
      DailyRunService().saveGameScore(gameId, score, durationMs);
    }

    switch (gameId) {
      case 'wordle': return WordleScreen(isDailyMode: true, onGameComplete: onComplete);
      case 'wikitrivia': return WikitriviaScreen(isDailyMode: true, onGameComplete: onComplete);
      case 'rgble': return RgbleScreen(isDailyMode: true, onGameComplete: onComplete);
      case 'nerdle': return NerdleScreen(isDailyMode: true, onGameComplete: onComplete);
      case 'linele': return LineleScreen(isDailyMode: true, onGameComplete: onComplete);
      case 'worldle': return WorldleScreen(isDailyMode: true, onGameComplete: onComplete);
      case 'sound': return SoundScreen(isDailyMode: true, onGameComplete: onComplete);
      case 'memorle': return MemorleScreen(isDailyMode: true, onGameComplete: onComplete);
      case 'huedle': return HuedleScreen(isDailyMode: true, onGameComplete: onComplete);
      case 'fille': return FilleScreen(isDailyMode: true, onGameComplete: onComplete);
      case 'timele': return TimeleScreen(isDailyMode: true, onGameComplete: onComplete);
      case 'reactle': return ReactleScreen(isDailyMode: true, onGameComplete: onComplete);
      default: return const SizedBox();
    }
  }

  void _showLeaderboard(String gameId, String gameName) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => LeaderboardScreen(
          gameId: gameId,
          gameName: gameName,
        ),
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
    );
  }

  void _showDailyRunLeaderboard() {
    final slot = DailyRunService.currentRunSlot();
    final gameId = 'daily_run_${slot == 1 ? "morning" : "evening"}';
    final name = AppStrings.dailyRunSlotName(slot);
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => LeaderboardScreen(
          gameId: gameId,
          gameName: name,
        ),
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
    );
  }

  void _showCompletionDialog() {
    final totalScore = DailyRunService().getTotalScore();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          backgroundColor: const Color(0xFF1B1B2F),
          contentPadding: const EdgeInsets.all(28),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 500),
                curve: Curves.elasticOut,
                builder: (context, value, child) => Transform.scale(scale: value, child: child),
                child: const Text('🏆', style: TextStyle(fontSize: 64)),
              ),
              const SizedBox(height: 16),
              Text(
                AppStrings.dailyRunCompleted,
                style: GoogleFonts.nunito(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: Colors.amberAccent,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(AppStrings.totalScore, style: GoogleFonts.nunito(fontSize: 14, color: Colors.white54)),
              const SizedBox(height: 4),
              Text(
                totalScore.toStringAsFixed(1),
                style: GoogleFonts.nunito(
                  fontSize: 48,
                  fontWeight: FontWeight.w900,
                  color: Colors.amberAccent,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        _showDailyRunLeaderboard();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amberAccent.withValues(alpha: 0.2),
                        foregroundColor: Colors.amberAccent,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: BorderSide(color: Colors.amberAccent.withValues(alpha: 0.5)),
                        ),
                        elevation: 0,
                      ),
                      child: Text(AppStrings.ranking, style: GoogleFonts.nunito(fontSize: 15, fontWeight: FontWeight.w700)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        Navigator.of(context).pop();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6C5CE7),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      child: Text(AppStrings.homePage, style: GoogleFonts.nunito(fontSize: 15, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final progress = DailyRunService().getProgress();
    final slot = DailyRunService.currentRunSlot();

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
                  gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF2E0854), // Vibrant deep purple
            Color(0xFF0F3460), // Deep blue
            Color(0xFF16213E), // Dark slate blue
          ],
        ),
        ),
        child: Stack(
          children: [
            const LogoBackground(),
            SafeArea(
              child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                          ),
                          child: Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white.withValues(alpha: 0.8), size: 18),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Daily Run',
                              style: GoogleFonts.nunito(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            Row(
                              children: [
                                Icon(
                                  slot == 1 ? Icons.wb_sunny_rounded : Icons.nights_stay_rounded,
                                  color: slot == 1 ? Colors.orangeAccent : Colors.indigoAccent,
                                  size: 14,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  slot == 1 ? AppStrings.morningRound : AppStrings.eveningRound,
                                  style: GoogleFonts.nunito(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w900,
                                    color: slot == 1 ? Colors.orangeAccent : Colors.indigoAccent,
                                  ),
                                ),
                                if (_timeLeft != null) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      '${_timeLeft!.inHours.toString().padLeft(2, '0')}:${(_timeLeft!.inMinutes % 60).toString().padLeft(2, '0')}:${(_timeLeft!.inSeconds % 60).toString().padLeft(2, '0')}',
                                      style: GoogleFonts.spaceMono(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white70,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              FadeTransition(
                opacity: _fadeAnimation,
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFE81F).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFFFE81F), width: 2),
                    boxShadow: [BoxShadow(color: const Color(0xFFFFE81F).withValues(alpha: 0.2), blurRadius: 12)],
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.stars_rounded, color: Colors.amberAccent, size: 28),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(AppStrings.totalScore, style: GoogleFonts.nunito(fontSize: 12, color: Colors.white54)),
                          Text(
                            DailyRunService().getTotalScore().toStringAsFixed(1),
                            style: GoogleFonts.nunito(fontSize: 24, fontWeight: FontWeight.w800, color: Colors.amberAccent),
                          ),
                        ],
                      ),
                      const Spacer(),
                      SizedBox(
                        width: 50,
                        height: 50,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            CircularProgressIndicator(
                              value: progress.scores.length / DailyRunService.gameOrder.length,
                              strokeWidth: 4,
                              backgroundColor: Colors.white.withValues(alpha: 0.1),
                              valueColor: const AlwaysStoppedAnimation(Colors.amberAccent),
                            ),
                            Text(
                              '${progress.scores.length}/${DailyRunService.gameOrder.length}',
                              style: GoogleFonts.nunito(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: FadeTransition(
                  opacity: _slideAnimation,
                  child: _buildPathLayout(progress),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: ElevatedButton.icon(
                  onPressed: _showDailyRunLeaderboard,
                  icon: const Icon(Icons.emoji_events_rounded, color: Colors.amberAccent, size: 28),
                  label: Text(
                    AppStrings.generalRanking,
                    style: GoogleFonts.nunito(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amberAccent.withValues(alpha: 0.15),
                    foregroundColor: Colors.amberAccent,
                    minimumSize: const Size(double.infinity, 56),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: Colors.amberAccent.withValues(alpha: 0.5), width: 2),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  ),
);
  }

  Widget _buildPathLayout(DailyRunProgress progress) {
    const double nodeHeight = 150;
    final int totalNodes = DailyRunService.gameOrder.length;
    final double totalHeight = totalNodes * nodeHeight + 100;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(top: 20, bottom: 40),
      child: SizedBox(
        height: totalHeight,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: PathPainter(
                  totalNodes: totalNodes,
                  nodeHeight: nodeHeight,
                  completedCount: progress.scores.length,
                ),
              ),
            ),
            ...List.generate(totalNodes, (index) {
              final gameId = DailyRunService.gameOrder[index];
              final gameName = DailyRunService.getGameDisplayName(gameId);
              final isCompleted = progress.scores.containsKey(gameId);
              final isCurrent = index == progress.currentGameIndex && !progress.isCompleted;
              final isLocked = index > progress.currentGameIndex && !progress.isCompleted;
              final score = progress.scores[gameId];

              return Positioned(
                top: index * nodeHeight,
                left: 0,
                right: 0,
                height: nodeHeight,
                child: _buildPathNode(
                  index: index,
                  gameId: gameId,
                  gameName: gameName,
                  isCompleted: isCompleted,
                  isCurrent: isCurrent,
                  isLocked: isLocked,
                  score: score,
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildPathNode({
    required int index,
    required String gameId,
    required String gameName,
    required bool isCompleted,
    required bool isCurrent,
    required bool isLocked,
    required double? score,
  }) {
    final double xAlign = math.sin(index * math.pi / 2.5) * 0.6;
    
    Widget nodeContent;
    if (isCurrent) {
      nodeContent = _buildCurrentNode(gameId, gameName, index);
    } else if (isCompleted) {
      nodeContent = _buildCompletedNode(gameId, gameName, score, index);
    } else {
      nodeContent = _buildLockedNode(gameId, gameName, index);
    }

    return Align(
      alignment: Alignment(xAlign, 0),
      child: nodeContent,
    );
  }

  Widget _buildCurrentNode(String gameId, String gameName, int index) {
    return _PulseNode(
      child: GestureDetector(
        onTap: () => _startGame(gameId),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFFF007F).withValues(alpha: 0.2),
                border: Border.all(color: const Color(0xFFFF007F), width: 4),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF007F).withValues(alpha: 0.6),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  AppStrings.start,
                  style: GoogleFonts.nunito(
                    fontWeight: FontWeight.w900,
                    fontSize: 20,
                    color: Colors.white,
                    shadows: [
                      const Shadow(color: Color(0xFFFF007F), blurRadius: 10),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF121212).withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${index + 1}. $gameName',
                style: GoogleFonts.nunito(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompletedNode(String gameId, String gameName, double? score, int index) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 100,
          height: 80,
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.greenAccent.withValues(alpha: 0.1),
                  border: Border.all(color: Colors.greenAccent, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.greenAccent.withValues(alpha: 0.2),
                      blurRadius: 10,
                    )
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.check_rounded, color: Colors.greenAccent, size: 24),
                    if (score != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1B1B2F),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          score.toStringAsFixed(1),
                          style: GoogleFonts.nunito(
                            color: Colors.greenAccent,
                            fontWeight: FontWeight.w900,
                            fontSize: 11,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: GestureDetector(
                  onTap: () => _showLeaderboard(gameId, gameName),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1B1B2F),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.amberAccent, width: 1.5),
                      boxShadow: [
                        BoxShadow(
                           color: Colors.amberAccent.withValues(alpha: 0.4),
                           blurRadius: 8,
                        )
                      ]
                    ),
                    child: const Icon(
                      Icons.emoji_events_rounded,
                      color: Colors.amberAccent,
                      size: 16,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: const Color(0xFF121212).withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '${index + 1}. $gameName',
            style: GoogleFonts.nunito(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.greenAccent.withValues(alpha: 0.9),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLockedNode(String gameId, String gameName, int index) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.05),
            border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 2),
          ),
          child: Center(
            child: Icon(Icons.lock_rounded, color: Colors.white.withValues(alpha: 0.3), size: 24),
          ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: const Color(0xFF121212).withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '${index + 1}. $gameName',
            style: GoogleFonts.nunito(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.6),
            ),
          ),
        ),
      ],
    );
  }
}

class _PulseNode extends StatefulWidget {
  final Widget child;
  const _PulseNode({required this.child});
  @override
  State<_PulseNode> createState() => _PulseNodeState();
}

class _PulseNodeState extends State<_PulseNode> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
  }
  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: Tween<double>(begin: 1.0, end: 1.05).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
      ),
      child: widget.child,
    );
  }
}

class PathPainter extends CustomPainter {
  final int totalNodes;
  final double nodeHeight;
  final int completedCount;

  PathPainter({
    required this.totalNodes,
    required this.nodeHeight,
    required this.completedCount,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;

    final path = Path();
    final completedPath = Path();

    for (int i = 0; i < totalNodes; i++) {
      final double xAlign = math.sin(i * math.pi / 2.5) * 0.6;
      final double x = (size.width / 2) + (xAlign * (size.width / 2));
      final double y = i * nodeHeight + (nodeHeight / 2);

      if (i == 0) {
        path.moveTo(x, y);
        completedPath.moveTo(x, y);
      } else {
        final prevXAlign = math.sin((i - 1) * math.pi / 2.5) * 0.6;
        final prevX = (size.width / 2) + (prevXAlign * (size.width / 2));
        final prevY = (i - 1) * nodeHeight + (nodeHeight / 2);
        
        final cpY = (prevY + y) / 2;
        
        path.quadraticBezierTo(prevX, cpY, x, y);
        
        if (i <= completedCount) {
          completedPath.quadraticBezierTo(prevX, cpY, x, y);
        }
      }
    }
    
    canvas.drawPath(path, paint);

    for (int i = 1; i <= 3; i++) {
      canvas.drawPath(
        completedPath,
        Paint()
          ..color = Colors.greenAccent.withValues(alpha: 0.3 / i)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6 + (i * 4)
          ..strokeCap = StrokeCap.round,
      );
    }
    
    final completedPaint = Paint()
      ..color = Colors.greenAccent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;
      
    canvas.drawPath(completedPath, completedPaint);
  }

  @override
  bool shouldRepaint(covariant PathPainter oldDelegate) {
    return oldDelegate.completedCount != completedCount;
  }
}
