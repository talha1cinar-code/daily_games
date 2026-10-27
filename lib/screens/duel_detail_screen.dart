import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../games/game_registry.dart';
import '../models/duel.dart';
import '../models/game_model.dart';
import '../services/app_strings.dart';
import '../services/daily_challenge_service.dart';
import '../services/duel_service.dart';
import '../services/leaderboard_service.dart';
import '../services/score_scale.dart';
import '../services/sound_service.dart';
import '../services/streak_service.dart';
import '../widgets/avatar_view.dart';
import '../widgets/banner_background.dart';
import '../widgets/chunky_button.dart';

/// Tek bir düello: iki oyuncu, 3 tur. Turlar sırayla oynanır; rakibin tur
/// skoru, o tur oynanana kadar gizlidir.
class DuelDetailScreen extends StatefulWidget {
  final String duelId;
  const DuelDetailScreen({super.key, required this.duelId});

  @override
  State<DuelDetailScreen> createState() => _DuelDetailScreenState();
}

class _DuelDetailScreenState extends State<DuelDetailScreen> {
  bool _playing = false;

  @override
  void initState() {
    super.initState();
    DuelService().addListener(_onChanged);
  }

  @override
  void dispose() {
    DuelService().removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  Duel? get _duel {
    for (final d in DuelService().duels) {
      if (d.id == widget.duelId) return d;
    }
    return null;
  }

  Future<void> _play(Duel d, int round) async {
    if (_playing) return;
    final gameId = d.games[round];
    _playing = true;
    var submitted = false;
    // Oyun, düelloya özel seed ile açılır; Daily Run sıralamasına yazılmaz
    DailyChallengeService.seedOverride = d.roundSeed(round);
    SoundService().enterMiniGame();
    final screen = buildGameScreen(
      gameId,
      isDailyMode: true,
      onGameComplete: (score, [durationMs = 0]) {
        if (submitted) return;
        submitted = true;
        DuelService().submitRound(d, round, ScoreScale.normalize(gameId, score)).catchError((Object e) {
          debugPrint('Duel submit error: $e');
        });
        StreakService().recordActivity();
      },
    );
    if (screen != null) {
      await Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
    }
    DailyChallengeService.seedOverride = null;
    SoundService().exitMiniGame();
    _playing = false;
  }

  GameModel _game(String id) => games.firstWhere((g) => g.id == id);

  Widget _side(Duel d, String id, {required bool left}) {
    final isMe = id == DuelService().me;
    return Expanded(
      child: SizedBox(
        height: 132,
        child: BannerBackground(
          bannerId: d.banners[id],
          plainColor: Colors.black.withValues(alpha: 0.3),
          borderRadius: BorderRadius.horizontal(
            left: left ? const Radius.circular(24) : Radius.zero,
            right: left ? Radius.zero : const Radius.circular(24),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AvatarView(avatar: d.avatars[id] ?? (isMe ? LeaderboardService().avatar : '🙂'), size: 62, ring: Colors.white),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  isMe ? AppStrings.you : (d.names[id] ?? '?'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.nunito(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    shadows: const [Shadow(color: Color(0x88000000), blurRadius: 6)],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _scoreBox(double? v, {required bool hidden, required bool winner}) {
    return Container(
      width: 64,
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: winner ? const Color(0xFF3DDC84).withValues(alpha: 0.25) : Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: winner ? Border.all(color: const Color(0xFF3DDC84), width: 2) : null,
      ),
      alignment: Alignment.center,
      child: Text(
        hidden ? '?' : (v == null ? '—' : v.toStringAsFixed(0)),
        style: GoogleFonts.nunito(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white),
      ),
    );
  }

  Widget _roundRow(Duel d, int r) {
    final me = DuelService().me;
    final opp = d.opponentOf(me);
    final mine = d.scores[me]?[r];
    final oppPlayed = d.scores[opp]?.containsKey(r) ?? false;
    final theirs = d.visibleOpponentScore(me, r);
    final nextForMe = !d.isDone && mine == null && d.playedBy(me) == r;
    final g = _game(d.games[r]);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: nextForMe ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(20),
        border: nextForMe ? Border.all(color: const Color(0xFFFFC233), width: 2) : null,
      ),
      child: Row(
        children: [
          _scoreBox(mine, hidden: false, winner: mine != null && theirs != null && mine > theirs),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.asset(g.imagePath!, width: 48, height: 48, cacheWidth: 150),
                ),
                const SizedBox(height: 4),
                Text('${AppStrings.round} ${r + 1} · ${g.name}',
                    style: GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white70)),
                if (nextForMe) ...[
                  const SizedBox(height: 8),
                  ChunkyButton(
                    face: const Color(0xFF3DDC84),
                    lip: const Color(0xFF1E9E55),
                    height: 40,
                    radius: 13,
                    onTap: () => _play(d, r),
                    child: Text(AppStrings.playButton,
                        style: GoogleFonts.nunito(fontSize: 17, fontWeight: FontWeight.w900, color: Colors.white)),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          _scoreBox(theirs,
              hidden: oppPlayed && theirs == null, winner: mine != null && theirs != null && theirs > mine),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final d = _duel;
    final me = DuelService().me;
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
          child: d == null
              ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF5D73)))
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.28), borderRadius: BorderRadius.circular(22)),
                          child: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        Row(children: [_side(d, me, left: true), const SizedBox(width: 4), _side(d, d.opponentOf(me), left: false)]),
                        Container(
                          width: 64,
                          height: 64,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF5D73),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                          ),
                          child: Builder(builder: (context) {
                            final (a, b) = d.roundWins(me);
                            return Text('$a-$b',
                                style: GoogleFonts.nunito(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white));
                          }),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    if (d.isDone) _resultBanner(d.resultFor(me)!) else _statusLine(d),
                    const SizedBox(height: 14),
                    for (var r = 0; r < Duel.rounds; r++) _roundRow(d, r),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _statusLine(Duel d) {
    final me = DuelService().me;
    final left = Duel.timeout - DateTime.now().difference(d.updatedAt);
    final text = d.isMyTurn(me) ? AppStrings.yourTurnLong : AppStrings.waitingOpponentLong;
    return Column(
      children: [
        Text(text,
            textAlign: TextAlign.center,
            style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.white)),
        Text(AppStrings.duelExpiresIn(left.inHours.clamp(0, Duel.timeout.inHours)),
            style: GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white54)),
      ],
    );
  }

  Widget _resultBanner(DuelResult r) {
    final (trophies, coins) = DuelRewards.of(r);
    final color = switch (r) {
      DuelResult.win => const Color(0xFF3DDC84),
      DuelResult.loss => const Color(0xFFFF5D73),
      DuelResult.draw => const Color(0xFFB9A8FF),
    };
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(20)),
      child: Column(
        children: [
          Text(AppStrings.duelResultTitle(r),
              style: GoogleFonts.nunito(fontSize: 26, fontWeight: FontWeight.w900, color: color)),
          Text('${trophies >= 0 ? '+' : ''}$trophies 🏆   +$coins 🪙',
              style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white)),
        ],
      ),
    );
  }
}
