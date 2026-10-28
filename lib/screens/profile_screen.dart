import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/duel.dart';
import '../models/game_model.dart';
import '../services/stats_service.dart';
import '../services/leaderboard_service.dart';
import '../services/streak_service.dart';
import '../services/daily_run_service.dart';
import '../services/duel_service.dart';
import '../services/personal_best_service.dart';
import '../services/score_scale.dart';
import '../services/language_service.dart';
import '../services/ad_service.dart';
import '../services/sound_service.dart';
import '../services/app_strings.dart';
import '../services/achievement_service.dart';
import '../widgets/avatar_view.dart';
import '../widgets/banner_background.dart';
import '../widgets/avatar_picker_sheet.dart';
import '../widgets/chunky_button.dart';
import '../widgets/streak_style.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const Color _card = Color(0x1AFFFFFF);

  List<GameStat> _dailyRunHistory = [];
  final Map<String, int?> _dailyRunRanks = {};

  bool get _tr => LanguageService().isTurkish;

  @override
  void initState() {
    super.initState();
    _dailyRunHistory = StatsService().getStats('daily_run')..sort((a, b) => b.date.compareTo(a.date));
    _loadDailyRanks();
    StreakService().addListener(_changed);
    AchievementService().addListener(_changed);
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    StreakService().removeListener(_changed);
    AchievementService().removeListener(_changed);
    super.dispose();
  }

  Future<void> _loadDailyRanks() async {
    for (final stat in _dailyRunHistory.take(30)) {
      if (_dailyRunRanks.containsKey(stat.date)) continue;
      final slot = stat.targetValue == 'Sabah' ? 'morning' : 'evening';
      int? rank;
      try {
        rank = await LeaderboardService().getCachedUserRank('daily_run_$slot', stat.score, stat.durationMs, stat.date);
      } catch (_) {}
      if (!mounted) return;
      setState(() => _dailyRunRanks[stat.date] = rank ?? -1);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF2B1460), Color(0xFF1A1440), Color(0xFF0E1638)],
          ),
        ),
        child: SafeArea(
          child: ListView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              _buildTopBar(),
              const SizedBox(height: 14),
              _buildHeader(),
              const SizedBox(height: 16),
              _buildStreakCard(),
              const SizedBox(height: 22),
              _sectionTitle(_tr ? 'İstatistikler' : 'Statistics', Icons.insights_rounded),
              const SizedBox(height: 10),
              _buildStatGrid(),
              const SizedBox(height: 12),
              _buildRunChart(),
              const SizedBox(height: 12),
              _buildDuelCard(),
              const SizedBox(height: 12),
              _buildGameBests(),
              const SizedBox(height: 22),
              _buildAchievements(),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Üst bar ve başlık ───────────────────────────────────────────
  Widget _buildTopBar() {
    return Row(
      children: [
        GestureDetector(
          onTap: () => Navigator.pop(context),
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
          _tr ? 'Profil' : 'Profile',
          style: GoogleFonts.nunito(fontSize: 26, fontWeight: FontWeight.w900, color: Colors.white),
        ),
      ],
    );
  }

  Widget _sectionTitle(String text, IconData icon, {String? trailing}) {
    return Row(
      children: [
        Icon(icon, color: Colors.white70, size: 20),
        const SizedBox(width: 8),
        Text(
          text,
          style: GoogleFonts.nunito(fontSize: 19, fontWeight: FontWeight.w900, color: Colors.white),
        ),
        const Spacer(),
        if (trailing != null)
          Text(
            trailing,
            style: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white54),
          ),
      ],
    );
  }

  Widget _buildHeader() {
    final lb = LeaderboardService();
    const shadow = [Shadow(color: Color(0x66000000), blurRadius: 4)];

    Future<void> edit() async {
      SoundService().playKeyTap();
      await AvatarPickerSheet.show(context);
      if (mounted) setState(() {});
    }

    return GestureDetector(
      onTap: edit,
      child: SizedBox(
        height: 120,
        child: BannerBackground(
          bannerId: lb.banner,
          plainColor: const Color(0xFF2A2060),
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Row(
              children: [
                AvatarView(avatar: lb.avatar, size: 78, ring: Colors.white),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        lb.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.nunito(
                          fontSize: 22,
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          shadows: shadow,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.32),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.edit_rounded, color: Colors.white, size: 14),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                AppStrings.editLook,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.nunito(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── Seri kartı ──────────────────────────────────────────────────
  Widget _buildStreakCard() {
    final s = StreakService();
    final n = s.currentStreak;
    final frozen = s.isFrozenToday;
    final tier = StreakTier.of(n);
    final color = frozen ? StreakTier.frozenColor : tier.color;
    final mood = StreakMood.of(s);

    return GestureDetector(
      onTap: () {
        SoundService().playKeyTap();
        _showCalendar();
      },
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [color.withValues(alpha: 0.28), color.withValues(alpha: 0.08)],
          ),
          border: Border.all(color: color.withValues(alpha: 0.45), width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                StreakFlame(streak: n, frozen: frozen, size: 72),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            '$n',
                            style: GoogleFonts.nunito(
                              fontSize: 44,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              height: 1,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              _tr ? 'günlük seri' : 'day streak',
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.nunito(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: Colors.white70,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      _chip(frozen ? (_tr ? 'Donmuş' : 'Frozen') : tier.name, color),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              mood.headline,
              style: GoogleFonts.nunito(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white),
            ),
            const SizedBox(height: 2),
            Text(
              mood.line,
              style: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white70),
            ),
            const SizedBox(height: 16),
            _buildWeek(color),
            const SizedBox(height: 16),
            _buildGoal(n, color),
            const SizedBox(height: 14),
            Row(
              children: [
                _miniStat(
                  Icons.ac_unit_rounded,
                  StreakTier.frozenColor,
                  '${s.freezeCount}/${StreakService.maxFreezes}',
                  _tr ? 'Donma' : 'Freeze',
                ),
                const SizedBox(width: 8),
                _miniStat(
                  Icons.emoji_events_rounded,
                  const Color(0xFFFFD54F),
                  '${s.bestStreak}',
                  _tr ? 'En iyi' : 'Best',
                ),
                const Spacer(),
                Text(
                  _tr ? 'Takvim' : 'Calendar',
                  style: GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white60),
                ),
                const Icon(Icons.chevron_right_rounded, color: Colors.white60, size: 20),
              ],
            ),
            if (s.canRestoreStreak) ...[
              const SizedBox(height: 14),
              ChunkyButton(
                face: const Color(0xFFFF8A2F),
                lip: const Color(0xFFC85A00),
                height: 52,
                onTap: () => _showRestoreDialog(s.lostStreak),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.play_circle_rounded, color: Colors.white, size: 22),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        AppStrings.restoreStreak(s.lostStreak),
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _chip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.7)),
      ),
      child: Text(
        text,
        style: GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.white),
      ),
    );
  }

  Widget _miniStat(IconData icon, Color color, String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.22), borderRadius: BorderRadius.circular(12)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 5),
          Text(
            value,
            style: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w900, color: Colors.white),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white60),
          ),
        ],
      ),
    );
  }

  Set<String> get _playedDates => {...StreakService().activeDays, ..._dailyRunHistory.map((s) => s.date)};

  DateTime get _today {
    final n = DailyRunService.turkeyNow;
    return DateTime.utc(n.year, n.month, n.day);
  }

  String _dayLetter(int weekday) => [
    AppStrings.mon,
    AppStrings.tue,
    AppStrings.wed,
    AppStrings.thu,
    AppStrings.fri,
    AppStrings.sat,
    AppStrings.sun,
  ][weekday - 1];

  /// Bu hafta (Pzt–Paz): oynanan gün alevli, donan gün buzlu, bugün halkalı, gelecek soluk
  Widget _buildWeek(Color color) {
    final today = _today;
    final monday = today.subtract(Duration(days: today.weekday - 1));
    final played = _playedDates;
    final frozen = StreakService().frozenDays;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        for (var i = 0; i < 7; i++)
          Builder(
            builder: (context) {
              final d = monday.add(Duration(days: i));
              final key = StreakService.keyOf(d);
              final isToday = d == today;
              final future = d.isAfter(today);
              final isPlayed = played.contains(key);
              final isFrozen = frozen.contains(key);
              final Color fill = isPlayed
                  ? color
                  : isFrozen
                  ? StreakTier.frozenColor
                  : Colors.white.withValues(alpha: future ? 0.04 : 0.1);
              return Column(
                children: [
                  Text(
                    _dayLetter(d.weekday),
                    style: GoogleFonts.nunito(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: isToday ? Colors.white : Colors.white54,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: fill,
                      border: isToday && !isPlayed ? Border.all(color: color, width: 2.5) : null,
                      boxShadow: isPlayed ? [BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 8)] : null,
                    ),
                    child: isPlayed
                        ? const Icon(Icons.local_fire_department_rounded, color: Colors.white, size: 20)
                        : isFrozen
                        ? const Icon(Icons.ac_unit_rounded, color: Colors.white, size: 18)
                        : null,
                  ),
                ],
              );
            },
          ),
      ],
    );
  }

  /// Sonraki hedefe ilerleme çubuğu
  Widget _buildGoal(int n, Color color) {
    final goal = StreakTier.nextGoal(n);
    if (goal == null) return const SizedBox.shrink();
    final prev = StreakTier.prevGoal(n);
    final progress = ((n - prev) / (goal - prev)).clamp(0.0, 1.0);
    final nextTier = StreakTier.next(n);
    final isTierGoal = nextTier != null && nextTier.minDays == goal;
    final left = goal - n;
    final label = isTierGoal
        ? (_tr ? '$left gün sonra ${nextTier.name}' : '${nextTier.name} in $left days')
        : (_tr ? '$goal günlük hedefe $left gün' : '$left days to $goal-day goal');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.flag_rounded, color: isTierGoal ? nextTier.color : Colors.white70, size: 16),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white70),
              ),
            ),
            Text(
              '$n/$goal',
              style: GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.w900, color: Colors.white),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Stack(
            children: [
              Container(height: 12, color: Colors.black.withValues(alpha: 0.25)),
              FractionallySizedBox(
                widthFactor: math.max(progress, 0.04),
                child: Container(
                  height: 12,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [color, isTierGoal ? nextTier.color : color]),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showCalendar() {
    final played = _playedDates;
    final frozen = StreakService().frozenDays;
    final today = _today;
    final color = StreakTier.of(StreakService().currentStreak).color;
    // Son 5 hafta, pazartesiden başlayarak
    final start = today.subtract(Duration(days: today.weekday - 1 + 28));

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1C1640),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 16),
              Text(
                AppStrings.dailyStreak,
                style: GoogleFonts.nunito(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  for (var w = 1; w <= 7; w++)
                    Expanded(
                      child: Center(
                        child: Text(
                          _dayLetter(w),
                          style: GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.white54),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              for (var week = 0; week < 5; week++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      for (var i = 0; i < 7; i++)
                        Expanded(
                          child: Builder(
                            builder: (context) {
                              final d = start.add(Duration(days: week * 7 + i));
                              final key = StreakService.keyOf(d);
                              final isPlayed = played.contains(key);
                              final isFrozen = frozen.contains(key);
                              final future = d.isAfter(today);
                              return Center(
                                child: Container(
                                  width: 38,
                                  height: 38,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: isPlayed
                                        ? color
                                        : isFrozen
                                        ? StreakTier.frozenColor
                                        : Colors.white.withValues(alpha: future ? 0.02 : 0.06),
                                    border: d == today ? Border.all(color: Colors.white, width: 2) : null,
                                  ),
                                  child: Text(
                                    '${d.day}',
                                    style: GoogleFonts.nunito(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w900,
                                      color: isPlayed || isFrozen
                                          ? Colors.white
                                          : (future ? Colors.white24 : Colors.white54),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 16,
                children: [
                  _legend(color, _tr ? 'Oynandı' : 'Played'),
                  _legend(StreakTier.frozenColor, _tr ? 'Donma kullanıldı' : 'Freeze used'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _legend(Color c, String t) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(color: c, shape: BoxShape.circle),
      ),
      const SizedBox(width: 6),
      Text(
        t,
        style: GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white70),
      ),
    ],
  );

  void _showRestoreDialog(int lostStreak) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1C1640),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        contentPadding: const EdgeInsets.fromLTRB(24, 28, 24, 16),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            StreakFlame(streak: lostStreak, size: 64),
            const SizedBox(height: 12),
            Text(
              AppStrings.restoreStreakTitle,
              textAlign: TextAlign.center,
              style: GoogleFonts.nunito(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white),
            ),
            const SizedBox(height: 8),
            Text(
              AppStrings.restoreStreakBody(lostStreak),
              textAlign: TextAlign.center,
              style: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white70),
            ),
            const SizedBox(height: 4),
            Text(
              AppStrings.limitedTimeOffer,
              textAlign: TextAlign.center,
              style: GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.orangeAccent),
            ),
            const SizedBox(height: 20),
            ChunkyButton(
              face: const Color(0xFFFF8A2F),
              lip: const Color(0xFFC85A00),
              height: 52,
              onTap: () {
                Navigator.pop(context);
                _watchAdAndRestore();
              },
              child: Text(
                AppStrings.watchAdAndRestore,
                style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.white),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                AppStrings.cancel,
                style: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white38),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _watchAdAndRestore() {
    AdService().showRewardedAd(
      onUserEarnedReward: () async {
        final success = await StreakService().restoreStreakWithAd();
        if (mounted && success) {
          SoundService().playReward();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                AppStrings.streakRestored,
                style: GoogleFonts.nunito(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              backgroundColor: const Color(0xFFFF6E40),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
      },
    );
  }

  // ─── İstatistikler ───────────────────────────────────────────────
  Widget _buildStatGrid() {
    final runs = _dailyRunHistory;
    final maxRun = DailyRunService.gamesPerRun * 100.0;
    final valid = runs.map((r) => r.score).where((v) => v > 0 && v <= maxRun).toList();
    final best = valid.isEmpty ? null : valid.reduce(math.max);
    final avg = valid.isEmpty ? null : valid.reduce((a, b) => a + b) / valid.length;
    final ranks = _dailyRunRanks.values.whereType<int>().where((r) => r > 0);
    final bestRank = ranks.isEmpty ? null : ranks.reduce(math.min);

    final tiles = [
      (
        Icons.directions_run_rounded,
        const Color(0xFF4F8BFF),
        '${AchievementService().runsCompleted}',
        _tr ? 'Koşu' : 'Runs',
      ),
      (Icons.star_rounded, const Color(0xFFFFC233), best?.toStringAsFixed(0) ?? '–', _tr ? 'En iyi koşu' : 'Best run'),
      (Icons.equalizer_rounded, const Color(0xFF3DDC84), avg?.toStringAsFixed(0) ?? '–', _tr ? 'Ortalama' : 'Average'),
      (
        Icons.emoji_events_rounded,
        const Color(0xFFFF7A9A),
        bestRank != null ? '#$bestRank' : '–',
        _tr ? 'En iyi sıra' : 'Best rank',
      ),
    ];
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 2.3,
      children: [
        for (final (icon, color, value, label) in tiles)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(18)),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          value,
                          style: GoogleFonts.nunito(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            height: 1.1,
                          ),
                        ),
                      ),
                      Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white60),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  /// Son 7 koşunun puanları (eskiden yeniye)
  Widget _buildRunChart() {
    final maxRun = DailyRunService.gamesPerRun * 100.0;
    final last = _dailyRunHistory.where((r) => r.score <= maxRun).take(7).toList().reversed.toList();
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _tr ? 'Son koşuların' : 'Your recent runs',
            style: GoogleFonts.nunito(fontSize: 15, fontWeight: FontWeight.w900, color: Colors.white),
          ),
          const SizedBox(height: 12),
          if (last.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 18),
              child: Center(
                child: Text(
                  _tr
                      ? 'İlk Daily Run\'ını bitirince burada görünecek.'
                      : 'Finish your first Daily Run to see it here.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white54),
                ),
              ),
            )
          else
            SizedBox(
              height: 120,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (var i = 0; i < last.length; i++)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(
                              last[i].score.toStringAsFixed(0),
                              style: GoogleFonts.nunito(
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                color: Colors.white70,
                              ),
                            ),
                            const SizedBox(height: 4),
                            TweenAnimationBuilder<double>(
                              tween: Tween(begin: 0, end: (last[i].score / maxRun).clamp(0.03, 1.0)),
                              duration: Duration(milliseconds: 500 + i * 60),
                              curve: Curves.easeOutCubic,
                              builder: (context, v, _) => Container(
                                height: 80 * v,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(6),
                                  gradient: LinearGradient(
                                    begin: Alignment.bottomCenter,
                                    end: Alignment.topCenter,
                                    colors: i == last.length - 1
                                        ? const [Color(0xFFFF9800), Color(0xFFFFD180)]
                                        : const [Color(0xFF4F8BFF), Color(0xFF8FB4FF)],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              last[i].date.substring(8),
                              style: GoogleFonts.nunito(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Colors.white38,
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
    );
  }

  Widget _buildDuelCard() {
    final d = DuelService();
    final league = DuelLeague.of(d.trophies);
    final total = d.wins + d.losses + d.draws;
    final rate = total == 0 ? null : (d.wins / total * 100).round();
    final lc = Color(league.color);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(20)),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: lc.withValues(alpha: 0.18),
              border: Border.all(color: lc, width: 2),
            ),
            child: Icon(Icons.shield_rounded, color: lc, size: 28),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_tr ? 'Düello' : 'Duel'} · ${_tr ? league.nameTr : league.nameEn}',
                  style: GoogleFonts.nunito(fontSize: 15, fontWeight: FontWeight.w900, color: Colors.white),
                ),
                Text(
                  '${d.trophies} ${_tr ? 'kupa' : 'trophies'}${rate != null ? ' · %$rate ${_tr ? 'galibiyet' : 'wins'}' : ''}',
                  style: GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white60),
                ),
              ],
            ),
          ),
          _wld('${d.wins}', const Color(0xFF3DDC84), _tr ? 'G' : 'W'),
          _wld('${d.draws}', Colors.white70, _tr ? 'B' : 'D'),
          _wld('${d.losses}', const Color(0xFFFF5D73), _tr ? 'M' : 'L'),
        ],
      ),
    );
  }

  Widget _wld(String v, Color c, String l) => Padding(
    padding: const EdgeInsets.only(left: 10),
    child: Column(
      children: [
        Text(
          v,
          style: GoogleFonts.nunito(fontSize: 18, fontWeight: FontWeight.w900, color: c),
        ),
        Text(
          l,
          style: GoogleFonts.nunito(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white54),
        ),
      ],
    ),
  );

  /// Oyun başına en iyi puan (günlük ya da bilet modu, 100 üzerinden)
  Widget _buildGameBests() {
    final bests = <(GameModel, double)>[];
    for (final g in games) {
      final daily = StatsService().getStats(g.id).map((s) => ScoreScale.normalize(g.id, s.score));
      final pb = PersonalBestService().best(g.id);
      final all = [...daily, if (pb != null) ScoreScale.normalize(g.id, pb)];
      if (all.isEmpty) continue;
      bests.add((g, all.reduce(math.max)));
    }
    bests.sort((a, b) => b.$2.compareTo(a.$2));
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                _tr ? 'Oyun rekorların' : 'Game records',
                style: GoogleFonts.nunito(fontSize: 15, fontWeight: FontWeight.w900, color: Colors.white),
              ),
              const Spacer(),
              Text(
                '${bests.length}/${games.length}',
                style: GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white54),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (bests.isEmpty)
            Text(
              _tr ? 'Oyun oynadıkça rekorların burada birikecek.' : 'Your records will collect here as you play.',
              style: GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white54),
            )
          else
            SizedBox(
              height: 92,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: bests.length,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (context, i) {
                  final (g, v) = bests[i];
                  return SizedBox(
                    width: 64,
                    child: Column(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: g.imagePath != null
                              ? Image.asset(g.imagePath!, width: 52, height: 52, fit: BoxFit.cover, cacheWidth: 160)
                              : Container(
                                  width: 52,
                                  height: 52,
                                  color: Colors.white12,
                                  child: Icon(g.icon, color: Colors.white),
                                ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          v.toStringAsFixed(0),
                          style: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w900, color: _scoreColor(v)),
                        ),
                        Text(
                          g.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.nunito(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white54),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Color _scoreColor(double v) {
    if (v >= 85) return const Color(0xFF3DDC84);
    if (v >= 60) return const Color(0xFFFFC233);
    if (v >= 30) return const Color(0xFFFF9800);
    return const Color(0xFFFF5D73);
  }

  // ─── Rozetler ────────────────────────────────────────────────────
  Widget _buildAchievements() {
    final service = AchievementService();
    final total = AchievementService.all.length;
    final got = service.unlockedCount;
    // Açılanlar önce
    final list = [...AchievementService.all]
      ..sort((a, b) => (service.isUnlocked(b.id) ? 1 : 0).compareTo(service.isUnlocked(a.id) ? 1 : 0));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(AppStrings.badges, Icons.military_tech_rounded, trailing: '$got/$total'),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(5),
          child: LinearProgressIndicator(
            value: total == 0 ? 0 : got / total,
            minHeight: 8,
            backgroundColor: Colors.white.withValues(alpha: 0.1),
            valueColor: const AlwaysStoppedAnimation(Color(0xFFFFD54F)),
          ),
        ),
        const SizedBox(height: 14),
        GridView.count(
          crossAxisCount: 4,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 8,
          childAspectRatio: 0.78,
          children: [
            for (final a in list)
              GestureDetector(
                onTap: () => _showAchievement(a, service.isUnlocked(a.id)),
                child: Column(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: service.isUnlocked(a.id)
                            ? const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [Color(0xFFFFE082), Color(0xFFFFB300)],
                              )
                            : null,
                        color: service.isUnlocked(a.id) ? null : Colors.white.withValues(alpha: 0.06),
                        boxShadow: service.isUnlocked(a.id)
                            ? const [BoxShadow(color: Color(0xFFB27C00), offset: Offset(0, 3))]
                            : null,
                      ),
                      child: Icon(
                        service.isUnlocked(a.id) ? a.icon : Icons.lock_rounded,
                        color: service.isUnlocked(a.id) ? const Color(0xFF3A2A00) : Colors.white24,
                        size: 26,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      a.title,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.nunito(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: service.isUnlocked(a.id) ? Colors.white : Colors.white38,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }

  void _showAchievement(Achievement a, bool unlocked) {
    SoundService().playKeyTap();
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1C1640),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: unlocked ? const LinearGradient(colors: [Color(0xFFFFE082), Color(0xFFFFB300)]) : null,
                  color: unlocked ? null : Colors.white.withValues(alpha: 0.08),
                ),
                child: Icon(
                  unlocked ? a.icon : Icons.lock_rounded,
                  color: unlocked ? const Color(0xFF3A2A00) : Colors.white38,
                  size: 40,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                a.title,
                style: GoogleFonts.nunito(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white),
              ),
              const SizedBox(height: 4),
              Text(
                a.description,
                textAlign: TextAlign.center,
                style: GoogleFonts.nunito(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white70),
              ),
              const SizedBox(height: 10),
              Text(
                unlocked ? (_tr ? 'Kazanıldı ✓' : 'Unlocked ✓') : (_tr ? 'Henüz kilitli' : 'Still locked'),
                style: GoogleFonts.nunito(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: unlocked ? const Color(0xFF3DDC84) : Colors.white38,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
