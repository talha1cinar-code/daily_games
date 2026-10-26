import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/stats_service.dart';
import '../services/leaderboard_service.dart';
import '../services/streak_service.dart';
import '../services/daily_run_service.dart';
import '../services/ad_service.dart';
import '../services/sound_service.dart';
import '../services/app_strings.dart';
import '../services/achievement_service.dart';
import '../widgets/avatar_view.dart';
import '../widgets/banner_background.dart';
import '../widgets/avatar_picker_sheet.dart';
import '../widgets/logo_background.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {

  // Daily Run
  List<GameStat> _dailyRunHistory = [];
  final Map<String, int?> _dailyRunRanks = {};

  @override
  void initState() {
    super.initState();
    _loadStats();
    _loadDailyRanks();

    // StreakService değişikliklerini dinle
    StreakService().addListener(_onStreakChanged);
  }

  void _onStreakChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    StreakService().removeListener(_onStreakChanged);
    super.dispose();
  }

  void _loadStats() {
    _dailyRunHistory = StatsService().getStats('daily_run');
    _dailyRunHistory.sort((a, b) => b.date.compareTo(a.date));
    setState(() {});
  }

  Future<void> _loadDailyRanks() async {
    // Daily Run Geçmişi Sıralamaları
    for (var stat in _dailyRunHistory) {
      if (!_dailyRunRanks.containsKey(stat.date)) {
        final slotStr = stat.targetValue == 'Sabah' ? 'morning' : 'evening';
        final gameId = 'daily_run_$slotStr';
        
        try {
          final rank = await LeaderboardService().getCachedUserRank(gameId, stat.score, stat.durationMs, stat.date);
          if (mounted) {
            setState(() {
              _dailyRunRanks[stat.date] = rank ?? -1;
            });
          }
        } catch (e) {
          if (mounted) {
            setState(() {
              _dailyRunRanks[stat.date] = -1;
            });
          }
        }
      }
    }
  }



  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
                gradient: RadialGradient(
          center: Alignment.center,
          radius: 1.5,
          colors: [
            Color(0xFF2E0854), // Vibrant deep purple center
            Color(0xFF0F3460), // Deep blue edges
          ],
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            AppStrings.profileAndStats,
            style: GoogleFonts.nunito(
              fontWeight: FontWeight.bold,
              color: Colors.white,
              shadows: [
                const Shadow(
                  color: Color(0xFFFF007F), // Neon pink glow for title
                  blurRadius: 10,
                ),
              ],
            ),
          ),
          centerTitle: true,
        ),
        body: Stack(
          children: [
            const LogoBackground(),
            CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(child: _buildHeader()),
                SliverToBoxAdapter(child: _buildStreakCard()),
                SliverToBoxAdapter(child: _buildBestRank()),
                SliverToBoxAdapter(child: _buildAchievements()),
                const SliverToBoxAdapter(child: SizedBox(height: 32)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final lb = LeaderboardService();
    const shadow = [Shadow(color: Color(0x66000000), blurRadius: 4)];

    Future<void> edit() async {
      await AvatarPickerSheet.show(context);
      if (mounted) setState(() {});
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      child: GestureDetector(
        onTap: edit,
        child: SizedBox(
          height: 124,
          child: BannerBackground(
            bannerId: lb.banner,
            plainColor: const Color(0xFF16213E),
            borderRadius: BorderRadius.circular(24),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  AvatarView(avatar: lb.avatar, size: 80, ring: Colors.white),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppStrings.welcome,
                          style: GoogleFonts.nunito(
                              fontSize: 14, color: Colors.white70, fontWeight: FontWeight.w700, shadows: shadow),
                        ),
                        Text(
                          lb.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.nunito(
                              fontSize: 22, color: Colors.white, fontWeight: FontWeight.w900, shadows: shadow),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.edit_rounded, color: Colors.white, size: 14),
                              const SizedBox(width: 4),
                              Text(AppStrings.editLook,
                                  style: GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white)),
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
      ),
    );
  }

  Widget _buildStreakCard() {
    final streak = StreakService().currentStreak;
    final isFrozen = StreakService().isFrozenToday;
    final canRestore = StreakService().canRestoreStreak;
    final lostStreak = StreakService().lostStreak;

    Color streakColor = isFrozen ? const Color(0xFF40C4FF) : (streak > 0 ? const Color(0xFFFF9100) : Colors.grey.shade700);

    String subtitle = '';
    if (isFrozen) {
      subtitle = AppStrings.streakSavedBody;
    } else if (streak == 0) {
      subtitle = AppStrings.streakZero;
    } else if (streak < 3) {
      subtitle = AppStrings.streakLow;
    } else if (streak < 7) {
      subtitle = AppStrings.streakMedium;
    } else if (streak < 30) {
      subtitle = AppStrings.streakHigh;
    } else {
      subtitle = AppStrings.streakSuper;
    }

    return GestureDetector(
      onTap: () {
        SoundService().playKeyTap();
        _showCalendarDialog();
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              streakColor.withValues(alpha: 0.9),
              streakColor.withValues(alpha: 0.7),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: streakColor.withValues(alpha: 0.3),
              blurRadius: 20,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(isFrozen ? Icons.ac_unit_rounded : Icons.local_fire_department_rounded, color: Colors.white, size: 36),
                const SizedBox(width: 8),
                Text(
                  '$streak ${AppStrings.days}',
                  style: GoogleFonts.nunito(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.ac_unit_rounded, color: Colors.white, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        '${StreakService().freezeCount} / ${StreakService.maxFreezes}',
                        style: GoogleFonts.nunito(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: GoogleFonts.nunito(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white.withValues(alpha: 0.9),
              ),
            ),
            const SizedBox(height: 24),
            _buildWeekTracker(),
            if (canRestore) ...[
              const SizedBox(height: 16),
              _buildRestoreStreakButton(lostStreak, streakColor),
            ],
          ],
        ),
      ),
    );
  }


  Widget _buildRestoreStreakButton(int lostStreak, Color streakColor) {
    return GestureDetector(
      onTap: () => _showRestoreDialog(lostStreak),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              streakColor.withValues(alpha: 0.3),
              const Color(0xFFFF6D00).withValues(alpha: 0.3),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: streakColor.withValues(alpha: 0.7),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: streakColor.withValues(alpha: 0.2),
              blurRadius: 12,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.play_circle_rounded,
              color: Colors.white,
              size: 24,
              shadows: [Shadow(color: streakColor, blurRadius: 8)],
            ),
            const SizedBox(width: 10),
            Text(
              AppStrings.restoreStreak(lostStreak),
              style: GoogleFonts.nunito(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                shadows: [Shadow(color: streakColor, blurRadius: 8)],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showRestoreDialog(int lostStreak) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF1A0B2E), Color(0xFF0D0020)],
            ),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: const Color(0xFFFF6E40).withValues(alpha: 0.6),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFF6E40).withValues(alpha: 0.3),
                blurRadius: 20,
                spreadRadius: 4,
              ),
            ],
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.local_fire_department_rounded,
                  size: 56,
                  color: Color(0xFFFF6E40),
                  shadows: [Shadow(color: Color(0xFFFF6E40), blurRadius: 16)],
                ),
              const SizedBox(height: 16),
              Text(
                AppStrings.restoreStreakTitle,
                style: GoogleFonts.nunito(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                AppStrings.restoreStreakBody(lostStreak),
                style: GoogleFonts.nunito(
                  fontSize: 14,
                  color: Colors.white70,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                AppStrings.limitedTimeOffer,
                style: GoogleFonts.nunito(
                  fontSize: 12,
                  color: Colors.orangeAccent,
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              // Reklam izle butonu
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _watchAdAndRestore();
                  },
                  icon: const Icon(Icons.play_arrow_rounded, size: 22),
                  label: Text(
                    AppStrings.watchAdAndRestore,
                    style: GoogleFonts.nunito(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: const Color(0xFFFF6E40).withValues(alpha: 0.3),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: const BorderSide(color: Color(0xFFFF6E40), width: 1.5),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  AppStrings.cancel,
                  style: GoogleFonts.nunito(
                    fontSize: 14,
                    color: Colors.white38,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          ),
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
                style: GoogleFonts.nunito(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
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

  Set<String> get _playedDates => {
        ...StreakService().activeDays,
        ..._dailyRunHistory.map((s) => s.date),
      };

  DateTime get _turkeyToday {
    final n = DailyRunService.turkeyNow;
    return DateTime.utc(n.year, n.month, n.day);
  }

  Widget _buildWeekTracker() {
    final today = _turkeyToday;
    List<Widget> dayWidgets = [];

    final playedDates = _playedDates;
    final frozenDates = StreakService().frozenDays;

    for (int i = 6; i >= 0; i--) {
      final date = today.subtract(Duration(days: i));
      final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
 
      final isPlayed = playedDates.contains(dateStr);
      final isFrozenDay = frozenDates.contains(dateStr);
      final isToday = i == 0;

      String dayName = '';
      switch (date.weekday) {
        case 1: dayName = AppStrings.mon; break;
        case 2: dayName = AppStrings.tue; break;
        case 3: dayName = AppStrings.wed; break;
        case 4: dayName = AppStrings.thu; break;
        case 5: dayName = AppStrings.fri; break;
        case 6: dayName = AppStrings.sat; break;
        case 7: dayName = AppStrings.sun; break;
      }

      dayWidgets.add(
        Column(
          children: [
            Text(
              dayName,
              style: GoogleFonts.nunito(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: Colors.white.withValues(alpha: 0.8),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isPlayed
                    ? Colors.white
                    : isFrozenDay
                        ? const Color(0xFFB3E5FC)
                        : Colors.white.withValues(alpha: 0.15),
                border: isToday && !isPlayed ? Border.all(color: Colors.white, width: 2) : null,
              ),
              child: isPlayed
                  ? const Icon(Icons.local_fire_department_rounded, color: Color(0xFFFF9100), size: 20)
                  : isFrozenDay
                      ? const Icon(Icons.ac_unit_rounded, color: Color(0xFF0288D1), size: 18)
                      : null,
            ),
          ],
        )
      );
      
      if (i > 0) {
        dayWidgets.add(
          Expanded(
            child: Container(
              height: 3,
              margin: const EdgeInsets.only(top: 30),
              color: Colors.white.withValues(alpha: 0.2),
            ),
          )
        );
      }
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: dayWidgets,
    );
  }

  void _showCalendarDialog() {
    final playedDates = _playedDates;
    final frozenDates = StreakService().frozenDays;
    final today = _turkeyToday;

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF16213E), Color(0xFF0F3460)],
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 2),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    AppStrings.dailyStreak,
                    style: GoogleFonts.nunito(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 24),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: List.generate(30, (index) {
                    final date = today.subtract(Duration(days: 29 - index));
                    final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
                    final isPlayed = playedDates.contains(dateStr);
                    final isFrozenDay = frozenDates.contains(dateStr);
                    final isToday = index == 29;

                    return Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isPlayed
                            ? const Color(0xFFFF9100)
                            : isFrozenDay
                                ? const Color(0xFF4FC3F7)
                                : Colors.white.withValues(alpha: 0.05),
                        border: isToday ? Border.all(color: Colors.white, width: 2) : null,
                      ),
                      child: Center(
                        child: Text(
                          '${date.day}',
                          style: GoogleFonts.nunito(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: isPlayed || isFrozenDay ? Colors.white : Colors.white54,
                          ),
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF9100),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Text(
                    AppStrings.close,
                    style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w700),
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

  Widget _buildBestRank() {
    if (_dailyRunHistory.isEmpty) return const SizedBox.shrink();

    int? bestRank;
    String? bestDate;
    
    for (final stat in _dailyRunHistory) {
      final rank = _dailyRunRanks[stat.date];
      if (rank != null && rank > 0) {
        if (bestRank == null || rank < bestRank) {
          bestRank = rank;
          bestDate = stat.date;
        }
      }
    }

    if (bestRank == null || bestDate == null) return const SizedBox.shrink();

    final rankLabel = AppStrings.days == 'Gün' ? 'En İyi Sıralama' : 'Best Rank';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 10,
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.emoji_events_rounded, color: Color(0xFFFFD740), size: 48),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  rankLabel,
                  style: GoogleFonts.nunito(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.white70,
                  ),
                ),
                Text(
                  '#$bestRank',
                  style: GoogleFonts.nunito(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    shadows: [
                      const Shadow(color: Color(0xFFFFD740), blurRadius: 10),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Text(
            bestDate,
            style: GoogleFonts.nunito(
              fontSize: 14,
              color: Colors.white54,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAchievements() {
    final service = AchievementService();
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                AppStrings.badges,
                style: GoogleFonts.nunito(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white),
              ),
              const Spacer(),
              Text(
                '${service.unlockedCount}/${AchievementService.all.length}',
                style: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white54),
              ),
            ],
          ),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: 4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 16,
            crossAxisSpacing: 8,
            childAspectRatio: 0.75,
            children: [
              for (final a in AchievementService.all)
                GestureDetector(
                  onTap: () => _showAchievement(a, service.isUnlocked(a.id)),
                  child: Column(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: service.isUnlocked(a.id)
                              ? const Color(0xFFFFD54F)
                              : Colors.white.withValues(alpha: 0.06),
                        ),
                        child: Icon(
                          service.isUnlocked(a.id) ? a.icon : Icons.lock_rounded,
                          color: service.isUnlocked(a.id) ? const Color(0xFF2A2340) : Colors.white24,
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
                          fontWeight: FontWeight.w700,
                          color: service.isUnlocked(a.id) ? Colors.white : Colors.white38,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  void _showAchievement(Achievement a, bool unlocked) {
    SoundService().playKeyTap();
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF2A2340),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          content: Text(
            '${a.title}: ${a.description}${unlocked ? '' : ' (${AppStrings.locked})'}',
            style: GoogleFonts.nunito(fontWeight: FontWeight.w700, color: Colors.white),
          ),
        ),
      );
  }
}
