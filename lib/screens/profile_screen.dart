import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';

import '../services/stats_service.dart';
import '../services/leaderboard_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  int _dailyRunStreak = 0;
  int _bestDailyRunRank = -1;

  // Daily Run
  List<GameStat> _dailyRunHistory = [];
  final Map<String, int?> _dailyRunRanks = {};

  @override
  void initState() {
    super.initState();
    _loadStats();
    _loadDailyRanks();
  }

  void _loadStats() {
    _dailyRunHistory = StatsService().getStats('daily_run');
    _dailyRunHistory.sort((a, b) => b.date.compareTo(a.date));

    final summary = StatsService().getSummary('daily_run');

    setState(() {
      _dailyRunStreak = summary['streak'] as int;
    });
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

  Widget _buildDailyRunHistory() {
    final summary = StatsService().getSummary('daily_run');
    final streak = summary['streak'];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF007F).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFF007F)),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF007F).withValues(alpha: 0.3),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: Text(
                  'Seri: $streak 🔥',
                  style: GoogleFonts.nunito(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
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
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatBox(
              'Güncel Seri',
              '$_dailyRunStreak 🔥',
              Icons.local_fire_department_rounded,
              const Color(0xFFFF3333), // Neon Red
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
