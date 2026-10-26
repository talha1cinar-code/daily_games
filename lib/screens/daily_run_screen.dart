import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math' as math;
import 'dart:async';
import '../services/daily_run_service.dart';
import '../games/game_registry.dart';
import '../services/sound_service.dart';
import '../services/ad_service.dart';
import '../services/app_strings.dart';
import '../services/friends_service.dart';
import '../services/stats_service.dart';
import '../models/game_model.dart';
import '../widgets/chunky_button.dart';
import '../widgets/streak_celebration.dart';
import '../widgets/coin_badge.dart';
import '../services/leaderboard_service.dart';
import '../services/streak_service.dart';
import '../services/score_scale.dart';
import '../utils/app_links.dart';
import 'package:share_plus/share_plus.dart';
import '../widgets/logo_background.dart';
import 'leaderboard_screen.dart';

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

    // Tamamlanmış ama sandığı açılmamış run: ödül kaybolmasın
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final progress = DailyRunService().getProgress();
      if (mounted && progress.isCompleted && !DailyRunService().isChestOpened(progress)) {
        _showCompletionDialog();
      }
    });
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
        .then((_) async {
      if (mounted) {
        SoundService().exitMiniGame();
        setState(() {});
        await maybeShowStreakCelebration(context);
        if (!mounted) return;

        final progress = DailyRunService().getProgress();
        if (progress.isCompleted) {
          AdService().showInterstitialAd(
            onAdClosed: () {
              if (mounted) _showCompletionDialog();
            }
          );
        } else if (progress.currentGameIndex == (DailyRunService.gamesPerRun / 2).ceil()) {
          // Run'ın ortasında bir kez reklam göster
          AdService().showInterstitialAd();
        }
      }
    });
  }

  Widget _buildGameScreen(String gameId) {
    void onComplete(double score, [int durationMs = 0]) {
      DailyRunService().saveGameScore(gameId, score, durationMs);
    }

    return buildGameScreen(gameId, isDailyMode: true, onGameComplete: onComplete) ?? const SizedBox();
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
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _RunCompleteDialog(
        progress: DailyRunService().getProgress(),
        onRanking: () {
          Navigator.of(ctx).pop();
          _showDailyRunLeaderboard();
        },
        onHome: () {
          Navigator.of(ctx).pop();
          Navigator.of(context).pop();
        },
      ),
    );
  }

  String _two(int v) => v.toString().padLeft(2, '0');

  @override
  Widget build(BuildContext context) {
    final progress = DailyRunService().getProgress();
    final slot = DailyRunService.currentRunSlot();
    final morning = slot == 1;
    final left = _timeLeft ?? Duration.zero;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF3A0F6E), Color(0xFF1A1450), Color(0xFF0E1638)],
          ),
        ),
        child: Stack(
          children: [
            const LogoBackground(),
            SafeArea(
              child: Column(
                children: [
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                      child: Row(
                        children: [
                          GestureDetector(
                            onTap: () => Navigator.of(context).pop(),
                            child: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.28),
                                borderRadius: BorderRadius.circular(22),
                              ),
                              child: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Daily Run',
                            style: GoogleFonts.nunito(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white),
                          ),
                          const Spacer(),
                          Container(
                            height: 36,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.28),
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  morning ? Icons.wb_sunny_rounded : Icons.nightlight_round,
                                  color: morning ? const Color(0xFFFFC857) : const Color(0xFFB9A8FF),
                                  size: 18,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '${_two(left.inHours)}:${_two(left.inMinutes % 60)}:${_two(left.inSeconds % 60)}',
                                  style: GoogleFonts.nunito(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                    fontFeatures: const [FontFeature.tabularFigures()],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _TargetBar(progress: progress),
                    ),
                  ),
                  Expanded(
                    child: FadeTransition(
                      opacity: _slideAnimation,
                      child: _buildPathLayout(progress),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
                    child: ChunkyButton(
                      face: const Color(0xFFFFB627),
                      lip: const Color(0xFFC77F00),
                      height: 58,
                      onTap: _showDailyRunLeaderboard,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.emoji_events_rounded, color: Colors.white, size: 26),
                          const SizedBox(width: 8),
                          Text(
                            AppStrings.generalRanking,
                            style: GoogleFonts.nunito(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              shadows: const [Shadow(color: Color(0x55000000), offset: Offset(0, 2))],
                            ),
                          ),
                        ],
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
    final order = progress.gameOrder;
    final int totalNodes = order.length;
    final double totalHeight = totalNodes * nodeHeight + 40;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(top: 16, bottom: 24),
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
                  completedCount: progress.completedCount,
                ),
              ),
            ),
            ...List.generate(totalNodes, (index) {
              final gameId = order[index];
              final isCompleted = progress.scores.containsKey(gameId);
              final isCurrent = index == progress.currentGameIndex && !progress.isCompleted;
              return Positioned(
                top: index * nodeHeight,
                left: 0,
                right: 0,
                height: nodeHeight,
                child: Align(
                  alignment: Alignment(math.sin(index * math.pi / 2.5) * 0.6, 0),
                  child: isCurrent
                      ? _buildCurrentNode(gameId)
                      : isCompleted
                          ? _buildCompletedNode(gameId, progress.scores[gameId]!)
                          : _buildLockedNode(gameId),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  GameModel _game(String id) => games.firstWhere((g) => g.id == id);

  Widget _icon(String gameId, double size, {double dim = 0, Widget? overlay, Color? ring}) {
    final g = _game(gameId);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.27),
        border: ring != null ? Border.all(color: ring, width: 4) : null,
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 12, offset: const Offset(0, 6)),
          if (ring != null) BoxShadow(color: ring.withValues(alpha: 0.45), blurRadius: 22),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.27 - (ring != null ? 4 : 0)),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (g.imagePath != null) Image.asset(g.imagePath!, fit: BoxFit.cover, cacheWidth: 300),
            if (dim > 0) Container(color: Colors.black.withValues(alpha: dim)),
            ?overlay,
          ],
        ),
      ),
    );
  }

  Widget _label(String text, {Color color = Colors.white, Color? bg}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: bg ?? Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(text, style: GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.w900, color: color)),
    );
  }

  Widget _buildCurrentNode(String gameId) {
    return GestureDetector(
      onTap: () => _startGame(gameId),
      child: _PulseNode(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _icon(gameId, 96, ring: Colors.white),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF3DDC84),
                borderRadius: BorderRadius.circular(14),
                boxShadow: const [BoxShadow(color: Color(0xFF1E9E55), offset: Offset(0, 4))],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 20),
                  const SizedBox(width: 2),
                  Text(
                    _game(gameId).name.toUpperCase(),
                    style: GoogleFonts.nunito(fontSize: 15, fontWeight: FontWeight.w900, color: Colors.white),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompletedNode(String gameId, double score) {
    return GestureDetector(
      onTap: () => _showLeaderboard(gameId, _game(gameId).name),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _icon(
            gameId,
            72,
            dim: 0.35,
            overlay: const Center(child: Icon(Icons.check_rounded, color: Color(0xFF5CF08F), size: 44)),
          ),
          const SizedBox(height: 6),
          _label('${score.toStringAsFixed(0)} ${AppStrings.pointsShort}', color: const Color(0xFF5CF08F)),
        ],
      ),
    );
  }

  Widget _buildLockedNode(String gameId) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _icon(
          gameId,
          60,
          dim: 0.6,
          overlay: Center(child: Icon(Icons.lock_rounded, color: Colors.white.withValues(alpha: 0.75), size: 24)),
        ),
        const SizedBox(height: 6),
        _label(_game(gameId).name, color: Colors.white60),
      ],
    );
  }
}

/// Run boyunca hedef: arkadaşın bugünkü en iyi skoru ya da kendi rekorun.
class _TargetBar extends StatefulWidget {
  final DailyRunProgress progress;
  const _TargetBar({required this.progress});

  @override
  State<_TargetBar> createState() => _TargetBarState();
}

class _TargetBarState extends State<_TargetBar> {
  String? _friendName;
  double? _friendScore;

  @override
  void initState() {
    super.initState();
    _loadFriend();
  }

  Future<void> _loadFriend() async {
    final ids = FriendsService().friendIds;
    if (ids.isEmpty) return;
    final runId = 'daily_run_${widget.progress.runSlot == 1 ? "morning" : "evening"}';
    final entries = await LeaderboardService().getDailyEntriesForUsers(runId, ids, widget.progress.dateKey);
    if (entries.isEmpty || !mounted) return;
    setState(() {
      _friendName = entries.first.displayName;
      _friendScore = entries.first.score;
    });
  }

  /// Önceki koşulardaki en iyi toplam. Normalize puanlamadan önceki ham
  /// toplamlar (run başına 100'den büyük ortalama) hedef olarak kullanılmaz.
  double? get _personalBest {
    final max = DailyRunService.gamesPerRun * 100.0;
    final scores = StatsService()
        .getStats('daily_run')
        .map((s) => s.score)
        .where((v) => v > 0 && v <= max);
    if (scores.isEmpty) return null;
    return scores.reduce((a, b) => a > b ? a : b);
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.progress.scores.values.fold(0.0, (a, b) => a + b);
    final best = _personalBest;
    final String? who;
    final double? target;
    if (_friendScore != null) {
      who = _friendName;
      target = _friendScore;
    } else if (best != null) {
      who = AppStrings.yourLastRun;
      target = best;
    } else {
      who = null;
      target = null;
    }
    final beaten = target != null && total > target;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.stars_rounded, color: Color(0xFFFFC233), size: 26),
              const SizedBox(width: 8),
              Text(
                total.toStringAsFixed(0),
                style: GoogleFonts.nunito(fontSize: 26, fontWeight: FontWeight.w900, color: Colors.white, height: 1),
              ),
              const SizedBox(width: 6),
              Text(
                '/ ${widget.progress.gameOrder.length * 100}',
                style: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white54),
              ),
              const Spacer(),
              if (target != null)
                Flexible(
                  child: Text(
                    beaten ? AppStrings.targetBeaten(who!) : AppStrings.targetToBeat(who!, target.toStringAsFixed(0)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.nunito(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: beaten ? const Color(0xFF5CF08F) : Colors.white70,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: target != null && target > 0
                  ? (total / target).clamp(0.0, 1.0)
                  : widget.progress.completedCount / widget.progress.gameOrder.length,
              minHeight: 10,
              backgroundColor: Colors.white.withValues(alpha: 0.1),
              valueColor: AlwaysStoppedAnimation(beaten ? const Color(0xFF5CF08F) : const Color(0xFFFFC233)),
            ),
          ),
        ],
      ),
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
      scale: Tween<double>(begin: 1.0, end: 1.06).animate(
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

class _RunCompleteDialog extends StatefulWidget {
  final DailyRunProgress progress;
  final VoidCallback onRanking;
  final VoidCallback onHome;

  const _RunCompleteDialog({required this.progress, required this.onRanking, required this.onHome});

  @override
  State<_RunCompleteDialog> createState() => _RunCompleteDialogState();
}

class _RunCompleteDialogState extends State<_RunCompleteDialog> {
  ({int rank, int total})? _standing;
  bool _loadingStanding = true;

  DailyRunProgress get _p => widget.progress;
  double get _total => _p.scores.values.fold(0.0, (a, b) => a + b);
  String get _runId => 'daily_run_${_p.runSlot == 1 ? "morning" : "evening"}';

  @override
  void initState() {
    super.initState();
    LeaderboardService()
        .getStanding(_runId, _total, _p.totalDurationMs, _p.dateKey)
        .then((s) {
      if (!mounted) return;
      setState(() {
        _standing = s;
        _loadingStanding = false;
      });
    });
  }

  String get _grid => [
        for (final id in _p.gameOrder) ScoreScale.emoji(_p.scores[id] ?? 0),
      ].join();

  String? get _standingText {
    final s = _standing;
    if (s == null) return null;
    if (s.total < 10) return AppStrings.rankOf(s.rank, s.total);
    final pct = (s.rank / s.total * 100).ceil().clamp(1, 100);
    return AppStrings.topPercent(pct);
  }

  void _share() {
    SoundService().playKeyTap();
    final date = _p.dateKey.split('-');
    final slot = _p.runSlot == 1 ? AppStrings.morning : AppStrings.evening;
    final streak = StreakService().currentStreak;
    final standing = _standingText;
    final lines = [
      'Daily Run · ${date[2]}.${date[1]} $slot',
      _grid,
      '${_total.toStringAsFixed(0)} / ${_p.gameOrder.length * 100}${standing != null ? ' · $standing' : ''}',
      if (streak > 1) '🔥 ${AppStrings.streakDays(streak)}',
      '',
      AppLinks.playStore,
    ];
    SharePlus.instance.share(ShareParams(text: lines.join('\n')));
  }

  @override
  Widget build(BuildContext context) {
    final streak = StreakService();
    return AlertDialog(
      scrollable: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: const Color(0xFF1B1B2F),
      contentPadding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            AppStrings.dailyRunCompleted,
            style: GoogleFonts.nunito(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: _total),
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeOutCubic,
            builder: (context, v, _) => Text(
              v.toStringAsFixed(0),
              style: GoogleFonts.nunito(fontSize: 52, fontWeight: FontWeight.w900, color: Colors.amberAccent, height: 1),
            ),
          ),
          Text(
            '${AppStrings.totalScore} · ${_p.gameOrder.length * 100} ${AppStrings.outOf}',
            style: GoogleFonts.nunito(fontSize: 13, color: Colors.white54),
          ),
          const SizedBox(height: 16),
          Text(_grid, style: const TextStyle(fontSize: 24, letterSpacing: 2)),
          const SizedBox(height: 12),
          SizedBox(
            height: 22,
            child: _loadingStanding
                ? const Center(child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)))
                : Text(
                    _standingText ?? '',
                    style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.greenAccent),
                  ),
          ),
          if (streak.lastRunExtendedStreak) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFF6E40).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.local_fire_department_rounded, color: Color(0xFFFF6E40)),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      streak.lastRunEarnedFreeze
                          ? '${AppStrings.streakDays(streak.currentStreak)} · ${AppStrings.freezeEarned}'
                          : AppStrings.streakDays(streak.currentStreak),
                      style: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          _RunChest(progress: _p),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _share,
              icon: const Icon(Icons.ios_share_rounded, size: 20),
              label: Text(AppStrings.shareResult, style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w800)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amberAccent,
                foregroundColor: const Color(0xFF1B1B2F),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: widget.onRanking,
                  child: Text(AppStrings.ranking,
                      style: GoogleFonts.nunito(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white70)),
                ),
              ),
              Expanded(
                child: TextButton(
                  onPressed: widget.onHome,
                  child: Text(AppStrings.homePage,
                      style: GoogleFonts.nunito(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white70)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Koşu sandığı: açılınca skora göre coin verir, bir kez reklamla ikiye katlanır.
class _RunChest extends StatefulWidget {
  final DailyRunProgress progress;
  const _RunChest({required this.progress});

  @override
  State<_RunChest> createState() => _RunChestState();
}

class _RunChestState extends State<_RunChest> with SingleTickerProviderStateMixin {
  late final AnimationController _shake = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 600),
  );
  int? _earned;
  bool _opening = false;

  DailyRunProgress get _p => widget.progress;

  @override
  void initState() {
    super.initState();
    if (DailyRunService().isChestOpened(_p)) {
      _earned = DailyRunService.chestReward(_p) * (DailyRunService().isChestDoubled(_p) ? 2 : 1);
    }
  }

  @override
  void dispose() {
    _shake.dispose();
    super.dispose();
  }

  Future<void> _open() async {
    if (_opening || _earned != null) return;
    setState(() => _opening = true);
    await _shake.forward(from: 0);
    final amount = await DailyRunService().openChest(_p);
    SoundService().playReward();
    if (mounted) setState(() => _earned = amount);
  }

  void _double() {
    if (!AdService().isRewardedReady) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(behavior: SnackBarBehavior.floating, content: Text(AppStrings.adNotReady)),
      );
      return;
    }
    AdService().showRewardedAd(onUserEarnedReward: () async {
      final extra = await DailyRunService().doubleChest(_p);
      SoundService().playCoin();
      if (mounted) setState(() => _earned = (_earned ?? 0) + extra);
    });
  }

  @override
  Widget build(BuildContext context) {
    final opened = _earned != null;
    final canDouble = opened && !DailyRunService().isChestDoubled(_p);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFB627).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          AnimatedBuilder(
            animation: _shake,
            builder: (context, child) => Transform.rotate(
              angle: math.sin(_shake.value * math.pi * 8) * 0.18 * (1 - _shake.value),
              child: Transform.scale(scale: 1 + _shake.value * 0.15, child: child),
            ),
            child: Icon(
              opened ? Icons.inventory_2_outlined : Icons.inventory_2_rounded,
              color: const Color(0xFFFFC233),
              size: 44,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: opened
                ? Row(
                    children: [
                      const CoinIcon(size: 26),
                      const SizedBox(width: 6),
                      Text(
                        '+$_earned',
                        style: GoogleFonts.nunito(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white),
                      ),
                    ],
                  )
                : Text(
                    AppStrings.runChest,
                    style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.white),
                  ),
          ),
          SizedBox(
            width: 120,
            child: !opened
                ? ChunkyButton(
                    face: const Color(0xFF3DDC84),
                    lip: const Color(0xFF1E9E55),
                    height: 42,
                    radius: 14,
                    onTap: _opening ? null : _open,
                    child: Text(AppStrings.openChest,
                        style: GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.w900, color: Colors.white)),
                  )
                : canDouble
                    ? ChunkyButton(
                        face: const Color(0xFF4F8BFF),
                        lip: const Color(0xFF2E5BC4),
                        height: 42,
                        radius: 14,
                        onTap: _double,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.smart_display_rounded, color: Colors.white, size: 18),
                            const SizedBox(width: 4),
                            Text('x2',
                                style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.white)),
                          ],
                        ),
                      )
                    : const SizedBox(),
          ),
        ],
      ),
    );
  }
}
