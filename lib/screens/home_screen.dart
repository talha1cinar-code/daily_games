import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../services/settings_service.dart';
import '../services/sound_service.dart';
import '../services/language_service.dart';
import '../services/app_strings.dart';
import 'games_screen.dart';
import 'profile_screen.dart';
import 'daily_run_screen.dart';
import '../services/daily_run_service.dart';
import '../services/leaderboard_service.dart';
import '../services/streak_service.dart';
import '../widgets/streak_style.dart';
import '../services/ad_service.dart';
import 'leaderboard_screen.dart';
import '../utils/network_utils.dart';
import '../widgets/logo_background.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/game_model.dart';
import '../widgets/chunky_button.dart';
import '../widgets/avatar_view.dart';
import '../widgets/coin_badge.dart';
import '../widgets/daily_reward_dialog.dart';
import '../services/coin_service.dart';
import '../services/daily_reward_service.dart';
import 'store_screen.dart';
import 'duel_screen.dart';
import '../services/duel_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  late AnimationController _card1Controller;
  late AnimationController _card2Controller;
  late AnimationController _card3Controller;
  late Animation<double> _card1Animation;
  late Animation<double> _card2Animation;
  late Animation<double> _card3Animation;

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(duration: const Duration(milliseconds: 600), vsync: this);
    _fadeAnimation = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);

    _card1Controller = AnimationController(duration: const Duration(milliseconds: 500), vsync: this);
    _card2Controller = AnimationController(duration: const Duration(milliseconds: 500), vsync: this);
    _card3Controller = AnimationController(duration: const Duration(milliseconds: 500), vsync: this);

    _card1Animation = CurvedAnimation(parent: _card1Controller, curve: Curves.easeOutBack);
    _card2Animation = CurvedAnimation(parent: _card2Controller, curve: Curves.easeOutBack);
    _card3Animation = CurvedAnimation(parent: _card3Controller, curve: Curves.easeOutBack);

    StreakService().addListener(_onStreakChanged);
    _startAnimations();
  }

  void _onStreakChanged() {
    if (mounted && StreakService().shouldShowRestorePrompt) {
      StreakService().markRestorePromptShown();
      _showRestoreStreakDialog();
    }
  }

  Future<void> _startAnimations() async {
    _fadeController.forward();
    await Future.delayed(const Duration(milliseconds: 200));
    if (mounted) _card1Controller.forward();
    await Future.delayed(const Duration(milliseconds: 120));
    if (mounted) _card2Controller.forward();
    await Future.delayed(const Duration(milliseconds: 120));
    if (mounted) _card3Controller.forward();

    if (mounted && StreakService().shouldShowRestorePrompt) {
      StreakService().markRestorePromptShown();
      _showRestoreStreakDialog();
    } else if (mounted && DailyRewardService().canClaim) {
      await Future.delayed(const Duration(milliseconds: 300));
      if (mounted) DailyRewardDialog.show(context);
    }
  }

  void _openDuels() {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const DuelScreen()));
  }

  void _openStore() {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const StoreScreen()));
  }

  @override
  void dispose() {
    StreakService().removeListener(_onStreakChanged);
    _fadeController.dispose();
    _card1Controller.dispose();
    _card2Controller.dispose();
    _card3Controller.dispose();
    super.dispose();
  }

  void _navigateToGames() {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => const GamesScreen(),
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
    );
  }

  void _navigateToProfile() {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => const ProfileScreen(),
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
    );
  }

  void _showRestoreStreakDialog() {
    final lostStreak = StreakService().lostStreak;
    showDialog(
      context: context,
      barrierDismissible: false,
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
            border: Border.all(color: const Color(0xFFFF6E40).withValues(alpha: 0.6), width: 2),
            boxShadow: [
              BoxShadow(color: const Color(0xFFFF6E40).withValues(alpha: 0.3), blurRadius: 20, spreadRadius: 4),
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
                  style: GoogleFonts.nunito(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white),
                ),
                const SizedBox(height: 12),
                Text(
                  AppStrings.restoreStreakBody(lostStreak),
                  style: GoogleFonts.nunito(fontSize: 14, color: Colors.white70, fontWeight: FontWeight.w600),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  AppStrings.limitedTimeOffer,
                  style: GoogleFonts.nunito(fontSize: 12, color: Colors.orangeAccent, fontWeight: FontWeight.w700),
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
                      style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w800),
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
                    style: GoogleFonts.nunito(fontSize: 14, color: Colors.white38, fontWeight: FontWeight.w600),
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

  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
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
                        AppStrings.settings,
                        style: GoogleFonts.nunito(fontSize: 24, fontWeight: FontWeight.w700, color: Colors.white),
                      ),
                      const SizedBox(height: 24),
                      // Dil seçici
                      _buildLanguageRow(
                        onChanged: () {
                          LanguageService().toggleLanguage();
                          setDialogState(() {});
                          setState(() {});
                        },
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildIconToggle(
                            icon: Icons.music_note_rounded,
                            iconOff: Icons.music_off_rounded,
                            value: SettingsService().isMusicEnabled,
                            onTap: () {
                              SettingsService().toggleMusic();
                              SoundService().updateBgmState();
                              setDialogState(() {});
                            },
                          ),
                          _buildIconToggle(
                            icon: Icons.volume_up_rounded,
                            iconOff: Icons.volume_off_rounded,
                            value: SettingsService().isSfxEnabled,
                            onTap: () {
                              SettingsService().toggleSfx();
                              setDialogState(() {});
                            },
                          ),
                          _buildIconToggle(
                            icon: Icons.vibration_rounded,
                            iconOff: Icons.smartphone_rounded,
                            value: SettingsService().isVibrationEnabled,
                            onTap: () {
                              SettingsService().toggleVibration();
                              setDialogState(() {});
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),
                      _buildMoreSettingRow(
                        icon: Icons.tune_rounded,
                        title: AppStrings.moreSettings,
                        onTap: () {
                          Navigator.of(context).pop(); // Close main settings
                          _showMoreSettingsDialog(); // Open more settings
                        },
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 50),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: Text(
                          AppStrings.close,
                          style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showMoreSettingsDialog() {
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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  AppStrings.moreSettings,
                  style: GoogleFonts.nunito(fontSize: 24, fontWeight: FontWeight.w700, color: Colors.white),
                ),
                const SizedBox(height: 24),
                _buildMoreSettingRow(
                  icon: Icons.privacy_tip_rounded,
                  title: AppStrings.privacyPolicy,
                  onTap: () {
                    _launchUrlHelper('https://daily-games-6b0e3.web.app/privacy.html');
                  },
                ),
                const SizedBox(height: 8),
                _buildMoreSettingRow(
                  icon: Icons.description_rounded,
                  title: AppStrings.termsOfService,
                  onTap: () {
                    _launchUrlHelper('https://daily-games-6b0e3.web.app/terms.html');
                  },
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Text(AppStrings.close, style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _launchUrlHelper(String urlStr) async {
    final uri = Uri.parse(urlStr);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('Link açılamadı: $e');
    }
  }

  Widget _buildIconToggle({
    required IconData icon,
    IconData? iconOff,
    required bool value,
    required VoidCallback onTap,
  }) {
    final glowColor = value ? AppColors.secondary : Colors.grey;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: glowColor.withValues(alpha: 0.08),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(color: glowColor.withValues(alpha: value ? 0.6 : 0.0), blurRadius: 16, spreadRadius: 1),
          ],
          border: Border.all(color: glowColor, width: value ? 2.5 : 1.5),
        ),
        child: Icon(
          value ? icon : (iconOff ?? icon),
          color: value ? Colors.white : Colors.white.withValues(alpha: 0.5),
          size: 32,
        ),
      ),
    );
  }

  Widget _buildMoreSettingRow({required IconData icon, required String title, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(16)),
        child: Row(
          children: [
            Icon(icon, color: Colors.white.withValues(alpha: 0.8), size: 24),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.nunito(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: Colors.white.withValues(alpha: 0.5), size: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageRow({required VoidCallback onChanged}) {
    return GestureDetector(
      onTap: onChanged,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(16)),
        child: Row(
          children: [
            Icon(Icons.language_rounded, color: Colors.white.withValues(alpha: 0.8), size: 24),
            const SizedBox(width: 16),
            Expanded(
              child: FittedBox(
                alignment: Alignment.centerLeft,
                fit: BoxFit.scaleDown,
                child: Text(
                  AppStrings.language,
                  style: GoogleFonts.nunito(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w500),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.secondary.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.secondary.withValues(alpha: 0.5)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(LanguageService().isTurkish ? '🇹🇷' : '🇬🇧', style: const TextStyle(fontSize: 18)),
                  const SizedBox(width: 6),
                  Text(
                    AppStrings.languageValue,
                    style: GoogleFonts.nunito(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  int _refreshToken = 0;

  void _snack(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          text,
          style: GoogleFonts.nunito(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _openDailyRun() async {
    final hasInternet = await NetworkUtils.checkInternet();
    if (!mounted) return;
    if (!hasInternet) return _snack(AppStrings.dailyRunInternetRequired);
    await Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => const DailyRunScreen(),
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
    );
    // Dönüşte ilerleme yenilensin
    if (mounted) setState(() => _refreshToken++);
  }

  Future<void> _openLeaderboard() async {
    final hasInternet = await NetworkUtils.checkInternet();
    if (!mounted) return;
    if (!hasInternet) return _snack(AppStrings.leaderboardInternetRequired);
    final slot = DailyRunService.currentRunSlot();
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => LeaderboardScreen(
          gameId: 'daily_run_${slot == 1 ? "morning" : "evening"}',
          gameName: AppStrings.dailyRunSlotName(slot),
        ),
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
    );
  }

  Widget _staggered(Animation<double> animation, Widget child) {
    return FadeTransition(
      opacity: animation,
      child: ScaleTransition(scale: Tween<double>(begin: 0.85, end: 1).animate(animation), child: child),
    );
  }

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
              child: LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          FadeTransition(
                            opacity: _fadeAnimation,
                            child: _Hud(onProfile: _navigateToProfile, onSettings: _showSettingsDialog, onStore: _openStore),
                          ),
                          // Ana içerik HUD ile ekran altı arasında dikeyde ortalanır
                          Column(
                            children: [
                              const SizedBox(height: 18),
                              FadeTransition(
                                opacity: _fadeAnimation,
                                child: Image.asset('assets/images/logo_wordmark.png', height: 150, fit: BoxFit.contain),
                              ),
                              const SizedBox(height: 22),
                              _staggered(
                                _card1Animation,
                                _TodayStrip(key: ValueKey(_refreshToken), onTap: _openDailyRun),
                              ),
                              const SizedBox(height: 22),
                              _staggered(_card2Animation, _PlayButton(onTap: _openDailyRun)),
                              const SizedBox(height: 18),
                              _staggered(
                                _card3Animation,
                                Row(
                                  children: [
                                    Expanded(
                                      child: ChunkyButton(
                                        face: const Color(0xFF4F8BFF),
                                        lip: const Color(0xFF2E5BC4),
                                        height: 78,
                                        onTap: _navigateToGames,
                                        child: _ButtonLabel(icon: Icons.grid_view_rounded, label: AppStrings.games),
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: ChunkyButton(
                                        face: const Color(0xFFFFB627),
                                        lip: const Color(0xFFC77F00),
                                        height: 78,
                                        onTap: _openLeaderboard,
                                        child: _ButtonLabel(
                                          icon: Icons.emoji_events_rounded,
                                          label: AppStrings.rankingShort,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 14),
                              _staggered(_card3Animation, _DuelButton(onTap: _openDuels)),
                            ],
                          ),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ButtonLabel extends StatelessWidget {
  final IconData icon;
  final String label;
  const _ButtonLabel({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white, size: 26, shadows: _textShadow),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            label.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.nunito(
              fontSize: 19,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: 0.5,
              shadows: _textShadow,
            ),
          ),
        ),
      ],
    );
  }
}

const List<Shadow> _textShadow = [Shadow(color: Color(0x55000000), offset: Offset(0, 2), blurRadius: 0)];

// ─── Üst bar: avatar + seri + ayarlar ───────────────────────────
class _Hud extends StatefulWidget {
  final VoidCallback onProfile;
  final VoidCallback onSettings;
  final VoidCallback onStore;
  const _Hud({required this.onProfile, required this.onSettings, required this.onStore});

  @override
  State<_Hud> createState() => _HudState();
}

class _HudState extends State<_Hud> {
  @override
  void initState() {
    super.initState();
    StreakService().addListener(_changed);
    CoinService().addListener(_changed);
    DailyRewardService().addListener(_changed);
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    StreakService().removeListener(_changed);
    CoinService().removeListener(_changed);
    DailyRewardService().removeListener(_changed);
    super.dispose();
  }

  Widget _pill({required Widget child, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: () {
        SoundService().playKeyTap();
        onTap();
      },
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.28),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final streak = StreakService().currentStreak;
    final frozen = StreakService().isFrozenToday;
    return Row(
      children: [
        _pill(
          onTap: widget.onProfile,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AvatarView(avatar: LeaderboardService().avatar, size: 34),
              const SizedBox(width: 10),
              StreakFlame(streak: streak, frozen: frozen, size: 24, animate: false),
              const SizedBox(width: 2),
              Text(
                '$streak',
                style: GoogleFonts.nunito(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white),
              ),
              const SizedBox(width: 10),
            ],
          ),
        ),
        const Spacer(),
        CoinBadge(amount: CoinService().balance, showPlus: true, onTap: widget.onStore),
        const SizedBox(width: 8),
        if (DailyRewardService().canClaim) ...[
          _pill(
            onTap: () => DailyRewardDialog.show(context),
            child: const SizedBox(
              width: 32,
              child: Badge(
                smallSize: 9,
                backgroundColor: Color(0xFFFF4D6D),
                child: Icon(Icons.card_giftcard_rounded, color: Color(0xFFFFC233), size: 24),
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
        _pill(
          onTap: widget.onSettings,
          child: const SizedBox(width: 32, child: Icon(Icons.settings_rounded, color: Colors.white, size: 24)),
        ),
      ],
    );
  }
}

// ─── Bugünün oyunları şeridi ────────────────────────────────────
class _TodayStrip extends StatelessWidget {
  final VoidCallback onTap;
  const _TodayStrip({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final progress = DailyRunService().getProgress();
    final order = progress.gameOrder;
    final next = DailyRunService().getNextGameId();

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
        decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.22), borderRadius: BorderRadius.circular(22)),
        child: Column(
          children: [
            Text(
              AppStrings.todaysGames.toUpperCase(),
              style: GoogleFonts.nunito(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
                color: Colors.white.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 10),
            LayoutBuilder(
              builder: (context, c) {
                const gap = 6.0;
                final size = ((c.maxWidth - gap * (order.length - 1)) / order.length).clamp(30.0, 52.0);
                return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < order.length; i++) ...[
                      if (i > 0) const SizedBox(width: gap),
                      _gameIcon(order[i], size, progress.scores.containsKey(order[i]), order[i] == next),
                    ],
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _gameIcon(String id, double size, bool done, bool isNext) {
    final path = games.firstWhere((g) => g.id == id).imagePath;
    return AnimatedScale(
      scale: isNext ? 1.1 : 1,
      duration: const Duration(milliseconds: 200),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(size * 0.26),
          border: isNext ? Border.all(color: Colors.white, width: 2.5) : null,
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 6, offset: const Offset(0, 3)),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(size * 0.26 - (isNext ? 2 : 0)),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (path != null) Image.asset(path, fit: BoxFit.cover, cacheWidth: 160),
              if (done)
                Container(
                  color: Colors.black.withValues(alpha: 0.45),
                  child: Icon(Icons.check_rounded, color: const Color(0xFF5CF08F), size: size * 0.6),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Büyük OYNA butonu ──────────────────────────────────────────
class _PlayButton extends StatefulWidget {
  final VoidCallback onTap;
  const _PlayButton({required this.onTap});

  @override
  State<_PlayButton> createState() => _PlayButtonState();
}

class _PlayButtonState extends State<_PlayButton> with SingleTickerProviderStateMixin {
  Timer? _timer;
  late final AnimationController _idle = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))
    ..repeat(reverse: true);

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _idle.dispose();
    super.dispose();
  }

  String _countdown() {
    final now = DailyRunService.turkeyNow;
    final next = now.hour < 17
        ? DateTime.utc(now.year, now.month, now.day, 17)
        : DateTime.utc(now.year, now.month, now.day + 1, 0);
    final left = next.difference(now);
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(left.inHours)}:${two(left.inMinutes % 60)}:${two(left.inSeconds % 60)}';
  }

  @override
  Widget build(BuildContext context) {
    final progress = DailyRunService().getProgress();
    final done = progress.completedCount;
    final total = progress.gameOrder.length;
    final morning = DailyRunService.currentRunSlot() == 1;

    final String label;
    final Color face, lip;
    if (progress.isCompleted) {
      label = AppStrings.resultsButton;
      face = const Color(0xFF8B5CFF);
      lip = const Color(0xFF5B2FD0);
    } else if (done > 0) {
      label = '${AppStrings.continueButton}  $done/$total';
      face = const Color(0xFF3DDC84);
      lip = const Color(0xFF1E9E55);
    } else {
      label = AppStrings.playButton;
      face = const Color(0xFF3DDC84);
      lip = const Color(0xFF1E9E55);
    }

    return Column(
      children: [
        AnimatedBuilder(
          animation: _idle,
          builder: (context, child) => Transform.scale(
            scale: progress.isCompleted ? 1 : 1 + Curves.easeInOut.transform(_idle.value) * 0.025,
            child: child,
          ),
          child: ChunkyButton(
            face: face,
            lip: lip,
            height: 96,
            radius: 28,
            onTap: widget.onTap,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  progress.isCompleted ? Icons.emoji_events_rounded : Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 44,
                  shadows: _textShadow,
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: GoogleFonts.nunito(
                    fontSize: 34,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 1,
                    shadows: const [Shadow(color: Color(0x66000000), offset: Offset(0, 3), blurRadius: 0)],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              morning ? Icons.wb_sunny_rounded : Icons.nightlight_round,
              color: morning ? const Color(0xFFFFC857) : const Color(0xFFB9A8FF),
              size: 18,
            ),
            const SizedBox(width: 6),
            Text(
              progress.isCompleted
                  ? AppStrings.nextRunIn(_countdown())
                  : '${morning ? AppStrings.morningRound : AppStrings.eveningRound} · ${_countdown()}',
              style: GoogleFonts.nunito(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: Colors.white.withValues(alpha: 0.75),
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _DuelButton extends StatefulWidget {
  final VoidCallback onTap;
  const _DuelButton({required this.onTap});

  @override
  State<_DuelButton> createState() => _DuelButtonState();
}

class _DuelButtonState extends State<_DuelButton> {
  @override
  void initState() {
    super.initState();
    DuelService().addListener(_changed);
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    DuelService().removeListener(_changed);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pending = DuelService().myTurnCount;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        ChunkyButton(
          face: const Color(0xFFFF5D73),
          lip: const Color(0xFFC2304A),
          height: 70,
          onTap: widget.onTap,
          child: _ButtonLabel(icon: Icons.sports_kabaddi_rounded, label: AppStrings.duel),
        ),
        if (pending > 0)
          Positioned(
            right: 10,
            top: -6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFFFC233),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: Text(
                '$pending',
                style: GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.w900, color: const Color(0xFF5A3A00)),
              ),
            ),
          ),
      ],
    );
  }
}
