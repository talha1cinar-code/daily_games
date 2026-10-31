import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/game_model.dart';
import '../services/daily_run_service.dart';
import '../services/language_service.dart';
import '../services/sound_service.dart';
import '../utils/network_utils.dart';
import '../widgets/chunky_button.dart';
import '../widgets/streak_style.dart';
import 'daily_run_screen.dart';
import 'home_screen.dart';

/// İlk açılışta 3 sayfalık tanıtım: gerçek oyunları ve seriyi gösterir, sonunda kullanıcıyı
/// doğrudan Daily Run'a götürür.
class OnboardingScreen extends StatefulWidget {
  static const String doneKey = 'onboarding_done';

  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  static const int _pageCount = 3;

  final PageController _pages = PageController();
  int _page = 0;
  bool _finishing = false;

  bool get _tr => LanguageService().isTurkish;
  bool get _last => _page == _pageCount - 1;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  Route<void> _instant(Widget page) => PageRouteBuilder(
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionDuration: Duration.zero,
    reverseTransitionDuration: Duration.zero,
  );

  Future<void> _finish({required bool startRun}) async {
    if (_finishing) return;
    _finishing = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(OnboardingScreen.doneKey, true);
    final online = startRun && await NetworkUtils.checkInternet();
    if (!mounted) return;
    final nav = Navigator.of(context);
    nav.pushReplacement(_instant(const HomeScreen()));
    if (online) nav.push(_instant(const DailyRunScreen()));
  }

  void _next() {
    if (_last) {
      _finish(startRun: true);
    } else {
      _pages.nextPage(duration: const Duration(milliseconds: 280), curve: Curves.easeOut);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1450),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF3A0F6E), Color(0xFF1A1450), Color(0xFF0E1638)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildTop(),
              Expanded(
                child: PageView(
                  controller: _pages,
                  onPageChanged: (i) => setState(() => _page = i),
                  children: [_page1(), _page2(), _page3()],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: ChunkyButton(
                  face: const Color(0xFF3DDC84),
                  lip: const Color(0xFF1E9E55),
                  height: 58,
                  onTap: _next,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        _last ? (_tr ? 'İlk koşuya başla' : 'Start your first run') : (_tr ? 'Devam' : 'Next'),
                        style: GoogleFonts.nunito(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// İlerleme çubukları ve "Geç"
  Widget _buildTop() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 8, 0),
      child: Row(
        children: [
          for (var i = 0; i < _pageCount; i++)
            Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: 6,
                margin: const EdgeInsets.only(right: 6),
                decoration: BoxDecoration(
                  color: i <= _page ? const Color(0xFF3DDC84) : Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          const SizedBox(width: 4),
          TextButton(
            onPressed: () {
              SoundService().playKeyTap();
              _finish(startRun: false);
            },
            child: Text(
              _tr ? 'Geç' : 'Skip',
              style: GoogleFonts.nunito(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white60),
            ),
          ),
        ],
      ),
    );
  }

  /// Üstte görsel, altta sola dayalı metin. Görsel kalan alanı doldurur; çok dar ekranda
  /// metin en fazla yarıyı alır ve kayar, böylece hiçbir boyutta taşmaz.
  Widget _pageFrame({required Widget visual, required String title, required String body}) {
    return LayoutBuilder(
      builder: (context, c) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: visual),
            ),
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: c.maxHeight * 0.5),
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: SizedBox(
                    width: double.infinity,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: GoogleFonts.nunito(
                            fontSize: 30,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            height: 1.12,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          body,
                          style: GoogleFonts.nunito(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white70,
                            height: 1.4,
                          ),
                        ),
                      ],
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

  Widget _gameIcon(GameModel g, double size) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.24),
      child: g.imagePath != null
          ? Image.asset(g.imagePath!, width: size, height: size, fit: BoxFit.cover, cacheWidth: 180)
          : Container(
              width: size,
              height: size,
              color: Colors.white12,
              child: Icon(g.icon, color: Colors.white, size: size * 0.6),
            ),
    );
  }

  // ─── 1: Bugünkü iki koşu, gerçek oyunlarıyla ─────────────────────
  Widget _page1() {
    final now = DailyRunService.turkeyNow;
    final today = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    return _pageFrame(
      visual: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Flexible(
            child: _runCard(
              icon: Icons.wb_sunny_rounded,
              color: const Color(0xFFFFC857),
              name: _tr ? 'Sabah koşusu' : 'Morning run',
              time: _tr ? '00.00\'da başlar' : 'starts 00:00',
              gameIds: DailyRunService.gameOrderFor(today, 1),
            ),
          ),
          const SizedBox(height: 12),
          Flexible(
            child: _runCard(
              icon: Icons.nightlight_round,
              color: const Color(0xFFB9A8FF),
              name: _tr ? 'Akşam koşusu' : 'Evening run',
              time: _tr ? '17.00\'de başlar' : 'starts 17:00',
              gameIds: DailyRunService.gameOrderFor(today, 2),
            ),
          ),
        ],
      ),
      title: _tr ? 'Günde iki koşu, yedi oyun' : 'Two runs a day, seven games',
      body: _tr
          ? 'Herkes aynı bulmacaları oynar. Sıralamada kimin önde olduğu da buradan belli olur.'
          : 'Everyone gets the same puzzles, so the ranking shows who really did best.',
    );
  }

  Widget _runCard({
    required IconData icon,
    required Color color,
    required String name,
    required String time,
    required List<String> gameIds,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.25), borderRadius: BorderRadius.circular(20)),
      child: FittedBox(
        fit: BoxFit.contain,
        alignment: Alignment.centerLeft,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: color, size: 22),
                const SizedBox(width: 8),
                Text(
                  name,
                  style: GoogleFonts.nunito(fontSize: 17, fontWeight: FontWeight.w900, color: Colors.white),
                ),
                const SizedBox(width: 10),
                Text(
                  time,
                  style: GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white60),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final id in gameIds)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: _gameIcon(games.firstWhere((g) => g.id == id), 42),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ─── 2: Tüm oyunlar ──────────────────────────────────────────────
  Widget _page2() {
    return _pageFrame(
      visual: LayoutBuilder(
        builder: (context, c) {
          // En büyük ikonu verecek sütun sayısını seç
          var bestSize = 0.0, bestCols = 1;
          const gap = 8.0;
          for (var cols = 3; cols <= 10; cols++) {
            final rows = (games.length / cols).ceil();
            final size = min((c.maxWidth - gap * (cols - 1)) / cols, (c.maxHeight - gap * (rows - 1)) / rows);
            if (size > bestSize) {
              bestSize = size;
              bestCols = cols;
            }
          }
          final size = max(bestSize.floorToDouble(), 1.0);
          return Center(
            child: SizedBox(
              width: bestCols * size + (bestCols - 1) * gap,
              child: Wrap(spacing: gap, runSpacing: gap, children: [for (final g in games) _gameIcon(g, size)]),
            ),
          );
        },
      ),
      title: _tr ? '${games.length} oyun, hepsi kısa' : '${games.length} games, all short',
      body: _tr
          ? 'Kelime, hafıza, ritim, refleks, görsel algı. Çoğu bir iki dakikada biter.'
          : 'Words, memory, rhythm, reflexes, perception. Most take a minute or two.',
    );
  }

  // ─── 3: Seri ve alev kademeleri ──────────────────────────────────
  Widget _page3() {
    final tiers = StreakTier.all.where((t) => t.minDays > 0).toList();
    return _pageFrame(
      visual: Center(
        child: FittedBox(
          fit: BoxFit.contain,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < tiers.length; i++)
                SizedBox(
                  width: 74,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      StreakFlame(streak: tiers[i].minDays, size: 44.0 + i * 10, animate: false),
                      const SizedBox(height: 6),
                      Text(
                        '${tiers[i].minDays}',
                        style: GoogleFonts.nunito(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          height: 1.1,
                        ),
                      ),
                      Text(
                        _tr ? 'gün' : (tiers[i].minDays == 1 ? 'day' : 'days'),
                        style: GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white60),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
      title: _tr ? 'Her gün oyna, alev büyüsün' : 'Play daily, grow the flame',
      body: _tr
          ? 'Bir oyun bitirmek seriyi uzatır. Bir gün kaçırırsan donma hakkın seriyi kurtarır.'
          : 'Finishing one game extends your streak. Miss a day and a freeze saves it.',
    );
  }
}
