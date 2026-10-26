import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/leaderboard_service.dart';
import '../services/app_strings.dart';
import '../services/friends_service.dart';
import '../services/sound_service.dart';
import '../widgets/avatar_view.dart';
import '../widgets/banner_background.dart';
import '../models/banner_style.dart';
import '../widgets/chunky_button.dart';
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

/// Günlük, haftalık ve arkadaş listelerinin ortak satır modeli
class _RankRow {
  final int rank;
  final String userId;
  final String name;
  final String avatar;
  final String banner;
  final String score;
  final String? detail;

  const _RankRow(this.rank, this.userId, this.name, this.avatar, this.banner, this.score, this.detail);

  bool get isMe => userId == LeaderboardService().userId;
}

class _LeaderboardScreenState extends State<LeaderboardScreen> with SingleTickerProviderStateMixin {
  static const _medals = [Color(0xFFFFD54F), Color(0xFFCFD8DC), Color(0xFFD7A26C)];

  late TabController _tabController;
  late String _currentGameId;
  late String _currentGameName;

  List<LeaderboardEntry>? _dailyEntries;
  List<WeeklyLeaderboardEntry>? _weeklyEntries;
  bool _isDailyLoading = true;
  bool _isWeeklyLoading = true;

  LeaderboardEntry? _dailyUserEntry;
  int? _dailyUserRank;
  WeeklyLeaderboardEntry? _weeklyUserEntry;
  int? _weeklyUserRank;

  List<LeaderboardEntry>? _friendEntries;
  bool _isFriendsLoading = false;

  bool get _isDailyRun => _currentGameId.startsWith('daily_run');

  @override
  void initState() {
    super.initState();
    _currentGameId = widget.gameId;
    _currentGameName = widget.gameName;
    _tabController = TabController(length: 3, vsync: this);
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
    if (_tabController.index == 2 && _friendEntries == null && !_isFriendsLoading) {
      _loadFriends();
    }
  }

  // ─── Veri ───────────────────────────────────────────────────────
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
        userRank = await service.getUserRank(_currentGameId, userEntry.score, userEntry.durationMs);
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
        userRank = await service.getWeeklyUserRank(_currentGameId, userEntry.totalScore);
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

  Future<void> _loadFriends() async {
    setState(() => _isFriendsLoading = true);
    final friends = FriendsService();
    final ids = [LeaderboardService().userId, ...friends.friendIds];
    final entries = await LeaderboardService().getDailyEntriesForUsers(_currentGameId, ids);
    friends.rememberNames(entries);
    if (mounted) {
      setState(() {
        _friendEntries = entries;
        _isFriendsLoading = false;
      });
    }
  }

  void _switchDailyRunSlot(String newId, String newName) {
    if (newId == _currentGameId) return;
    SoundService().playKeyTap();
    setState(() {
      _currentGameId = newId;
      _currentGameName = newName;
      _weeklyEntries = null;
      _dailyEntries = null;
      _friendEntries = null;
    });
    _loadDailyLeaderboard();
    if (_tabController.index == 1) _loadWeeklyLeaderboard();
    if (_tabController.index == 2) _loadFriends();
  }

  Future<void> _showAddFriendDialog() async {
    final code = await showDialog<String>(
      context: context,
      builder: (ctx) => const _AddFriendDialog(),
    );
    if (code == null || code.trim().isEmpty || !mounted) return;
    final result = await FriendsService().addFromText(code);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text(AppStrings.addFriendResult(result), style: GoogleFonts.nunito(fontWeight: FontWeight.w700)),
      ),
    );
    if (result == AddFriendResult.added) _loadFriends();
  }

  Future<void> _confirmRemove(String id) async {
    final name = FriendsService().nameOf(id) ?? id.substring(0, 8).toUpperCase();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1B1B2F),
        content: Text(AppStrings.removeFriendQuestion(name), style: GoogleFonts.nunito(color: Colors.white)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(AppStrings.cancel)),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(AppStrings.remove, style: const TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (ok == true) {
      await FriendsService().remove(id);
      _loadFriends();
    }
  }

  String _formatDuration(int durationMs) {
    final seconds = (durationMs / 1000).truncate();
    return '${(seconds ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';
  }

  String _score(double v) => _isDailyRun ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

  _RankRow _dailyRow(int rank, LeaderboardEntry e) => _RankRow(rank, e.userId, e.displayName, e.avatar, e.banner,
      _score(e.score), e.durationMs != null ? _formatDuration(e.durationMs!) : null);

  _RankRow _weeklyRow(int rank, WeeklyLeaderboardEntry e) => _RankRow(
      rank, e.userId, e.displayName, e.avatar, e.banner, _score(e.totalScore), AppStrings.daysPlayed(e.daysPlayed));

  // ─── Ekran ──────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
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
                  _buildHeader(),
                  if (_isDailyRun) ...[
                    const SizedBox(height: 12),
                    _buildSlotToggle(),
                  ],
                  const SizedBox(height: 12),
                  _buildTabs(),
                  const SizedBox(height: 8),
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _isDailyLoading
                            ? _loading()
                            : _buildRanking(
                                rows: [
                                  for (var i = 0; i < (_dailyEntries ?? []).length; i++)
                                    _dailyRow(i + 1, _dailyEntries![i]),
                                ],
                                me: _dailyUserEntry != null && _dailyUserRank != null
                                    ? _dailyRow(_dailyUserRank!, _dailyUserEntry!)
                                    : null,
                                empty: AppStrings.noPlayersToday,
                              ),
                        _isWeeklyLoading
                            ? _loading()
                            : _buildRanking(
                                rows: [
                                  for (var i = 0; i < (_weeklyEntries ?? []).length; i++)
                                    _weeklyRow(i + 1, _weeklyEntries![i]),
                                ],
                                me: _weeklyUserEntry != null && _weeklyUserRank != null
                                    ? _weeklyRow(_weeklyUserRank!, _weeklyUserEntry!)
                                    : null,
                                empty: AppStrings.noPlayersWeek,
                              ),
                        _buildFriendsTab(),
                      ],
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

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.28), borderRadius: BorderRadius.circular(22)),
              child: const Icon(Icons.arrow_back_rounded, color: Colors.white),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(AppStrings.rankingShort,
                    style: GoogleFonts.nunito(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white, height: 1.1)),
                Text(
                  _currentGameName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white60),
                ),
              ],
            ),
          ),
          const Icon(Icons.emoji_events_rounded, color: Color(0xFFFFC233), size: 30),
        ],
      ),
    );
  }

  Widget _buildSlotToggle() {
    final morning = _currentGameId == 'daily_run_morning';
    Widget option(bool selected, IconData icon, String label, Color color, VoidCallback onTap) {
      return Expanded(
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            height: 38,
            decoration: BoxDecoration(
              color: selected ? color.withValues(alpha: 0.22) : Colors.transparent,
              borderRadius: BorderRadius.circular(19),
              border: Border.all(color: selected ? color : Colors.transparent, width: 1.5),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 16, color: selected ? color : Colors.white54),
                const SizedBox(width: 6),
                Text(label,
                    style: GoogleFonts.nunito(
                        fontSize: 14, fontWeight: FontWeight.w800, color: selected ? Colors.white : Colors.white54)),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.25), borderRadius: BorderRadius.circular(23)),
      child: Row(
        children: [
          option(morning, Icons.wb_sunny_rounded, AppStrings.morning, const Color(0xFFFFC857),
              () => _switchDailyRunSlot('daily_run_morning', AppStrings.dailyRunSlotName(1))),
          option(!morning, Icons.nightlight_round, AppStrings.evening, const Color(0xFFB9A8FF),
              () => _switchDailyRunSlot('daily_run_evening', AppStrings.dailyRunSlotName(2))),
        ],
      ),
    );
  }

  Widget _buildTabs() {
    final labels = [AppStrings.daily, AppStrings.weekly, AppStrings.friends];
    final icons = [Icons.today_rounded, Icons.date_range_rounded, Icons.group_rounded];
    final animation = _tabController.animation!;
    return Container(
      height: 50,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(18)),
      child: AnimatedBuilder(
        animation: animation,
        builder: (context, _) {
          final pos = animation.value; // 0..2, parmakla birlikte değişir
          return Stack(
            children: [
              Align(
                alignment: Alignment(-1 + pos, 0),
                child: FractionallySizedBox(
                  widthFactor: 1 / 3,
                  heightFactor: 1,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: const [BoxShadow(color: Color(0x40000000), blurRadius: 8, offset: Offset(0, 3))],
                    ),
                  ),
                ),
              ),
              Row(
                children: [
                  for (var i = 0; i < 3; i++)
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          SoundService().playKeyTap();
                          _tabController.animateTo(i);
                        },
                        child: Builder(builder: (context) {
                          // Göstergeye yakınlığa göre yazı rengi yumuşakça değişir
                          final t = (1 - (pos - i).abs()).clamp(0.0, 1.0);
                          final color = Color.lerp(Colors.white60, const Color(0xFF3A0F6E), t)!;
                          return Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(icons[i], size: 17, color: color),
                              const SizedBox(width: 5),
                              Flexible(
                                child: Text(
                                  labels[i],
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.w900, color: color),
                                ),
                              ),
                            ],
                          );
                        }),
                      ),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _loading() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      physics: const NeverScrollableScrollPhysics(),
      children: List.generate(
        7,
        (i) => Container(
          height: i == 0 ? 150 : 62,
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(18)),
        ),
      ),
    );
  }

  Widget _buildEmpty(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.emoji_events_rounded, size: 72, color: Colors.white.withValues(alpha: 0.2)),
            const SizedBox(height: 12),
            Text(message,
                textAlign: TextAlign.center,
                style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white60)),
            const SizedBox(height: 20),
            ChunkyButton(
              face: const Color(0xFF3DDC84),
              lip: const Color(0xFF1E9E55),
              height: 52,
              onTap: () => Navigator.pop(context),
              child: Text(AppStrings.playNow,
                  style: GoogleFonts.nunito(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRanking({required List<_RankRow> rows, required _RankRow? me, required String empty}) {
    if (rows.isEmpty) return _buildEmpty(empty);
    final podium = rows.take(3).toList();
    final rest = rows.skip(3).toList();
    final meVisible = rows.any((r) => r.isMe);

    return Column(
      children: [
        Expanded(
          child: ListView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            children: [
              _buildPodium(podium),
              if (rest.isNotEmpty) ...[
                const SizedBox(height: 16),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    children: [
                      for (var i = 0; i < rest.length; i++) ...[
                        if (i > 0) Divider(height: 1, indent: 64, color: Colors.white.withValues(alpha: 0.06)),
                        _buildRow(rest[i]),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        if (!meVisible && me != null)
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
            decoration: BoxDecoration(
              color: const Color(0xFF120C2C),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 16, offset: const Offset(0, -6))],
            ),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF6C4BFF).withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(18),
              ),
              child: _buildRow(me),
            ),
          ),
      ],
    );
  }

  Widget _buildPodium(List<_RankRow> top) {
    // Sıra: 2 - 1 - 3
    final order = [if (top.length > 1) top[1], top[0], if (top.length > 2) top[2]];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (final r in order)
          Expanded(
            child: GestureDetector(
              onTap: () => _showPlayerCard(r),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (r.rank == 1) const Icon(Icons.workspace_premium_rounded, color: Color(0xFFFFD54F), size: 30),
                  AvatarView(avatar: r.avatar, size: r.rank == 1 ? 78 : 62, ring: _medals[r.rank - 1]),
                  const SizedBox(height: 6),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      r.isMe ? AppStrings.you : r.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.nunito(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: r.isMe ? const Color(0xFF7CF5C4) : Colors.white,
                      ),
                    ),
                  ),
                  Text(
                    r.score,
                    style: GoogleFonts.nunito(fontSize: 15, fontWeight: FontWeight.w900, color: _medals[r.rank - 1]),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    height: [84.0, 62.0, 48.0][r.rank - 1],
                    margin: const EdgeInsets.symmetric(horizontal: 5),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [_medals[r.rank - 1], Color.lerp(_medals[r.rank - 1], Colors.black, 0.45)!],
                      ),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${r.rank}',
                      style: GoogleFonts.nunito(
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        shadows: const [Shadow(color: Color(0x55000000), offset: Offset(0, 2))],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  /// Sade satır: sıra, avatar, isim, skor. Banner sağ tarafta soluklaşarak görünür.
  Widget _buildRow(_RankRow r, {VoidCallback? onLongPress}) {
    final banner = BannerStyle.byId(r.banner);
    return GestureDetector(
      onTap: () => _showPlayerCard(r),
      onLongPress: onLongPress,
      child: SizedBox(
        height: 62,
        child: Stack(
          children: [
            if (banner.asset != null)
              Positioned.fill(
                child: FractionallySizedBox(
                  widthFactor: 0.55,
                  alignment: Alignment.centerRight,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: ShaderMask(
                      blendMode: BlendMode.dstIn,
                      shaderCallback: (rect) => const LinearGradient(
                        colors: [Colors.transparent, Color(0xCC000000)],
                      ).createShader(rect),
                      child: Image.asset(banner.asset!, fit: BoxFit.cover, cacheWidth: 600),
                    ),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  SizedBox(
                    width: 30,
                    child: Text(
                      '${r.rank}',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.nunito(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: r.rank <= 3 ? _medals[r.rank - 1] : Colors.white60,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  AvatarView(avatar: r.avatar, size: 42, ring: r.isMe ? const Color(0xFF7CF5C4) : null),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          r.isMe ? AppStrings.you : r.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.nunito(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            color: r.isMe ? const Color(0xFF7CF5C4) : Colors.white,
                          ),
                        ),
                        if (r.detail != null)
                          Text(r.detail!,
                              style: GoogleFonts.nunito(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white54)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      r.score,
                      style: GoogleFonts.nunito(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        fontFeatures: const [FontFeature.tabularFigures()],
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

  /// Oyuncu kartı: banner'ı tam gösterir (banner'ların vitrini burası).
  void _showPlayerCard(_RankRow r) {
    SoundService().playKeyTap();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 24),
        decoration: BoxDecoration(color: const Color(0xFF1C1640), borderRadius: BorderRadius.circular(28)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.bottomCenter,
              children: [
                AspectRatio(
                  aspectRatio: 10 / 3.6,
                  child: BannerBackground(
                    bannerId: r.banner,
                    scrim: false,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                    child: const SizedBox.expand(),
                  ),
                ),
                Positioned(
                  bottom: -40,
                  child: AvatarView(avatar: r.avatar, size: 84, ring: const Color(0xFF1C1640)),
                ),
              ],
            ),
            const SizedBox(height: 48),
            Text(
              r.isMe ? '${r.name} (${AppStrings.you})' : r.name,
              style: GoogleFonts.nunito(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white),
            ),
            Text(BannerStyle.byId(r.banner).name,
                style: GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white54)),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 22),
              child: Row(
                children: [
                  _cardStat(AppStrings.ranking, '#${r.rank}'),
                  _cardStat(AppStrings.totalScore, r.score),
                  if (r.detail != null) _cardStat(_tabController.index == 1 ? AppStrings.days : AppStrings.time, r.detail!),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cardStat(String label, String value) => Expanded(
        child: Column(
          children: [
            Text(value, style: GoogleFonts.nunito(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white)),
            Text(label, style: GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white54)),
          ],
        ),
      );

  Widget _buildFriendsTab() {
    final friends = FriendsService();
    final buttons = Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
      child: Row(
        children: [
          Expanded(
            child: ChunkyButton(
              face: const Color(0xFF4F8BFF),
              lip: const Color(0xFF2E5BC4),
              height: 50,
              radius: 16,
              onTap: friends.shareMyCode,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.ios_share_rounded, color: Colors.white, size: 20),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(AppStrings.shareMyCode,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w900, color: Colors.white)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ChunkyButton(
              face: const Color(0xFF3DDC84),
              lip: const Color(0xFF1E9E55),
              height: 50,
              radius: 16,
              onTap: _showAddFriendDialog,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.person_add_alt_1_rounded, color: Colors.white, size: 20),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(AppStrings.addFriend,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w900, color: Colors.white)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );

    if (friends.friendIds.isEmpty) {
      return Column(
        children: [
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.group_add_rounded, size: 72, color: Colors.white.withValues(alpha: 0.2)),
                    const SizedBox(height: 12),
                    Text(AppStrings.noFriendsYet,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white60)),
                  ],
                ),
              ),
            ),
          ),
          buttons,
        ],
      );
    }
    if (_isFriendsLoading || _friendEntries == null) return _loading();

    final played = _friendEntries!.map((e) => e.userId).toSet();
    final notPlayed = friends.friendIds.where((id) => !played.contains(id)).toList();

    return Column(
      children: [
        Expanded(
          child: ListView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            children: [
              for (var i = 0; i < _friendEntries!.length; i++)
                Builder(builder: (context) {
                  final row = _dailyRow(i + 1, _friendEntries![i]);
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: _buildRow(row, onLongPress: row.isMe ? null : () => _confirmRemove(row.userId)),
                  );
                }),
              for (final id in notPlayed)
                GestureDetector(
                  onLongPress: () => _confirmRemove(id),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    height: 56,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.hourglass_empty_rounded, color: Colors.white24, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            friends.nameOf(id) ?? '${id.substring(0, 8).toUpperCase()}…',
                            style: GoogleFonts.nunito(color: Colors.white54, fontWeight: FontWeight.w800),
                          ),
                        ),
                        Text(AppStrings.notPlayedToday,
                            style: GoogleFonts.nunito(color: Colors.white38, fontSize: 12, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  AppStrings.longPressToRemove,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white38),
                ),
              ),
            ],
          ),
        ),
        buttons,
      ],
    );
  }
}

/// Controller'ı kendi yaşam döngüsünde tutar; dialog kapanış animasyonu
/// bitmeden dispose edilip "used after being disposed" hatası oluşmaz.
class _AddFriendDialog extends StatefulWidget {
  const _AddFriendDialog();

  @override
  State<_AddFriendDialog> createState() => _AddFriendDialogState();
}

class _AddFriendDialogState extends State<_AddFriendDialog> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1B1B2F),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(AppStrings.addFriend, style: GoogleFonts.nunito(color: Colors.white, fontWeight: FontWeight.w800)),
      content: TextField(
        controller: _controller,
        autofocus: true,
        style: GoogleFonts.nunito(color: Colors.white),
        decoration: InputDecoration(
          hintText: AppStrings.pasteFriendCode,
          hintStyle: GoogleFonts.nunito(color: Colors.white38),
          filled: true,
          fillColor: Colors.white.withValues(alpha: 0.06),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(AppStrings.cancel, style: GoogleFonts.nunito(color: Colors.white54)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, _controller.text),
          child: Text(AppStrings.add, style: GoogleFonts.nunito(color: Colors.greenAccent, fontWeight: FontWeight.w800)),
        ),
      ],
    );
  }
}
