import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/duel.dart';
import '../models/game_model.dart';
import '../services/app_strings.dart';
import '../services/duel_service.dart';
import '../services/friends_service.dart';
import '../services/language_service.dart';
import '../services/sound_service.dart';
import '../utils/network_utils.dart';
import '../widgets/avatar_view.dart';
import '../widgets/banner_background.dart';
import '../widgets/chunky_button.dart';
import 'duel_detail_screen.dart';

/// Düello lobisi: lig durumu, rakip bulma, arkadaş daveti, düellolar.
class DuelScreen extends StatefulWidget {
  const DuelScreen({super.key});

  @override
  State<DuelScreen> createState() => _DuelScreenState();
}

class _DuelScreenState extends State<DuelScreen> {
  @override
  void initState() {
    super.initState();
    DuelService().addListener(_onChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _announceResults());
  }

  @override
  void dispose() {
    DuelService().removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (!mounted) return;
    setState(() {});
    _announceResults();
  }

  void _announceResults() {
    for (final (d, r) in DuelService().takeNewResults()) {
      final (trophies, coins) = DuelRewards.of(r);
      final name = d.names[d.opponentOf(DuelService().me)] ?? '?';
      switch (r) {
        case DuelResult.win:
          SoundService().playWin();
        case DuelResult.loss:
          SoundService().playLose();
        case DuelResult.draw:
          SoundService().playCorrect();
      }
      _toast(AppStrings.duelResultToast(r, name, trophies, coins));
    }
  }

  void _toast(String text, {bool error = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: error ? Colors.redAccent : const Color(0xFF2A2340),
        content: Text(text, style: GoogleFonts.nunito(fontWeight: FontWeight.w800, color: Colors.white)),
      ));
  }

  Future<void> _findMatch() async {
    if (!await NetworkUtils.checkInternet()) {
      _toast(AppStrings.duelNeedsInternet, error: true);
      return;
    }
    try {
      await DuelService().findMatch();
    } catch (_) {
      _toast(AppStrings.duelError, error: true);
    }
  }

  Future<void> _challengeFriend() async {
    final friends = FriendsService().friendIds;
    if (friends.isEmpty) {
      _toast(AppStrings.duelNoFriends, error: true);
      return;
    }
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF1C1640),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(18),
              child: Text(AppStrings.duelPickFriend,
                  style: GoogleFonts.nunito(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white)),
            ),
            for (final id in friends)
              ListTile(
                leading: const Icon(Icons.person_rounded, color: Colors.white70),
                title: Text(FriendsService().nameOf(id) ?? '${id.substring(0, 8).toUpperCase()}…',
                    style: GoogleFonts.nunito(fontWeight: FontWeight.w800, color: Colors.white)),
                trailing: const Icon(Icons.sports_kabaddi_rounded, color: Color(0xFFFF5D73)),
                onTap: () => Navigator.pop(ctx, id),
              ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
    if (picked == null) return;
    try {
      await DuelService().challengeFriend(picked, FriendsService().nameOf(picked) ?? '?');
      SoundService().playCorrect();
      _toast(AppStrings.duelSent);
    } catch (_) {
      _toast(AppStrings.duelError, error: true);
    }
  }

  void _openLeague() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _LeagueSheet(),
    );
  }

  Widget _leagueCard() {
    final s = DuelService();
    final league = DuelLeague.of(s.trophies);
    final next = DuelLeague.next(s.trophies);
    final color = Color(league.color);
    final progress = next == null
        ? 1.0
        : ((s.trophies - league.minTrophies) / (next.minTrophies - league.minTrophies)).clamp(0.0, 1.0);
    final tr = LanguageService().isTurkish;
    return GestureDetector(
      onTap: _openLeague,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.25),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: color.withValues(alpha: 0.5), width: 2),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Icon(Icons.shield_rounded, color: color, size: 44),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(AppStrings.leagueName(tr ? league.nameTr : league.nameEn),
                          style: GoogleFonts.nunito(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white)),
                      Text('${s.wins}${AppStrings.winShort} · ${s.losses}${AppStrings.lossShort} · ${s.draws}${AppStrings.drawShort}',
                          style: GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white60)),
                    ],
                  ),
                ),
                const Icon(Icons.emoji_events_rounded, color: Color(0xFFFFC233), size: 22),
                const SizedBox(width: 4),
                Text('${s.trophies}',
                    style: GoogleFonts.nunito(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white)),
                const Icon(Icons.chevron_right_rounded, color: Colors.white54),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 10,
                backgroundColor: Colors.white.withValues(alpha: 0.1),
                valueColor: AlwaysStoppedAnimation(color),
              ),
            ),
            if (next != null) ...[
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  AppStrings.toNextLeague(next.minTrophies - s.trophies, tr ? next.nameTr : next.nameEn),
                  style: GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white54),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _duelCard(Duel d) {
    final me = DuelService().me;
    final opp = d.opponentOf(me);
    final (mine, theirs) = d.roundWins(me);
    final result = d.resultFor(me);
    final String status;
    final Color statusColor;
    if (result != null) {
      status = AppStrings.duelResult(result);
      statusColor = switch (result) {
        DuelResult.win => const Color(0xFF3DDC84),
        DuelResult.loss => const Color(0xFFFF5D73),
        DuelResult.draw => Colors.white70,
      };
    } else if (d.isMyTurn(me)) {
      status = AppStrings.yourTurn;
      statusColor = const Color(0xFFFFC233);
    } else {
      status = AppStrings.waitingOpponent;
      statusColor = Colors.white54;
    }
    return GestureDetector(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => DuelDetailScreen(duelId: d.id))),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        height: 72,
        child: BannerBackground(
          bannerId: d.banners[opp],
          plainColor: Colors.black.withValues(alpha: 0.25),
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                AvatarView(avatar: d.avatars[opp] ?? '🙂', size: 46, ring: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(d.names[opp] ?? '?',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.white)),
                      Text(status, style: GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.w900, color: statusColor)),
                    ],
                  ),
                ),
                Row(
                  children: [
                    for (final g in d.games)
                      Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.asset(
                            games.firstWhere((m) => m.id == g).imagePath!,
                            width: 26,
                            height: 26,
                            cacheWidth: 80,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.4), borderRadius: BorderRadius.circular(12)),
                  child: Text('$mine - $theirs',
                      style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.white)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = DuelService();
    final searching = s.matchState == MatchState.searching;
    final active = s.duels.where((d) => !d.isDone).toList();
    final finished = s.duels.where((d) => d.isDone).take(10).toList();

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF5A0F3E), Color(0xFF2A1250), Color(0xFF0E1638)],
          ),
        ),
        child: SafeArea(
          child: ListView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              Row(
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
                  Text(AppStrings.duel,
                      style: GoogleFonts.nunito(fontSize: 26, fontWeight: FontWeight.w900, color: Colors.white)),
                  const SizedBox(width: 8),
                  const Icon(Icons.sports_kabaddi_rounded, color: Color(0xFFFF5D73), size: 28),
                ],
              ),
              const SizedBox(height: 16),
              _leagueCard(),
              const SizedBox(height: 18),
              if (searching)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.25), borderRadius: BorderRadius.circular(22)),
                  child: Row(
                    children: [
                      const SizedBox(
                          width: 28, height: 28, child: CircularProgressIndicator(color: Color(0xFFFF5D73), strokeWidth: 3)),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(AppStrings.searchingOpponent,
                            style: GoogleFonts.nunito(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white)),
                      ),
                      TextButton(
                        onPressed: s.cancelSearch,
                        child: Text(AppStrings.cancel,
                            style: GoogleFonts.nunito(fontWeight: FontWeight.w800, color: Colors.white60)),
                      ),
                    ],
                  ),
                )
              else
                ChunkyButton(
                  face: const Color(0xFFFF5D73),
                  lip: const Color(0xFFC2304A),
                  height: 72,
                  radius: 24,
                  onTap: _findMatch,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.bolt_rounded, color: Colors.white, size: 32),
                      const SizedBox(width: 6),
                      Text(AppStrings.findOpponent,
                          style: GoogleFonts.nunito(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            shadows: const [Shadow(color: Color(0x55000000), offset: Offset(0, 2))],
                          )),
                    ],
                  ),
                ),
              const SizedBox(height: 12),
              ChunkyButton(
                face: const Color(0xFF4F8BFF),
                lip: const Color(0xFF2E5BC4),
                height: 52,
                onTap: _challengeFriend,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.group_rounded, color: Colors.white),
                    const SizedBox(width: 8),
                    Text(AppStrings.challengeFriend,
                        style: GoogleFonts.nunito(fontSize: 17, fontWeight: FontWeight.w900, color: Colors.white)),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Text(AppStrings.duelHowTo,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white54)),
              const SizedBox(height: 20),
              if (active.isNotEmpty) ...[
                Text(AppStrings.activeDuels,
                    style: GoogleFonts.nunito(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white)),
                const SizedBox(height: 10),
                for (final d in active) _duelCard(d),
              ],
              if (finished.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(AppStrings.finishedDuels,
                    style: GoogleFonts.nunito(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white)),
                const SizedBox(height: 10),
                for (final d in finished) _duelCard(d),
              ],
              if (active.isEmpty && finished.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 20),
                  child: Column(
                    children: [
                      Icon(Icons.sports_kabaddi_rounded, size: 64, color: Colors.white.withValues(alpha: 0.18)),
                      const SizedBox(height: 8),
                      Text(AppStrings.noDuelsYet,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.nunito(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white54)),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LeagueSheet extends StatefulWidget {
  const _LeagueSheet();

  @override
  State<_LeagueSheet> createState() => _LeagueSheetState();
}

class _LeagueSheetState extends State<_LeagueSheet> {
  late final Future<List<Map<String, dynamic>>> _future = DuelService().topProfiles();

  @override
  Widget build(BuildContext context) {
    final me = DuelService().me;
    final tr = LanguageService().isTurkish;
    return DraggableScrollableSheet(
      initialChildSize: 0.8,
      maxChildSize: 0.94,
      expand: false,
      builder: (context, scroll) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1C1640),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _future,
          builder: (context, snap) {
            final rows = snap.data ?? [];
            return ListView(
              controller: scroll,
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
              children: [
                Text(AppStrings.trophyLeague,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.nunito(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white)),
                const SizedBox(height: 14),
                if (snap.connectionState != ConnectionState.done)
                  const Padding(
                    padding: EdgeInsets.all(30),
                    child: Center(child: CircularProgressIndicator(color: Color(0xFFFF5D73))),
                  )
                else if (rows.isEmpty)
                  Text(AppStrings.noPlayersYet,
                      textAlign: TextAlign.center, style: GoogleFonts.nunito(color: Colors.white60))
                else
                  for (var i = 0; i < rows.length; i++)
                    Builder(builder: (context) {
                      final r = rows[i];
                      final t = (r['trophies'] as num?)?.toInt() ?? 0;
                      final league = DuelLeague.of(t);
                      final isMe = r['userId'] == me;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        height: 60,
                        child: BannerBackground(
                          bannerId: r['banner'] as String?,
                          plainColor: isMe ? const Color(0xFF6C4BFF).withValues(alpha: 0.35) : Colors.black.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(18),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 28,
                                  child: Text('${i + 1}',
                                      style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.white70)),
                                ),
                                AvatarView(avatar: r['avatar'] as String? ?? '🙂', size: 40),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(isMe ? AppStrings.you : (r['name'] as String? ?? '?'),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.nunito(fontSize: 15, fontWeight: FontWeight.w900, color: Colors.white)),
                                ),
                                Icon(Icons.shield_rounded, color: Color(league.color), size: 18),
                                const SizedBox(width: 4),
                                Text(tr ? league.nameTr : league.nameEn,
                                    style: GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white70)),
                                const SizedBox(width: 10),
                                const Icon(Icons.emoji_events_rounded, color: Color(0xFFFFC233), size: 18),
                                const SizedBox(width: 3),
                                Text('$t', style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.white)),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
              ],
            );
          },
        ),
      ),
    );
  }
}
