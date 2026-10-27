import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/game_model.dart';
import '../utils/app_messenger.dart';
import 'language_service.dart';
import 'sound_service.dart';
import 'coin_service.dart';

class Achievement {
  final String id;
  final IconData icon;
  final String titleTr, titleEn, descTr, descEn;

  const Achievement(this.id, this.icon, this.titleTr, this.titleEn, this.descTr, this.descEn);

  String get title => LanguageService().isTurkish ? titleTr : titleEn;
  String get description => LanguageService().isTurkish ? descTr : descEn;
}

/// Rozetler. Skor eşikleri sıralama puanı (calculateLeaderboardScore) cinsindendir.
class AchievementService extends ChangeNotifier {
  static final AchievementService _instance = AchievementService._internal();
  factory AchievementService() => _instance;
  AchievementService._internal();

  static const List<Achievement> all = [
    Achievement('first_run', Icons.flag_rounded, 'İlk Koşu', 'First Run',
        'Bir Daily Run tamamla', 'Complete a Daily Run'),
    Achievement('runs_10', Icons.directions_run_rounded, 'Müdavim', 'Regular',
        '10 Daily Run tamamla', 'Complete 10 Daily Runs'),
    Achievement('runs_50', Icons.military_tech_rounded, 'Maratoncu', 'Marathoner',
        '50 Daily Run tamamla', 'Complete 50 Daily Runs'),
    Achievement('early_bird', Icons.wb_sunny_rounded, 'Erkenci', 'Early Bird',
        'Sabah turunu tamamla', 'Finish a morning run'),
    Achievement('night_owl', Icons.nights_stay_rounded, 'Gece Kuşu', 'Night Owl',
        'Akşam turunu tamamla', 'Finish an evening run'),
    Achievement('no_zero', Icons.verified_rounded, 'Eksiksiz', 'Clean Sweep',
        'Hiçbir oyundan 0 almadan Daily Run bitir', 'Finish a run without a single zero'),
    Achievement('streak_3', Icons.local_fire_department_rounded, 'Kıvılcım', 'Spark',
        '3 günlük seri', '3-day streak'),
    Achievement('streak_7', Icons.whatshot_rounded, 'Alev', 'Flame',
        '7 günlük seri', '7-day streak'),
    Achievement('streak_30', Icons.auto_awesome_rounded, 'Yanardağ', 'Volcano',
        '30 günlük seri', '30-day streak'),
    Achievement('explorer', Icons.explore_rounded, 'Kaşif', 'Explorer',
        'Her oyunu en az bir kez oyna', 'Play every game at least once'),
    Achievement('wordle_sharp', Icons.abc_rounded, 'Keskin Zekâ', 'Sharp Mind',
        'Wordle\'ı en fazla 2 denemede bil', 'Solve Wordle in 2 tries or fewer'),
    Achievement('reactle_fast', Icons.speed_rounded, 'Şimşek', 'Lightning',
        'Reactle\'da 90+ puan al', 'Score 90+ in Reactle'),
    Achievement('anglele_90', Icons.architecture_rounded, 'Pergel', 'Compass',
        'Anglele\'da 90+ puan al', 'Score 90+ in Anglele'),
    Achievement('quickle_80', Icons.bolt_rounded, 'Hesap Makinesi', 'Calculator',
        'Quickle\'da 80+ puan al', 'Score 80+ in Quickle'),
    Achievement('slicele_90', Icons.content_cut_rounded, 'Cerrah', 'Surgeon',
        'Slicele\'da 90+ puan al', 'Score 90+ in Slicele'),
    Achievement('stackle_75', Icons.layers_rounded, 'Mimar', 'Architect',
        'Stackle\'da 75+ puan al', 'Score 75+ in Stackle'),
    Achievement('mirrorle_100', Icons.flip_rounded, 'Ayna Ayna', 'Mirror Mirror',
        'Mirrorle\'ı kusursuz bitir', 'Finish Mirrorle flawlessly'),
    Achievement('friend', Icons.group_add_rounded, 'Sosyal', 'Social',
        'İlk arkadaşını ekle', 'Add your first friend'),
    // Düello
    Achievement('duel_first_win', Icons.sports_kabaddi_rounded, 'İlk Zafer', 'First Victory',
        'İlk düellonu kazan', 'Win your first duel'),
    Achievement('duel_wins_10', Icons.shield_rounded, 'Gladyatör', 'Gladiator',
        '10 düello kazan', 'Win 10 duels'),
    Achievement('duel_streak_3', Icons.trending_up_rounded, 'Yenilmez', 'Unstoppable',
        '3 düelloyu üst üste kazan', 'Win 3 duels in a row'),
    Achievement('duel_sweep', Icons.cleaning_services_rounded, 'Silindir', 'Steamroller',
        'Bir düelloda 3 turu da kazan', 'Win all 3 rounds of a duel'),
    Achievement('duel_gold', Icons.emoji_events_rounded, 'Altın Lig', 'Gold League',
        'Düelloda Altın lige yüksel', 'Reach the Gold duel league'),
    Achievement('duel_friend', Icons.handshake_rounded, 'Dostluk Maçı', 'Friendly Match',
        'Bir arkadaşınla düello bitir', 'Finish a duel with a friend'),
  ];

  static const Map<String, (String, double)> _scoreGoals = {
    'wordle_sharp': ('wordle', 83),
    'reactle_fast': ('reactle', 90),
    'anglele_90': ('anglele', 90),
    'quickle_80': ('quickle', 80),
    'slicele_90': ('slicele', 90),
    'stackle_75': ('stackle', 75),
    'mirrorle_100': ('mirrorle', 99.9),
  };

  static const String _prefix = 'ach_';
  static const String _runsKey = 'ach_runs_completed';
  static const String _duelStreakKey = 'ach_duel_win_streak';
  SharedPreferences? _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  bool isUnlocked(String id) => _prefs?.containsKey('$_prefix$id') ?? false;

  int get unlockedCount => all.where((a) => isUnlocked(a.id)).length;

  int get runsCompleted => _prefs?.getInt(_runsKey) ?? 0;

  // ─── Olaylar ───────────────────────────────────────────────────
  void onGameScore(String gameId, double score, Set<String> playedGames) {
    _scoreGoals.forEach((id, goal) {
      if (goal.$1 == gameId && score >= goal.$2) _unlock(id);
    });
    if (games.every((g) => playedGames.contains(g.id))) _unlock('explorer');
  }

  Future<void> onDailyRunCompleted(int slot, Map<String, double> scores) async {
    final runs = runsCompleted + 1;
    await _prefs?.setInt(_runsKey, runs);
    _unlock('first_run');
    if (runs >= 10) _unlock('runs_10');
    if (runs >= 50) _unlock('runs_50');
    _unlock(slot == 1 ? 'early_bird' : 'night_owl');
    if (scores.isNotEmpty && scores.values.every((s) => s > 0)) _unlock('no_zero');
  }

  void onStreak(int streak) {
    if (streak >= 3) _unlock('streak_3');
    if (streak >= 7) _unlock('streak_7');
    if (streak >= 30) _unlock('streak_30');
  }

  void onFriendAdded() => _unlock('friend');

  /// Biten her düello için bir kez çağrılır
  void onDuelFinished({
    required bool won,
    required bool sweep,
    required int totalWins,
    required int trophies,
    required bool vsFriend,
  }) {
    final streak = won ? (_prefs?.getInt(_duelStreakKey) ?? 0) + 1 : 0;
    _prefs?.setInt(_duelStreakKey, streak);
    if (won) _unlock('duel_first_win');
    if (totalWins >= 10) _unlock('duel_wins_10');
    if (streak >= 3) _unlock('duel_streak_3');
    if (won && sweep) _unlock('duel_sweep');
    if (trophies >= 400) _unlock('duel_gold');
    if (vsFriend) _unlock('duel_friend');
  }

  void _unlock(String id) {
    if (_prefs == null || isUnlocked(id)) return;
    _prefs!.setString('$_prefix$id', DateTime.now().toIso8601String());
    notifyListeners();
    CoinService().earn(CoinService.achievementReward, 'achievement');
    final a = all.firstWhere((a) => a.id == id);
    SoundService().playReward();
    rootMessengerKey.currentState?.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF2A2340),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        duration: const Duration(seconds: 3),
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(color: Color(0xFFFFD54F), shape: BoxShape.circle),
              child: Icon(a.icon, color: const Color(0xFF2A2340), size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    LanguageService().isTurkish ? 'Rozet kazandın: ${a.title}' : 'Badge unlocked: ${a.title}',
                    style: GoogleFonts.nunito(fontWeight: FontWeight.w800, color: Colors.white),
                  ),
                  Text('${a.description} · +${CoinService.achievementReward} coin',
                      style: GoogleFonts.nunito(fontSize: 12, color: Colors.white70)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
