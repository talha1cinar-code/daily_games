import 'package:flutter/material.dart';
import '../../widgets/game_exit_wrapper.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../services/sound_service.dart';
import '../../services/daily_challenge_service.dart';
import '../../services/ticket_service.dart';
import '../../services/stats_service.dart';
import '../../services/leaderboard_service.dart';
import 'country.dart';
import 'worldle_game.dart';
import '../../services/language_service.dart';
import '../../services/app_strings.dart';

class WorldleScreen extends StatefulWidget {
  final bool isDailyMode;
  final void Function(double score, [int durationMs])? onGameComplete;
  const WorldleScreen({super.key, this.isDailyMode = true, this.onGameComplete});

  @override
  State<WorldleScreen> createState() => _WorldleScreenState();
}

class _WorldleScreenState extends State<WorldleScreen>
    with TickerProviderStateMixin {
  late WorldleGame _game;
  bool _isLoading = true;
  final SoundService _sound = SoundService();
  Country? _selectedCountry;
  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  // Animasyonlar
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  
  // Süre ölçümü
  DateTime? _startTime;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _initGame();
  }

  Future<void> _initGame() async {
    Country target;
    if (widget.isDailyMode) {
      target = allCountries[DailyChallengeService.getSeededWorldleIndex(allCountries.length)];
    } else {
      target = getRandomCountry();
    }
    
    setState(() {
      _game = WorldleGame(targetCountry: target);
      _isLoading = false;
      _startTime = DateTime.now();
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onGuessSubmit() {
    if (_selectedCountry == null) return;

    final result = _game.submitGuess(_selectedCountry!);

    setState(() {
      _selectedCountry = null;
      _textController.clear();
    });

    if (result == WorldleGuessResult.correct || result == WorldleGuessResult.outOfAttempts) {
      final durationMs = _startTime != null ? DateTime.now().difference(_startTime!).inMilliseconds : null;
      if (widget.onGameComplete != null) {
        final score = LeaderboardService.calculateLeaderboardScore(
          gameId: 'worldle',
          isWin: _game.isWon,
          attempts: _game.guesses.length,
          maxAttempts: WorldleGame.maxAttempts,
          durationMs: durationMs,
        );
        widget.onGameComplete!(score, durationMs ?? 0);
      } else if (widget.isDailyMode) {
        TicketService().markDailyPlayed('worldle');
        StatsService().saveDailyStat(
          gameId: 'worldle',
          isWin: _game.isWon,
          attempts: _game.guesses.length,
          maxAttempts: WorldleGame.maxAttempts,
          targetValue: _game.targetCountry.name,
          durationMs: durationMs,
        );
        LeaderboardService().submitScore(
          gameId: 'worldle',
          score: LeaderboardService.calculateLeaderboardScore(
            gameId: 'worldle',
            isWin: _game.isWon,
            attempts: _game.guesses.length,
            maxAttempts: WorldleGame.maxAttempts,
            durationMs: durationMs,
          ),
          attempts: _game.guesses.length,
          maxAttempts: WorldleGame.maxAttempts,
          durationMs: durationMs,
          isWin: _game.isWon,
        );
      }
    }

    switch (result) {
      case WorldleGuessResult.correct:
        _sound.playWin();
        Future.delayed(
          const Duration(milliseconds: 800),
          _showGameOverDialog,
        );
      case WorldleGuessResult.outOfAttempts:
        _sound.playLose();
        Future.delayed(
          const Duration(milliseconds: 800),
          _showGameOverDialog,
        );
      case WorldleGuessResult.wrong:
        _sound.playFlip();
      case WorldleGuessResult.alreadyGuessed:
        _showSnackBar(LanguageService().currentLanguage == 'tr' ? 'Bu ülkeyi zaten tahmin ettin!' : 'You already guessed this country!');
        _sound.playError();
      case WorldleGuessResult.gameOver:
        break;
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.nunito(fontWeight: FontWeight.w500),
        ),
        backgroundColor: const Color(0xFF3D3D50),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showGameOverDialog() {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          backgroundColor: const Color(0xFF1B1B2F),
          contentPadding: const EdgeInsets.all(28),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 500),
                curve: Curves.elasticOut,
                builder: (context, value, child) =>
                    Transform.scale(scale: value, child: child),
                child: Text(
                  _game.isWon ? '🌍' : '😔',
                  style: const TextStyle(fontSize: 56),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _game.isWon ? AppStrings.congratulations : AppStrings.sorry,
                style: GoogleFonts.nunito(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: _game.isWon
                      ? const Color(0xFF6BCB77)
                      : const Color(0xFFFF6B6B),
                ),
              ),
              const SizedBox(height: 8),
              if (_game.isWon)
                Text(
                  LanguageService().currentLanguage == 'tr' ? '${_game.guesses.length}/${WorldleGame.maxAttempts} denemede buldun!' : 'Found in ${_game.guesses.length}/${WorldleGame.maxAttempts} attempts!',
                  style: GoogleFonts.nunito(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: Colors.white70,
                  ),
                )
              else
                Column(
                  children: [
                    Text(
                      LanguageService().currentLanguage == 'tr' ? 'Doğru cevap:' : 'Correct answer:',
                      style: GoogleFonts.nunito(
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        color: Colors.white54,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_game.targetCountry.flagEmoji} ${_game.targetCountry.name}',
                      style: GoogleFonts.nunito(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF6BCB77),
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).pop();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6C5CE7),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: Text(widget.onGameComplete != null ? (LanguageService().currentLanguage == 'tr' ? 'Sonraki' : 'Next') : (LanguageService().currentLanguage == 'tr' ? 'Ana Sayfa' : 'Home'),
                      style: GoogleFonts.nunito(
                          fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF1B1B2F),
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return GameExitWrapper(gameId: 'worldle', isDailyMode: widget.isDailyMode, onGameComplete: widget.onGameComplete, child: Scaffold(
      backgroundColor: const Color(0xFF1B1B2F),
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    const SizedBox(height: 12),
                    _buildCountrySilhouette(),
                    const SizedBox(height: 20),
                    if (!_game.isGameOver) ...[
                      _buildSearchField(),
                      const SizedBox(height: 12),
                      _buildGuessButton(),
                    ],
                    const SizedBox(height: 20),
                    _buildGuessHistory(),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ));
  }

  // ─── Üst Bar ──────────────────────────────────────────────────────
  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.arrow_back_ios_new_rounded,
                  color: Colors.white.withValues(alpha: 0.8), size: 18),
            ),
          ),
          const Spacer(),
          Text(
            'WORLDLE',
            style: GoogleFonts.nunito(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: 4,
            ),
          ),
          const Spacer(),
          // Kalan hak göstergesi
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: _game.remainingAttempts > 2
                  ? const Color(0xFF6BCB77).withValues(alpha: 0.2)
                  : const Color(0xFFFF6B6B).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '${_game.remainingAttempts}/${WorldleGame.maxAttempts}',
              style: GoogleFonts.nunito(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: _game.remainingAttempts > 2
                    ? const Color(0xFF6BCB77)
                    : const Color(0xFFFF6B6B),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Ülke Silüeti / Placeholder ───────────────────────────────────
  Widget _buildCountrySilhouette() {
    final targetIso = _game.targetCountry.isoCode.toLowerCase();
    final svgUrl = 'https://raw.githubusercontent.com/djaiss/mapsicon/master/all/$targetIso/vector.svg';

    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _game.isWon ? 1.0 : _pulseAnimation.value,
          child: child,
        );
      },
      child: Container(
        width: double.infinity,
        height: 160,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: _game.isWon
                ? [
                    const Color(0xFF6BCB77).withValues(alpha: 0.3),
                    const Color(0xFF00B894).withValues(alpha: 0.3),
                  ]
                : [
                    const Color(0xFF6C5CE7).withValues(alpha: 0.2),
                    const Color(0xFF0984E3).withValues(alpha: 0.2),
                  ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: _game.isWon
                ? const Color(0xFF6BCB77).withValues(alpha: 0.4)
                : Colors.white.withValues(alpha: 0.1),
            width: 1.5,
          ),
        ),
        child: _game.isWon
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _game.targetCountry.flagEmoji,
                    style: const TextStyle(fontSize: 48),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _game.targetCountry.name,
                    style: GoogleFonts.nunito(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF6BCB77),
                    ),
                  ),
                ],
              )
            : Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: SvgPicture.network(
                    svgUrl,
                    colorFilter: const ColorFilter.mode(
                      Colors.white,
                      BlendMode.srcIn,
                    ),
                    placeholderBuilder: (BuildContext context) => Icon(
                      Icons.map_rounded,
                      size: 80,
                      color: Colors.white.withValues(alpha: 0.2),
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  // ─── Arama / Autocomplete ─────────────────────────────────────────
  Widget _buildSearchField() {
    return Autocomplete<Country>(
      optionsBuilder: (TextEditingValue textEditingValue) {
        if (textEditingValue.text.isEmpty) {
          return const Iterable<Country>.empty();
        }
        final query = textEditingValue.text.toLowerCase();
        return allCountries.where((country) {
          // Zaten tahmin edilen ülkeleri filtreleme dışında bırak
          final alreadyGuessed =
              _game.guesses.any((g) => g.country == country);
          return !alreadyGuessed &&
              country.name.toLowerCase().contains(query);
        });
      },
      displayStringForOption: (Country country) => country.name,
      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
        // Sync dış controller
        _textController.addListener(() {});
        return TextField(
          controller: controller,
          focusNode: focusNode,
          style: GoogleFonts.nunito(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            hintText: LanguageService().currentLanguage == 'tr' ? 'Bir ülke adı yaz...' : 'Type a country name...',
            hintStyle: GoogleFonts.nunito(
              color: Colors.white.withValues(alpha: 0.3),
              fontSize: 15,
            ),
            prefixIcon: Icon(
              Icons.search_rounded,
              color: Colors.white.withValues(alpha: 0.4),
            ),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.08),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: Colors.white.withValues(alpha: 0.1),
                width: 1,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(
                color: Color(0xFF6C5CE7),
                width: 2,
              ),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 8,
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              constraints: const BoxConstraints(maxHeight: 200),
              margin: const EdgeInsets.only(top: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF2A2A40),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.1),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  itemCount: options.length,
                  separatorBuilder: (_, _) => Divider(
                    height: 1,
                    color: Colors.white.withValues(alpha: 0.06),
                  ),
                  itemBuilder: (context, index) {
                    final country = options.elementAt(index);
                    return ListTile(
                      dense: true,
                      leading: Text(
                        country.flagEmoji,
                        style: const TextStyle(fontSize: 22),
                      ),
                      title: Text(
                        country.name,
                        style: GoogleFonts.nunito(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      subtitle: Text(
                        country.isoCode,
                        style: GoogleFonts.nunito(
                          color: Colors.white.withValues(alpha: 0.4),
                          fontSize: 12,
                        ),
                      ),
                      onTap: () => onSelected(country),
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
      onSelected: (Country country) {
        FocusScope.of(context).unfocus(); // Klavyeyi kapat
        setState(() => _selectedCountry = country);
      },
    );
  }

  // ─── Tahmin Butonu ────────────────────────────────────────────────
  Widget _buildGuessButton() {
    final isActive = _selectedCountry != null;

    return SizedBox(
      width: double.infinity,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        child: ElevatedButton(
          onPressed: isActive ? _onGuessSubmit : null,
          style: ElevatedButton.styleFrom(
            backgroundColor:
                isActive ? const Color(0xFF6C5CE7) : const Color(0xFF2A2A40),
            foregroundColor: Colors.white,
            disabledBackgroundColor: const Color(0xFF2A2A40),
            disabledForegroundColor: Colors.white.withValues(alpha: 0.3),
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: isActive
                    ? const Color(0xFF6C5CE7)
                    : Colors.white.withValues(alpha: 0.1),
              ),
            ),
            elevation: isActive ? 4 : 0,
            shadowColor: const Color(0xFF6C5CE7).withValues(alpha: 0.4),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.send_rounded,
                size: 18,
                color: isActive
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.3),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  _selectedCountry != null
                      ? '${_selectedCountry!.flagEmoji} ${_selectedCountry!.name} — ${LanguageService().currentLanguage == 'tr' ? 'Tahmin Et' : 'Guess'}'
                      : (LanguageService().currentLanguage == 'tr' ? 'Bir ülke seç' : 'Select a country'),
                  style: GoogleFonts.nunito(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Tahmin Geçmişi ───────────────────────────────────────────────
  Widget _buildGuessHistory() {
    if (_game.guesses.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          children: [
            Icon(
              Icons.history_rounded,
              size: 36,
              color: Colors.white.withValues(alpha: 0.15),
            ),
            const SizedBox(height: 8),
            Text(
              LanguageService().currentLanguage == 'tr' ? 'Tahminlerin burada görünecek' : 'Your guesses will appear here',
              style: GoogleFonts.nunito(
                fontSize: 14,
                color: Colors.white.withValues(alpha: 0.2),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            LanguageService().currentLanguage == 'tr' ? 'Tahminler' : 'Guesses',
            style: GoogleFonts.nunito(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.6),
            ),
          ),
        ),
        ...List.generate(_game.guesses.length, (index) {
          // Sondan başa sırala — en son tahmin üstte
          final guess = _game.guesses[_game.guesses.length - 1 - index];
          return _buildGuessRow(guess, index);
        }),
      ],
    );
  }

  Widget _buildGuessRow(WorldleGuess guess, int animIndex) {
    final isCorrect = guess.isCorrect;

    return TweenAnimationBuilder<double>(
      key: ValueKey(guess.country.isoCode),
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 400 + animIndex * 50),
      curve: Curves.easeOutBack,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 20 * (1 - value)),
          child: Opacity(opacity: value.clamp(0.0, 1.0), child: child),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isCorrect
              ? const Color(0xFF6BCB77).withValues(alpha: 0.15)
              : Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isCorrect
                ? const Color(0xFF6BCB77).withValues(alpha: 0.4)
                : Colors.white.withValues(alpha: 0.08),
            width: 1,
          ),
        ),
        child: Column(
          children: [
            // Üst satır: bayrak + isim + mesafe + yön
            Row(
              children: [
                // Bayrak
                Text(
                  guess.country.flagEmoji,
                  style: const TextStyle(fontSize: 26),
                ),
                const SizedBox(width: 10),
                // Ülke adı
                Expanded(
                  child: Text(
                    guess.country.name,
                    style: GoogleFonts.nunito(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isCorrect
                          ? const Color(0xFF6BCB77)
                          : Colors.white,
                    ),
                  ),
                ),
                // Mesafe
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getDistanceColor(guess.proximityPercent)
                        .withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    guess.formattedDistance,
                    style: GoogleFonts.nunito(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _getDistanceColor(guess.proximityPercent),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Yön oku
                if (!isCorrect)
                  Text(
                    guess.directionArrow,
                    style: const TextStyle(fontSize: 22),
                  )
                else
                  const Text('🎯', style: TextStyle(fontSize: 22)),
              ],
            ),
            const SizedBox(height: 10),
            // Alt satır: yakınlık barı
            _buildProximityBar(guess.proximityPercent),
          ],
        ),
      ),
    );
  }

  // ─── Yakınlık Barı ────────────────────────────────────────────────
  Widget _buildProximityBar(double percent) {
    final color = _getDistanceColor(percent);

    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: percent / 100),
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeOutCubic,
              builder: (context, value, _) {
                return Stack(
                  children: [
                    // Arka plan
                    Container(
                      height: 8,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    // Doluluk
                    FractionallySizedBox(
                      widthFactor: value,
                      child: Container(
                        height: 8,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              color.withValues(alpha: 0.7),
                              color,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(6),
                          boxShadow: [
                            BoxShadow(
                              color: color.withValues(alpha: 0.4),
                              blurRadius: 6,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 48,
          child: Text(
            '${percent.round()}%',
            textAlign: TextAlign.right,
            style: GoogleFonts.nunito(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ),
      ],
    );
  }

  /// Yakınlık yüzdesine göre renk döndürür (kırmızı → sarı → yeşil)
  Color _getDistanceColor(double percent) {
    if (percent >= 80) return const Color(0xFF6BCB77);
    if (percent >= 60) return const Color(0xFF00B894);
    if (percent >= 40) return const Color(0xFFFECE54);
    if (percent >= 20) return const Color(0xFFFDAA5E);
    return const Color(0xFFFF6B6B);
  }
}
