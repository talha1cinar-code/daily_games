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
import '../services/ad_service.dart';
import 'leaderboard_screen.dart';
import '../utils/network_utils.dart';
import '../widgets/logo_background.dart';

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

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );

    _card1Controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _card2Controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _card3Controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _card1Animation = CurvedAnimation(parent: _card1Controller, curve: Curves.easeOutBack);
    _card2Animation = CurvedAnimation(parent: _card2Controller, curve: Curves.easeOutBack);
    _card3Animation = CurvedAnimation(parent: _card3Controller, curve: Curves.easeOutBack);

    _startAnimations();
  }

  Future<void> _startAnimations() async {
    _fadeController.forward();
    await Future.delayed(const Duration(milliseconds: 200));
    if (mounted) _card1Controller.forward();
    await Future.delayed(const Duration(milliseconds: 120));
    if (mounted) _card2Controller.forward();
    await Future.delayed(const Duration(milliseconds: 120));
    if (mounted) _card3Controller.forward();

    if (mounted && StreakService().canRestoreStreak) {
      _showRestoreStreakDialog();
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _card1Controller.dispose();
    _card2Controller.dispose();
    _card3Controller.dispose();
    super.dispose();
  }

  void _navigateToGames() {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const GamesScreen(),
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
    );
  }

  void _navigateToProfile() {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const ProfileScreen(),
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
          SoundService().playWin();
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
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.1),
                    width: 2,
                  ),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        AppStrings.settings,
                        style: GoogleFonts.nunito(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
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
                      _GameButton(
                        title: AppStrings.moreSettings,
                        glowColor: AppColors.secondary,
                        height: 56,
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
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Text(
                          AppStrings.close,
                          style: GoogleFonts.nunito(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
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
                  style: GoogleFonts.nunito(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 24),
                _buildMoreSettingRow(
                  icon: Icons.privacy_tip_rounded,
                  title: AppStrings.privacyPolicy,
                  onTap: () {},
                ),
                const SizedBox(height: 8),
                _buildMoreSettingRow(
                  icon: Icons.description_rounded,
                  title: AppStrings.termsOfService,
                  onTap: () {},
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
                  child: Text(
                    AppStrings.close,
                    style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
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
            BoxShadow(
              color: glowColor.withValues(alpha: value ? 0.6 : 0.0),
              blurRadius: 16,
              spreadRadius: 1,
            ),
          ],
          border: Border.all(
            color: glowColor,
            width: value ? 2.5 : 1.5,
          ),
        ),
        child: Icon(
          value ? icon : (iconOff ?? icon),
          color: value ? Colors.white : Colors.white.withValues(alpha: 0.5),
          size: 32,
        ),
      ),
    );
  }

  Widget _buildMoreSettingRow({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white.withValues(alpha: 0.8), size: 24),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.nunito(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
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
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
        ),
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
                  style: GoogleFonts.nunito(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.secondary.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.secondary.withValues(alpha: 0.5),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    LanguageService().isTurkish ? '🇹🇷' : '🇬🇧',
                    style: const TextStyle(fontSize: 18),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    AppStrings.languageValue,
                    style: GoogleFonts.nunito(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
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
        child: Stack(
          children: [
            const LogoBackground(),
            SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: IntrinsicHeight(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 16),
                          // Üst bar: Ayarlar
                          FadeTransition(
                            opacity: _fadeAnimation,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                GestureDetector(
                                  onTap: _showSettingsDialog,
                                  child: Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: Colors.white.withValues(alpha: 0.15),
                                      ),
                                    ),
                                    child: Icon(
                                      Icons.settings_rounded,
                                      color: Colors.white.withValues(alpha: 0.8),
                                      size: 22,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Spacer(flex: 1),
                          FadeTransition(
                            opacity: _fadeAnimation,
                            child: Center(
                              child: Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.white.withValues(alpha: 0.15),
                                      blurRadius: 40,
                                      spreadRadius: 10,
                                    ),
                                  ],
                                ),
                                child: Image.asset(
                                  'assets/images/main_menu.png',
                                  width: MediaQuery.of(context).size.width * 0.9, // Ekran genişliğine göre dinamik boyut
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Sıralama Widget'ı
                          FadeTransition(
                            opacity: _fadeAnimation,
                            child: _DailyRunLeaderboardWidget(),
                          ),
                          // Oyun butonları
                          // 1. Daily Run
                          FadeTransition(
                            opacity: _card1Animation,
                            child: SlideTransition(
                              position: Tween<Offset>(
                                begin: const Offset(0, 0.4),
                                end: Offset.zero,
                              ).animate(_card1Animation),
                              child: _DailyRunGameButton(
                                onTap: () async {
                                  final hasInternet = await NetworkUtils.checkInternet();
                                  if (!context.mounted) return;
                                  
                                  if (!hasInternet) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Daily Run için internet bağlantısı gerekiyor.',
                                          style: GoogleFonts.nunito(color: Colors.white, fontWeight: FontWeight.bold),
                                        ),
                                        backgroundColor: Colors.redAccent,
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                    return;
                                  }

                                  Navigator.push(
                                    context,
                                    PageRouteBuilder(
                                      pageBuilder: (context, animation, secondaryAnimation) => const DailyRunScreen(),
                                      transitionDuration: Duration.zero,
                                      reverseTransitionDuration: Duration.zero,
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          // 2. Oyunlar
                          FadeTransition(
                            opacity: _card2Animation,
                            child: SlideTransition(
                              position: Tween<Offset>(
                                begin: const Offset(0, 0.4),
                                end: Offset.zero,
                              ).animate(_card2Animation),
                              child: _GameButton(
                                title: AppStrings.games,
                                glowColor: const Color(0xFFFFE81F), // Neon yellow glow
                                height: 80,
                                onTap: _navigateToGames,
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          // 3. Seri
                          FadeTransition(
                            opacity: _card3Animation,
                            child: SlideTransition(
                              position: Tween<Offset>(
                                begin: const Offset(0, 0.4),
                                end: Offset.zero,
                              ).animate(_card3Animation),
                              child: _StreakButton(
                                onTap: _navigateToProfile,
                              ),
                            ),
                          ),
                          const Spacer(flex: 5),
                        ],
                      ),
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
    );
  }
}

class _DailyRunGameButton extends StatefulWidget {
  final VoidCallback onTap;

  const _DailyRunGameButton({required this.onTap});

  @override
  State<_DailyRunGameButton> createState() => _DailyRunGameButtonState();
}

class _DailyRunGameButtonState extends State<_DailyRunGameButton> with TickerProviderStateMixin {
  late AnimationController _pressController;
  late Animation<double> _pressAnimation;
  
  late AnimationController _breathController;
  late Animation<double> _breathAnimation;

  Timer? _timer;
  Duration _timeLeft = Duration.zero;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );
    _pressAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _pressController, curve: Curves.easeInOut),
    );

    _breathController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat(reverse: true);
    
    _breathAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _breathController, curve: Curves.easeInOut),
    );

    _updateTimer();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _updateTimer());
  }

  void _updateTimer() {
    final now = DailyRunService.turkeyNow;
    DateTime nextReset;
    if (now.hour < 17) {
      nextReset = DateTime.utc(now.year, now.month, now.day, 17);
    } else {
      nextReset = DateTime.utc(now.year, now.month, now.day + 1, 0);
    }
    
    if (mounted) {
      setState(() {
        _timeLeft = nextReset.difference(now);
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pressController.dispose();
    _breathController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const glowColor = Color(0xFF39FF14);
    final hours = _timeLeft.inHours.toString().padLeft(2, '0');
    final minutes = (_timeLeft.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (_timeLeft.inSeconds % 60).toString().padLeft(2, '0');

    return AnimatedBuilder(
      animation: Listenable.merge([_pressAnimation, _breathAnimation]),
      builder: (context, child) {
        return Transform.scale(
          scale: _pressAnimation.value * _breathAnimation.value,
          child: child,
        );
      },
      child: GestureDetector(
        onTapDown: (_) => _pressController.forward(),
        onTapUp: (_) => _pressController.reverse(),
        onTapCancel: () => _pressController.reverse(),
        onTap: () {
          SoundService().playKeyTap();
          widget.onTap();
        },
        child: Container(
          width: double.infinity,
          height: 80,
          decoration: BoxDecoration(
            color: glowColor.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(40),
            boxShadow: [
              BoxShadow(
                color: glowColor.withValues(alpha: 0.6),
                blurRadius: 24,
                spreadRadius: 2,
              ),
            ],
            border: Border.all(
              color: glowColor,
              width: 3.0,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Daily Run',
                style: GoogleFonts.nunito(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                  shadows: const [Shadow(color: glowColor, blurRadius: 10)],
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${AppStrings.renewalIn}: $hours:$minutes:$seconds',
                style: GoogleFonts.nunito(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GameButton extends StatefulWidget {
  final String title;
  final Color glowColor;
  final double height;
  final VoidCallback onTap;

  const _GameButton({
    required this.title,
    required this.glowColor,
    required this.height,
    required this.onTap,
  });

  @override
  State<_GameButton> createState() => _GameButtonState();
}

class _GameButtonState extends State<_GameButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _pressController;
  late Animation<double> _pressAnimation;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );
    _pressAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _pressController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pressAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _pressAnimation.value,
          child: child,
        );
      },
      child: GestureDetector(
        onTapDown: (_) => _pressController.forward(),
        onTapUp: (_) => _pressController.reverse(),
        onTapCancel: () => _pressController.reverse(),
        onTap: () {
          SoundService().playKeyTap();
          widget.onTap();
        },
        child: Container(
          width: double.infinity,
          height: widget.height,
          decoration: BoxDecoration(
            color: widget.glowColor.withValues(alpha: 0.08), // Hollow / tinted background
            borderRadius: BorderRadius.circular(40),
            boxShadow: [
              // Outer neon glow
              BoxShadow(
                color: widget.glowColor.withValues(alpha: 0.6),
                blurRadius: 24,
                spreadRadius: 2,
              ),
            ],
            border: Border.all(
              color: widget.glowColor, // Bright solid neon border
              width: 3.0,
            ),
          ),
          child: Center(
            child: Text(
              widget.title,
              style: GoogleFonts.nunito(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
                shadows: [
                  Shadow(
                    color: widget.glowColor,
                    blurRadius: 10,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DailyRunLeaderboardWidget extends StatefulWidget {
  @override
  State<_DailyRunLeaderboardWidget> createState() => _DailyRunLeaderboardWidgetState();
}

class _DailyRunLeaderboardWidgetState extends State<_DailyRunLeaderboardWidget> {
  List<LeaderboardEntry>? _entries;
  bool _isLoading = true;
  late String _gameId;
  late String _gameName;

  @override
  void initState() {
    super.initState();
    final slot = DailyRunService.currentRunSlot();
    _gameId = 'daily_run_${slot == 1 ? "morning" : "evening"}';
    _gameName = AppStrings.dailyRunSlotName(slot);
    _loadTop3();
  }

  Future<void> _loadTop3() async {
    final entries = await LeaderboardService().getDailyLeaderboard(_gameId);
    if (mounted) {
      setState(() {
        _entries = entries;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        SoundService().playKeyTap();
        
        final hasInternet = await NetworkUtils.checkInternet();
        if (!context.mounted) return;
        
        if (!hasInternet) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                AppStrings.leaderboardInternetRequired,
                style: GoogleFonts.nunito(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              backgroundColor: Colors.redAccent,
              behavior: SnackBarBehavior.floating,
            ),
          );
          return;
        }

        Navigator.push(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => LeaderboardScreen(
              gameId: _gameId,
              gameName: _gameName,
            ),
            transitionDuration: Duration.zero,
            reverseTransitionDuration: Duration.zero,
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 24),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF0B0514),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.purpleAccent.withValues(alpha: 0.5), width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.purpleAccent.withValues(alpha: 0.2),
              blurRadius: 15,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.emoji_events_rounded, color: Colors.greenAccent, size: 28),
                const SizedBox(width: 8),
                Text(
                  AppStrings.todaysRanking,
                  style: GoogleFonts.nunito(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: Colors.greenAccent,
                    letterSpacing: 1,
                    shadows: [
                      Shadow(
                        color: Colors.greenAccent.withValues(alpha: 0.5),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_isLoading)
              const Center(child: CircularProgressIndicator(color: Colors.purpleAccent))
            else if (_entries == null || _entries!.isEmpty)
              Text(
                AppStrings.noPlayersYet,
                style: GoogleFonts.nunito(color: Colors.white70),
              )
            else
              Column(
                children: List.generate(
                  _entries!.length > 3 ? 3 : _entries!.length,
                  (index) {
                    final entry = _entries![index];
                    final rank = index + 1;
                    Color borderColor;
                    if (rank == 1) {
                      borderColor = Colors.yellowAccent;
                    } else if (rank == 2) {
                      borderColor = Colors.redAccent;
                    } else {
                      borderColor = Colors.greenAccent;
                    }

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: borderColor, width: rank == 1 ? 2 : 1),
                        boxShadow: rank == 1 ? [
                          BoxShadow(
                            color: borderColor.withValues(alpha: 0.4),
                            blurRadius: 10,
                          )
                        ] : null,
                      ),
                      child: Row(
                        children: [
                          Text(
                            rank.toString(),
                            style: GoogleFonts.nunito(
                              fontSize: rank == 1 ? 20 : 18,
                              fontWeight: FontWeight.w900,
                              color: borderColor,
                              shadows: [Shadow(color: borderColor, blurRadius: 8)],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              entry.userId == LeaderboardService().userId
                                  ? AppStrings.you
                                  : _shortenName(entry.displayName).toUpperCase(),
                              style: GoogleFonts.nunito(
                                fontSize: rank == 1 ? 16 : 14,
                                fontWeight: FontWeight.w800,
                                color: Colors.greenAccent,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            entry.score.toStringAsFixed(1),
                            style: GoogleFonts.nunito(
                              fontSize: rank == 1 ? 18 : 16,
                              fontWeight: FontWeight.w900,
                              color: Colors.greenAccent,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            const SizedBox(height: 12),
            Text(
              AppStrings.seeAll,
              style: GoogleFonts.nunito(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.purpleAccent,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _shortenName(String name) {
    final hashIndex = name.indexOf('#');
    if (hashIndex > 0) {
      return name.substring(0, hashIndex).trim();
    }
    return name;
  }
}

class _StreakButton extends StatefulWidget {
  final VoidCallback onTap;

  const _StreakButton({required this.onTap});

  @override
  State<_StreakButton> createState() => _StreakButtonState();
}

class _StreakButtonState extends State<_StreakButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _pressController;
  late Animation<double> _pressAnimation;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );
    _pressAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _pressController, curve: Curves.easeInOut),
    );
    StreakService().addListener(_onStreakChanged);
  }

  void _onStreakChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _pressController.dispose();
    StreakService().removeListener(_onStreakChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final streak = StreakService().currentStreak;
    final isFrozen = StreakService().isFrozenToday;
    
    final glowColor = isFrozen ? const Color(0xFF40C4FF) : const Color(0xFFFF007F); // Ice blue if frozen
    final badgeColor = isFrozen ? const Color(0xFF00B0FF) : const Color(0xFFFF6E40); // Ice blue badge
    final iconText = isFrozen ? '❄️' : '🔥';

    return AnimatedBuilder(
      animation: _pressAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _pressAnimation.value,
          child: child,
        );
      },
      child: GestureDetector(
        onTapDown: (_) => _pressController.forward(),
        onTapUp: (_) => _pressController.reverse(),
        onTapCancel: () => _pressController.reverse(),
        onTap: () {
          SoundService().playKeyTap();
          widget.onTap();
        },
        child: Container(
          width: double.infinity,
          height: 80,
          decoration: BoxDecoration(
            color: glowColor.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(40),
            boxShadow: [
              BoxShadow(
                color: glowColor.withValues(alpha: 0.6),
                blurRadius: 24,
                spreadRadius: 2,
              ),
            ],
            border: Border.all(
              color: glowColor,
              width: 3.0,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                AppStrings.streak,
                style: GoogleFonts.nunito(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                  shadows: [Shadow(color: glowColor, blurRadius: 10)],
                ),
              ),
              if (streak > 0) ...[
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: badgeColor.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: badgeColor.withValues(alpha: 0.6),
                    ),
                  ),
                  child: Text(
                    '$streak $iconText',
                    style: GoogleFonts.nunito(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
