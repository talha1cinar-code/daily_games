import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/leaderboard_service.dart';
import '../services/app_strings.dart';
import '../widgets/logo_background.dart';

class LeaderboardScreen extends StatefulWidget {
  final String gameId;
  final String gameName;

  const LeaderboardScreen({
    super.key,
    required this.gameId,
    required this.gameName,
  });

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late String _currentGameId;

  List<LeaderboardEntry>? _dailyEntries;
  List<WeeklyLeaderboardEntry>? _weeklyEntries;
  bool _isDailyLoading = true;
  bool _isWeeklyLoading = true;

  LeaderboardEntry? _dailyUserEntry;
  int? _dailyUserRank;
  WeeklyLeaderboardEntry? _weeklyUserEntry;
  int? _weeklyUserRank;

  @override
  void initState() {
    super.initState();
    _currentGameId = widget.gameId;
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_onTabChanged);
    _loadDailyLeaderboard();
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (_tabController.index == 1 && _weeklyEntries == null) {
      _loadWeeklyLeaderboard();
    }
  }

  Future<void> _loadDailyLeaderboard() async {
    setState(() => _isDailyLoading = true);
    final service = LeaderboardService();
    final entries = await service.getDailyLeaderboard(_currentGameId);

    LeaderboardEntry? userEntry;
    int? userRank;

    final userIndex = entries.indexWhere((e) => e.userId == service.userId);
    if (userIndex != -1) {
      userEntry = entries[userIndex];
      userRank = userIndex + 1;
    } else {
      userEntry = await service.getUserEntry(_currentGameId);
      if (userEntry != null) {
        userRank = await service.getUserRank(
            _currentGameId, userEntry.score, userEntry.durationMs);
      }
    }

    if (mounted) {
      setState(() {
        _dailyEntries = entries;
        _dailyUserEntry = userEntry;
        _dailyUserRank = userRank;
        _isDailyLoading = false;
      });
    }
  }

  Future<void> _loadWeeklyLeaderboard() async {
    setState(() => _isWeeklyLoading = true);
    final service = LeaderboardService();
    final entries = await service.getWeeklyLeaderboard(_currentGameId);

    WeeklyLeaderboardEntry? userEntry;
    int? userRank;

    final userIndex = entries.indexWhere((e) => e.userId == service.userId);
    if (userIndex != -1) {
      userEntry = entries[userIndex];
      userRank = userIndex + 1;
    } else {
      userEntry = await service.getWeeklyUserEntry(_currentGameId);
      if (userEntry != null) {
        userRank =
            await service.getWeeklyUserRank(_currentGameId, userEntry.totalScore);
      }
    }

    if (mounted) {
      setState(() {
        _weeklyEntries = entries;
        _weeklyUserEntry = userEntry;
        _weeklyUserRank = userRank;
        _isWeeklyLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
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
      child: Scaffold(
        backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
            ),
            child: const Icon(Icons.close, color: Colors.white, size: 20),
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          const LogoBackground(),
          SafeArea(
            child: Column(
          children: [
            const SizedBox(height: 16),
            // Header
            Text(
              'LEADERBOARD',
              style: GoogleFonts.nunito(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: Colors.greenAccent,
                letterSpacing: 2,
                shadows: [
                  Shadow(
                    color: Colors.greenAccent.withValues(alpha: 0.6),
                    blurRadius: 12,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            if (_currentGameId.startsWith('daily_run')) _buildDailyRunToggle(),
            if (_currentGameId.startsWith('daily_run')) const SizedBox(height: 16),

            // Tab Bar
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.purpleAccent, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.purpleAccent.withValues(alpha: 0.3),
                      blurRadius: 8,
                    ),
                  ],
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                labelColor: Colors.purpleAccent,
                unselectedLabelColor: Colors.white54,
                labelStyle:
                    GoogleFonts.nunito(fontWeight: FontWeight.w800, fontSize: 14),
                unselectedLabelStyle:
                    GoogleFonts.nunito(fontWeight: FontWeight.w600, fontSize: 14),
                tabs: [
                  Tab(text: AppStrings.daily),
                  Tab(text: AppStrings.weekly),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Tab içerikleri
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildDailyTab(),
                  _buildWeeklyTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    ],
  ),
));
  }

  Widget _buildDailyTab() {
    if (_isDailyLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.purpleAccent),
      );
    }

    if (_dailyEntries == null || _dailyEntries!.isEmpty) {
      return _buildEmptyState(AppStrings.noPlayersToday);
    }

    final isUserInList =
        _dailyEntries!.any((e) => e.userId == LeaderboardService().userId);

    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            itemCount: _dailyEntries!.length,
            itemBuilder: (context, index) {
              final entry = _dailyEntries![index];
              final isCurrentUser = entry.userId == LeaderboardService().userId;
              return _buildDailyEntryRow(index + 1, entry, isCurrentUser);
            },
          ),
        ),

        // User Sticky Row
        if (!isUserInList && _dailyUserEntry != null && _dailyUserRank != null)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF0B0514),
              boxShadow: [
                BoxShadow(
                  color: Colors.purpleAccent.withValues(alpha: 0.1),
                  blurRadius: 20,
                  offset: const Offset(0, -10),
                ),
              ],
            ),
            child: _buildDailyEntryRow(_dailyUserRank!, _dailyUserEntry!, true),
          ),
      ],
    );
  }

  Widget _buildWeeklyTab() {
    if (_isWeeklyLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.purpleAccent),
      );
    }

    if (_weeklyEntries == null || _weeklyEntries!.isEmpty) {
      return _buildEmptyState(AppStrings.noPlayersWeek);
    }

    final isUserInList =
        _weeklyEntries!.any((e) => e.userId == LeaderboardService().userId);

    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            itemCount: _weeklyEntries!.length,
            itemBuilder: (context, index) {
              final entry = _weeklyEntries![index];
              final isCurrentUser = entry.userId == LeaderboardService().userId;
              return _buildWeeklyEntryRow(index + 1, entry, isCurrentUser);
            },
          ),
        ),

        // User Sticky Row
        if (!isUserInList && _weeklyUserEntry != null && _weeklyUserRank != null)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF0B0514),
              boxShadow: [
                BoxShadow(
                  color: Colors.purpleAccent.withValues(alpha: 0.1),
                  blurRadius: 20,
                  offset: const Offset(0, -10),
                ),
              ],
            ),
            child: _buildWeeklyEntryRow(_weeklyUserRank!, _weeklyUserEntry!, true),
          ),
      ],
    );
  }

  Widget _buildDailyEntryRow(int rank, LeaderboardEntry entry, bool isCurrentUser) {
    return _buildRankCard(
      rank: rank,
      avatar: entry.avatar,
      displayName: entry.displayName,
      score: entry.score.toStringAsFixed(1),
      isCurrentUser: isCurrentUser,
      durationMs: entry.durationMs,
    );
  }

  Widget _buildWeeklyEntryRow(
      int rank, WeeklyLeaderboardEntry entry, bool isCurrentUser) {
    return _buildRankCard(
      rank: rank,
      avatar: entry.avatar,
      displayName: entry.displayName,
      score: entry.totalScore.toStringAsFixed(1),
      isCurrentUser: isCurrentUser,
      daysPlayed: entry.daysPlayed,
    );
  }

  Widget _buildRankCard({
    required int rank,
    required String avatar,
    required String displayName,
    required String score,
    required bool isCurrentUser,
    int? durationMs,
    int? daysPlayed,
  }) {
    // Determine neon colors
    Color borderColor;
    Color shadowColor;
    
    if (rank == 1) {
      borderColor = Colors.yellowAccent;
      shadowColor = Colors.yellowAccent.withValues(alpha: 0.4);
    } else if (rank == 2) {
      borderColor = Colors.redAccent;
      shadowColor = Colors.redAccent.withValues(alpha: 0.4);
    } else if (rank == 3) {
      borderColor = Colors.greenAccent;
      shadowColor = Colors.greenAccent.withValues(alpha: 0.4);
    } else {
      borderColor = Colors.grey.shade800;
      shadowColor = Colors.transparent;
    }

    // Is current user override for normal ranks
    if (isCurrentUser && rank > 3) {
      borderColor = Colors.purpleAccent;
      shadowColor = Colors.purpleAccent.withValues(alpha: 0.3);
    }
    
    // Determine padding and font sizes based on rank
    double verticalPadding = 8;
    double nameFontSize = 14;
    
    if (rank == 1) {
      verticalPadding = 20;
      nameFontSize = 20;
    } else if (rank == 2) {
      verticalPadding = 16;
      nameFontSize = 18;
    } else if (rank == 3) {
      verticalPadding = 12;
      nameFontSize = 16;
    }

    Widget card = Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: verticalPadding),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: borderColor,
          width: rank <= 3 ? 2 : 1,
        ),
        boxShadow: shadowColor != Colors.transparent ? [
          BoxShadow(
            color: shadowColor,
            blurRadius: rank == 1 ? 15 : 10,
            spreadRadius: rank == 1 ? 2 : 0,
          )
        ] : null,
      ),
      child: Row(
        children: [
          // Rank
          SizedBox(
            width: 32,
            child: Text(
              rank.toString(),
              style: GoogleFonts.nunito(
                fontSize: nameFontSize + 2,
                fontWeight: FontWeight.w900,
                color: rank <= 3 ? borderColor : Colors.white70,
                shadows: rank <= 3 ? [
                  Shadow(
                    color: borderColor,
                    blurRadius: 8,
                  )
                ] : null,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 12),

          // Name
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  isCurrentUser ? AppStrings.you : displayName.toUpperCase(),
                  style: GoogleFonts.nunito(
                    fontSize: nameFontSize,
                    fontWeight: FontWeight.w800,
                    color: Colors.greenAccent, // Green text as in image
                    letterSpacing: 1,
                    shadows: [
                      Shadow(
                        color: Colors.greenAccent.withValues(alpha: 0.5),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (durationMs != null || daysPlayed != null)
                  Text(
                    durationMs != null
                        ? _formatDuration(durationMs)
                        : AppStrings.daysPlayed(daysPlayed!),
                    style: GoogleFonts.nunito(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.white54,
                    ),
                  ),
              ],
            ),
          ),

          // Score
          Text(
            score,
            style: GoogleFonts.nunito(
              fontSize: nameFontSize + 2,
              fontWeight: FontWeight.w900,
              color: Colors.greenAccent,
              shadows: [
                Shadow(
                  color: Colors.greenAccent.withValues(alpha: 0.5),
                  blurRadius: 4,
                ),
              ],
            ),
          ),
        ],
      ),
    );

    if (rank == 1) {
      return _PulseWidget(child: card);
    }
    return card;
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.emoji_events_outlined,
            size: 64,
            color: Colors.purpleAccent.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: GoogleFonts.nunito(
              fontSize: 16,
              color: Colors.white54,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  String _formatDuration(int durationMs) {
    final seconds = (durationMs / 1000).truncate();
    final m = (seconds / 60).truncate();
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Widget _buildDailyRunToggle() {
    final isMorning = _currentGameId == 'daily_run_morning';
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () {
                if (!isMorning) {
                  _switchDailyRunSlot('daily_run_morning', AppStrings.dailyRunSlotName(1));
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: isMorning ? Colors.orangeAccent.withValues(alpha: 0.1) : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isMorning ? Colors.orangeAccent : Colors.white.withValues(alpha: 0.1),
                    width: isMorning ? 2 : 1,
                  ),
                  boxShadow: isMorning ? [
                    BoxShadow(
                      color: Colors.orangeAccent.withValues(alpha: 0.3),
                      blurRadius: 8,
                    )
                  ] : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.wb_sunny_rounded,
                        color: isMorning ? Colors.orangeAccent : Colors.white54,
                        size: 20),
                    const SizedBox(width: 8),
                    Text(AppStrings.daytime,
                        style: GoogleFonts.nunito(
                          color: isMorning ? Colors.orangeAccent : Colors.white54,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1,
                        )),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: GestureDetector(
              onTap: () {
                if (isMorning) {
                  _switchDailyRunSlot('daily_run_evening', AppStrings.dailyRunSlotName(2));
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: !isMorning ? Colors.indigoAccent.withValues(alpha: 0.1) : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: !isMorning ? Colors.indigoAccent : Colors.white.withValues(alpha: 0.1),
                    width: !isMorning ? 2 : 1,
                  ),
                  boxShadow: !isMorning ? [
                    BoxShadow(
                      color: Colors.indigoAccent.withValues(alpha: 0.3),
                      blurRadius: 8,
                    )
                  ] : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.nightlight_round,
                        color: !isMorning ? Colors.indigoAccent : Colors.white54,
                        size: 20),
                    const SizedBox(width: 8),
                    Text(AppStrings.night,
                        style: GoogleFonts.nunito(
                          color: !isMorning ? Colors.indigoAccent : Colors.white54,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1,
                        )),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _switchDailyRunSlot(String newId, String newName) {
    setState(() {
      _currentGameId = newId;
      _isDailyLoading = true;
      _isWeeklyLoading = true;
      _weeklyEntries = null;
      _dailyEntries = null;
    });
    _loadDailyLeaderboard();
    if (_tabController.index == 1) {
      _loadWeeklyLeaderboard();
    }
  }
}

class _PulseWidget extends StatefulWidget {
  final Widget child;
  const _PulseWidget({required this.child});

  @override
  State<_PulseWidget> createState() => _PulseWidgetState();
}

class _PulseWidgetState extends State<_PulseWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.03).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: widget.child,
    );
  }
}
