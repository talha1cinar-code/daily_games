import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/game_model.dart';
import '../services/daily_run_service.dart';
import '../services/language_service.dart';
import '../services/sound_service.dart';
import '../utils/network_utils.dart';
import 'daily_run_screen.dart';
import 'home_screen.dart';

/// İlk açılışta 3 sayfalık tanıtım; sonunda kullanıcıyı doğrudan Daily Run'a götürür.
class OnboardingScreen extends StatefulWidget {
  static const String doneKey = 'onboarding_done';

  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pages = PageController();
  int _page = 0;

  bool get _tr => LanguageService().isTurkish;

  List<(IconData, Color, String, String)> get _slides => [
        (
          Icons.wb_twilight_rounded,
          const Color(0xFFFFB74D),
          _tr ? 'Günde iki koşu' : 'Two runs a day',
          _tr
              ? 'Sabah ve akşam yeni bir Daily Run başlar. Herkes aynı ${DailyRunService.gamesPerRun} oyunu aynı sırayla oynar.'
              : 'A new Daily Run starts every morning and evening. Everyone plays the same ${DailyRunService.gamesPerRun} games in the same order.',
        ),
        (
          Icons.grid_view_rounded,
          const Color(0xFF4DD0E1),
          _tr ? '${games.length} mini oyun' : '${games.length} mini games',
          _tr
              ? 'Kelime, mantık, refleks, hafıza, renk... Her biri bir iki dakika sürer.'
              : 'Words, logic, reflexes, memory, colour... each takes a minute or two.',
        ),
        (
          Icons.local_fire_department_rounded,
          const Color(0xFFFF6E40),
          _tr ? 'Serini koru' : 'Keep your streak',
          _tr
              ? 'Her gün en az bir koşuyu bitir, seriyi büyüt, rozetleri topla ve arkadaşlarınla yarış.'
              : 'Finish at least one run a day to grow your streak, collect badges and race your friends.',
        ),
      ];

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  Future<void> _finish({required bool startRun}) async {
    SoundService().playKeyTap();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(OnboardingScreen.doneKey, true);
    final online = startRun && await NetworkUtils.checkInternet();
    if (!mounted) return;
    final nav = Navigator.of(context);
    nav.pushReplacement(MaterialPageRoute(builder: (_) => const HomeScreen()));
    if (online) {
      nav.push(MaterialPageRoute(builder: (_) => const DailyRunScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    final slides = _slides;
    final last = _page == slides.length - 1;
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF2E0854), Color(0xFF0F3460), Color(0xFF16213E)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => _finish(startRun: false),
                  child: Text(_tr ? 'Geç' : 'Skip',
                      style: GoogleFonts.nunito(fontWeight: FontWeight.w700, color: Colors.white54)),
                ),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _pages,
                  itemCount: slides.length,
                  onPageChanged: (i) => setState(() => _page = i),
                  itemBuilder: (context, i) {
                    final (icon, color, title, body) = slides[i];
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 36),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: color.withValues(alpha: 0.15),
                            ),
                            child: Icon(icon, size: 60, color: color),
                          ),
                          const SizedBox(height: 36),
                          Text(
                            title,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.nunito(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.white),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            body,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.nunito(fontSize: 16, height: 1.5, color: Colors.white70),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(slides.length, (i) {
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: i == _page ? 24 : 8,
                    height: 8,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: i == _page ? Colors.white : Colors.white24,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  );
                }),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      if (last) {
                        _finish(startRun: true);
                      } else {
                        SoundService().playKeyTap();
                        _pages.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF39FF14),
                      foregroundColor: const Color(0xFF0F1A0B),
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                      elevation: 0,
                    ),
                    child: Text(
                      last ? (_tr ? 'İlk koşuna başla' : 'Start your first run') : (_tr ? 'Devam' : 'Next'),
                      style: GoogleFonts.nunito(fontSize: 18, fontWeight: FontWeight.w900),
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
}
