import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';

import '../services/stats_service.dart';
import '../services/leaderboard_service.dart';
import '../services/streak_service.dart';
import '../services/ad_service.dart';
import '../services/sound_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with TickerProviderStateMixin {
  int _bestDailyRunRank = -1;

  // Daily Run
  List<GameStat> _dailyRunHistory = [];
  final Map<String, int?> _dailyRunRanks = {};

  // Animasyonlar
  late AnimationController _streakPulseController;
  late Animation<double> _streakPulseAnimation;
  late AnimationController _fireController;
  late Animation<double> _fireAnimation;

  @override
  void initState() {
    super.initState();
    _loadStats();
    _loadDailyRanks();

    _streakPulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    _streakPulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _streakPulseController, curve: Curves.easeInOut),
    );

    _fireController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..repeat(reverse: true);
    _fireAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fireController, curve: Curves.easeInOut),
    );

    // StreakService değişikliklerini dinle
    StreakService().addListener(_onStreakChanged);
  }

  void _onStreakChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _streakPulseController.dispose();
    _fireController.dispose();
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
              _updateBestRank();
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

  void _updateBestRank() {
    int bestRank = -1;
    for (final rank in _dailyRunRanks.values) {
      if (rank != null && rank != -1) {
        if (bestRank == -1 || rank < bestRank) {
          bestRank = rank;
        }
      }
    }
    _bestDailyRunRank = bestRank;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF050505),
        gradient: RadialGradient(
          center: Alignment.center,
          radius: 1.5,
          colors: [
            Color(0xFF1A0B2E), // Subtle dark purple center
            Color(0xFF050505), // Almost black edges
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
            'Profil ve İstatistikler',
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
        body: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: _buildHeader()),
            SliverToBoxAdapter(child: _buildStreakCard()),
            SliverToBoxAdapter(child: _buildOverallStats()),
            SliverToBoxAdapter(child: _buildDailyRunHistory()),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final displayName = LeaderboardService().displayName;
    const glowColor = Color(0xFFFF007F); // Neon Pink

    return Container(
      margin: const EdgeInsets.all(24),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: glowColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: glowColor, width: 2.5),
        boxShadow: [
          BoxShadow(
            color: glowColor.withValues(alpha: 0.4),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: glowColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
              border: Border.all(color: glowColor, width: 1.5),
            ),
            child: Text(
              LeaderboardService().avatar,
              style: const TextStyle(fontSize: 40),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hoş Geldin,',
                  style: GoogleFonts.nunito(
                    fontSize: 14,
                    color: Colors.white70,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  displayName,
                  style: GoogleFonts.nunito(
                    fontSize: 22,
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    shadows: [
                      Shadow(
                        color: glowColor,
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── BÜYÜK SERİ KARTI ──────────────────────────────────────────
  Widget _buildStreakCard() {
    final streak = StreakService().currentStreak;
    final bestStreak = StreakService().bestStreak;
    final freezeCount = StreakService().freezeCount;
    final canRestore = StreakService().canRestoreStreak;
    final lostStreak = StreakService().lostStreak;

    // Seri rengini belirle
    Color streakColor;
    if (streak >= 30) {
      streakColor = const Color(0xFFFF6B00); // Turuncu ateş
    } else if (streak >= 14) {
      streakColor = const Color(0xFFFF3D00); // Kırmızı ateş
    } else if (streak >= 7) {
      streakColor = const Color(0xFFFF9100); // Sarı-turuncu
    } else {
      streakColor = const Color(0xFFFF6E40); // Açık turuncu
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            streakColor.withValues(alpha: 0.15),
            const Color(0xFF1A0B2E).withValues(alpha: 0.8),
            streakColor.withValues(alpha: 0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: streakColor.withValues(alpha: 0.6),
          width: 2.5,
        ),
        boxShadow: [
          BoxShadow(
            color: streakColor.withValues(alpha: 0.3),
            blurRadius: 24,
            spreadRadius: 3,
          ),
          BoxShadow(
            color: streakColor.withValues(alpha: 0.1),
            blurRadius: 48,
            spreadRadius: 8,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Ateş ikonu + Seri sayısı
            AnimatedBuilder(
              animation: _streakPulseAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: streak > 0 ? _streakPulseAnimation.value : 1.0,
                  child: child,
                );
              },
              child: Column(
                children: [
                  // Ateş ikonu
                  AnimatedBuilder(
                    animation: _fireAnimation,
                    builder: (context, child) {
                      return ShaderMask(
                        shaderCallback: (bounds) => LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Color.lerp(
                              const Color(0xFFFFEB3B),
                              const Color(0xFFFF9800),
                              _fireAnimation.value,
                            )!,
                            Color.lerp(
                              const Color(0xFFFF5722),
                              const Color(0xFFE64A19),
                              _fireAnimation.value,
                            )!,
                          ],
                        ).createShader(bounds),
                        child: Icon(
                          Icons.local_fire_department_rounded,
                          size: 64,
                          color: Colors.white,
                          shadows: [
                            Shadow(
                              color: streakColor.withValues(alpha: 0.8),
                              blurRadius: 20,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  // Seri sayısı
                  Text(
                    '$streak',
                    style: GoogleFonts.montserrat(
                      fontSize: 56,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      height: 1,
                      shadows: [
                        Shadow(
                          color: streakColor,
                          blurRadius: 16,
                        ),
                        Shadow(
                          color: streakColor.withValues(alpha: 0.5),
                          blurRadius: 32,
                        ),
                      ],
                    ),
                  ),
                  Text(
                    'Günlük Seri',
                    style: GoogleFonts.nunito(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // Donma hakkı + En iyi seri
            Row(
              children: [
                Expanded(
                  child: _buildStreakInfoBox(
                    icon: Icons.ac_unit_rounded,
                    label: 'Donma Hakkı',
                    value: '$freezeCount',
                    color: const Color(0xFF40C4FF),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStreakInfoBox(
                    icon: Icons.emoji_events_rounded,
                    label: 'En İyi Seri',
                    value: '$bestStreak',
                    color: const Color(0xFFFFD740),
                  ),
                ),
              ],
            ),
            // Seri geri getirme butonu
            if (canRestore) ...[
              const SizedBox(height: 16),
              _buildRestoreStreakButton(lostStreak, streakColor),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStreakInfoBox({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 1.5),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 22, shadows: [Shadow(color: color, blurRadius: 6)]),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: GoogleFonts.montserrat(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  shadows: [Shadow(color: color, blurRadius: 8)],
                ),
              ),
              Text(
                label,
                style: GoogleFonts.nunito(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.white54,
                ),
              ),
            ],
          ),
        ],
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
              'Seriyi Geri Getir ($lostStreak 🔥)',
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
                'Seriyi Geri Getir!',
                style: GoogleFonts.nunito(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Bir reklam izleyerek $lostStreak günlük serini geri getirebilirsin!',
                style: GoogleFonts.nunito(
                  fontSize: 14,
                  color: Colors.white70,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Bu hak kısıtlı sürelidir.',
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
                    'Reklam İzle ve Geri Getir',
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
                  'Vazgeç',
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
    );
  }

  void _watchAdAndRestore() {
    AdService().showRewardedAd(
      onUserEarnedReward: () async {
        final success = await StreakService().restoreStreakWithAd();
        if (mounted && success) {
          SoundService().playWin();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Serin geri geldi! 🔥',
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

  Widget _buildDailyRunHistory() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Daily Run Geçmişi',
            style: GoogleFonts.nunito(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              shadows: [
                const Shadow(
                  color: Color(0xFFFF007F), // Neon Pink
                  blurRadius: 8,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (_dailyRunHistory.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: Text(
                'Henüz Daily Run geçmişiniz bulunmuyor.\nİlk Daily Run\'ınızı tamamlayın!',
                style: GoogleFonts.nunito(
                  fontSize: 14,
                  color: Colors.white54,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            )
          else
            // Sadece son 5 Daily Run gösterilsin
            ..._dailyRunHistory.take(5).map((stat) {
              final rank = _dailyRunRanks[stat.date];
              return _buildDailyRunCard(stat, rank);
            }),
        ],
      ),
    );
  }

  Widget _buildDailyRunCard(GameStat stat, int? rank) {
    const glowColor = Color(0xFFFF007F); // Neon Pink
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: glowColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: glowColor.withValues(alpha: 0.4), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: glowColor.withValues(alpha: 0.1),
            blurRadius: 8,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: glowColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: glowColor.withValues(alpha: 0.8), width: 1.5),
            ),
            child: const Icon(Icons.directions_run_rounded, color: Colors.white, size: 24, shadows: [Shadow(color: glowColor, blurRadius: 8)]),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  stat.date,
                  style: GoogleFonts.nunito(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    shadows: [Shadow(color: glowColor.withValues(alpha: 0.5), blurRadius: 6)],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${stat.targetValue ?? "Bilinmiyor"} • Puan: ${stat.score.toStringAsFixed(1)}',
                  style: GoogleFonts.nunito(
                    fontSize: 12,
                    color: Colors.white70,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          // Sıralama durumu
          _buildRankWidget(rank),
        ],
      ),
    );
  }

  Widget _buildOverallStats() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          Expanded(
            child: _buildStatBox(
              'Tamamlanan',
              _dailyRunHistory.length.toString(),
              Icons.check_circle_outline_rounded,
              const Color(0xFF00FFFF), // Neon Cyan
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatBox(
              'En İyi Sıra',
              _bestDailyRunRank == -1 ? '-' : '#$_bestDailyRunRank',
              Icons.emoji_events_rounded,
              const Color(0xFFFFE81F), // Neon Yellow
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatBox(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color, width: 2),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.3),
            blurRadius: 12,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28, shadows: [Shadow(color: color, blurRadius: 8)]),
          const SizedBox(height: 12),
          Text(
            value,
            style: GoogleFonts.nunito(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              shadows: [Shadow(color: color, blurRadius: 8)],
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.nunito(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Colors.white70,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildRankWidget(int? rank) {
    if (rank == null) {
      // Yükleniyor durumu - Shimmer efekti
      return Shimmer.fromColors(
        baseColor: Colors.white.withValues(alpha: 0.1),
        highlightColor: Colors.white.withValues(alpha: 0.3),
        child: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      );
    }

    if (rank == -1) {
      // Henüz oynanmadı
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Column(
          children: [
            const Icon(Icons.videogame_asset_off_rounded, color: Colors.white38, size: 20),
            const SizedBox(height: 4),
            Text(
              'Oynanmadı',
              style: GoogleFonts.nunito(
                fontSize: 10,
                color: Colors.white38,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    // Sıralamada var
    final isTop3 = rank <= 3;
    final color = isTop3 ? const Color(0xFFFFE81F) : const Color(0xFF00FFFF);
    
    return Container(
      width: 60,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.2),
            blurRadius: 8,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            isTop3 ? ['🥇', '🥈', '🥉'][rank - 1] : '#$rank',
            style: GoogleFonts.nunito(
              fontSize: isTop3 ? 20 : 16,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              shadows: [
                Shadow(color: color, blurRadius: 10),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
