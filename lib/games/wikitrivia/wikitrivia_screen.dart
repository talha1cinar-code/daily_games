
import 'package:flutter/material.dart';
import '../../widgets/game_exit_wrapper.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/sound_service.dart';
import '../../services/daily_challenge_service.dart';
import '../../services/ticket_service.dart';
import '../../services/stats_service.dart';
import '../../services/leaderboard_service.dart';
import '../../services/personal_best_service.dart';
import 'wikitrivia_game.dart';
import 'wikitrivia_data.dart';
import '../../services/language_service.dart';

class WikitriviaScreen extends StatefulWidget {
  final bool isDailyMode;
  final void Function(double score, [int durationMs])? onGameComplete;
  const WikitriviaScreen({super.key, this.isDailyMode = true, this.onGameComplete});

  @override
  State<WikitriviaScreen> createState() => _WikitriviaScreenState();
}

class _WikitriviaScreenState extends State<WikitriviaScreen>
    with TickerProviderStateMixin {
  late WikitriviaGame _game;
  bool _isLoading = true;
  final SoundService _sound = SoundService();

  late AnimationController _cardEntryController;
  late Animation<double> _cardEntryAnimation;

  late AnimationController _flashController;
  late Animation<double> _flashAnimation;

  PlacementResult? _lastResult;
  int? _flashingIndex;
  int? _activeDropSlot;

  final ScrollController _scrollController = ScrollController();

  late AnimationController _lifeShakeController;
  late Animation<double> _lifeShakeAnimation;
  
  // Süre ölçümü
  DateTime? _startTime;

  @override
  void initState() {
    super.initState();

    _cardEntryController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _cardEntryAnimation = CurvedAnimation(
      parent: _cardEntryController,
      curve: Curves.easeOutBack,
    );

    _flashController = AnimationController(
      duration: const Duration(milliseconds: 900),
      vsync: this,
    );
    _flashAnimation = CurvedAnimation(
      parent: _flashController,
      curve: Curves.easeOut,
    );
    _flashController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() {
          _lastResult = null;
          _flashingIndex = null;
        });
        _flashController.reset();

        if (_game.isGameOver) {
          final durationMs = _startTime != null ? DateTime.now().difference(_startTime!).inMilliseconds : null;
          if (widget.onGameComplete != null) {
            final score = LeaderboardService.calculateLeaderboardScore(
              gameId: 'wikitrivia',
              isWin: true,
              score: _game.score.toDouble(),
              durationMs: durationMs,
            );
            widget.onGameComplete!(score, durationMs ?? 0);
          } else if (widget.isDailyMode) {
            TicketService().markDailyPlayed('wikitrivia');
            StatsService().saveDailyStat(
              gameId: 'wikitrivia',
              isWin: true,
              score: _game.score.toDouble(),
              attempts: _game.score,
              maxAttempts: 10,
              durationMs: durationMs,
            );
            LeaderboardService().submitScore(
              gameId: 'wikitrivia',
              score: LeaderboardService.calculateLeaderboardScore(
                gameId: 'wikitrivia',
                isWin: true,
                score: _game.score.toDouble(),
                durationMs: durationMs,
              ),
              attempts: _game.score,
              maxAttempts: 10,
              durationMs: durationMs,
              isWin: true,
            );
          } else {
            PersonalBestService().submit(
              'wikitrivia',
              LeaderboardService.calculateLeaderboardScore(
                gameId: 'wikitrivia',
                isWin: true,
                score: _game.score.toDouble(),
                durationMs: durationMs,
              ),
            );
          }
          Future.delayed(
              const Duration(milliseconds: 400), _showGameOverDialog);
        } else {
          _cardEntryController.reset();
          _cardEntryController.forward();
        }
      }
    });

    _lifeShakeController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _lifeShakeAnimation = CurvedAnimation(
      parent: _lifeShakeController,
      curve: Curves.elasticIn,
    );
    _lifeShakeController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _lifeShakeController.reset();
      }
    });

    _initGame();
  }

  Future<void> _initGame() async {
    List<HistoricalEvent>? externalEvents;
    
    if (widget.isDailyMode) {
      final sourceEvents = LanguageService().currentLanguage == 'tr' ? defaultHistoricalEventsTr : defaultHistoricalEventsEn;
      externalEvents = DailyChallengeService.getSeededWikitriviaEvents(
        sourceEvents,
        take: 15,
      );
    }
    
    setState(() {
      _game = WikitriviaGame(externalEvents: externalEvents);
      _isLoading = false;
      _startTime = DateTime.now();
    });
    
    _cardEntryController.forward();
  }

  @override
  void dispose() {
    _cardEntryController.dispose();
    _flashController.dispose();
    _lifeShakeController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _placeCard(int insertIndex) {
    if (_flashController.isAnimating) return;

    final info = _game.placeCard(insertIndex);

    setState(() {
      _lastResult = info.result;
      _flashingIndex = info.correctIndex;
      _activeDropSlot = null;
    });

    if (info.result == PlacementResult.correct) {
      _sound.playKeyTap();
    } else {
      _sound.playError();
      _lifeShakeController.forward();
    }

    _flashController.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToIndex(info.correctIndex);
    });
  }

  void _scrollToIndex(int index) {
    if (!_scrollController.hasClients) return;
    final targetOffset = (index * 175.0) - 40;
    _scrollController.animateTo(
      targetOffset.clamp(0.0, _scrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
    );
  }

  void _showGameOverDialog() {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          backgroundColor: const Color(0xFF2A2A3E),
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
                  _game.isWon ? '🏆' : '💔',
                  style: const TextStyle(fontSize: 56),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _game.isWon ? (LanguageService().currentLanguage == 'tr' ? 'Tebrikler!' : 'Congratulations!') : (LanguageService().currentLanguage == 'tr' ? 'Oyun Bitti!' : 'Game Over!'),
                style: GoogleFonts.nunito(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: _game.isWon
                      ? const Color(0xFF6BCB77)
                      : const Color(0xFFFF6B6B),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                LanguageService().currentLanguage == 'tr' ? '${_game.score}/${_game.totalAttempts} doğru yerleştirme' : '${_game.score}/${_game.totalAttempts} correct placements',
                style: GoogleFonts.nunito(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: Colors.white70,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(ctx).pop();
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
        backgroundColor: Color(0xFF1E1E2E),
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return GameExitWrapper(gameId: 'wikitrivia', isDailyMode: widget.isDailyMode, onGameComplete: widget.onGameComplete, child: Scaffold(
      backgroundColor: const Color(0xFF1E1E2E),
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            const SizedBox(height: 16),
            // Üstteki mevcut kart — yukarıda, sabit konumda
            _buildDraggableCurrentCard(),
            const Spacer(),
            // İpucu yazısı
            if (_game.currentCard != null && !_flashController.isAnimating)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.swipe_rounded,
                        color: Colors.white.withValues(alpha: 0.3), size: 18),
                    const SizedBox(width: 6),
                    Text(
                      LanguageService().currentLanguage == 'tr' ? 'Kartı sürükleyerek zaman çizelgesine bırak' : 'Drag the card and drop to timeline',
                      style: GoogleFonts.nunito(
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: Colors.white.withValues(alpha: 0.3),
                      ),
                    ),
                  ],
                ),
              ),
            // Zaman çizelgesi
            _buildTimeline(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    ));
  }

  // ─── Üst bar ──────────────────────────────────────────────────────
  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        children: [
          // Geri butonu
          GestureDetector(
            onTap: () => Navigator.of(context).maybePop(),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.arrow_back_ios_new_rounded,
                  color: Colors.white.withValues(alpha: 0.8), size: 18),
            ),
          ),
          const SizedBox(width: 16),
          // Başlık
          Text(
            'Wikitrivia',
            style: GoogleFonts.nunito(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const Spacer(),
          // Yanlış hakları — kırmızı yuvarlaklar
          AnimatedBuilder(
            animation: _lifeShakeAnimation,
            builder: (context, child) {
              final shake = _lifeShakeAnimation.value *
                  8 *
                  (1 - _lifeShakeAnimation.value);
              return Transform.translate(
                offset: Offset(shake, 0),
                child: child,
              );
            },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(_game.maxWrongs, (i) {
                final isLost = i < _game.wrongCount;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isLost
                          ? const Color(0xFFFF4757)
                          : const Color(0xFFFF4757).withValues(alpha: 0.15),
                      border: Border.all(
                        color: const Color(0xFFFF4757),
                        width: 2,
                      ),
                      boxShadow: isLost
                          ? [
                              BoxShadow(
                                color: const Color(0xFFFF4757)
                                    .withValues(alpha: 0.4),
                                blurRadius: 8,
                                spreadRadius: 1,
                              )
                            ]
                          : [],
                    ),
                    child: isLost
                        ? const Icon(Icons.close_rounded,
                            color: Colors.white, size: 14)
                        : null,
                  ),
                );
              }),
            ),
          ),
          const SizedBox(width: 12),
          // Skor
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle_rounded,
                    color: Color(0xFF6BCB77), size: 18),
                const SizedBox(width: 5),
                Text(
                  '${_game.score}',
                  style: GoogleFonts.nunito(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Sürüklenebilir üst kart ─────────────────────────────────────
  Widget _buildDraggableCurrentCard() {
    if (_game.currentCard == null || _flashController.isAnimating) {
      return const SizedBox(height: 120);
    }

    final card = _game.currentCard!;

    return FadeTransition(
      opacity: _cardEntryAnimation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, -0.3),
          end: Offset.zero,
        ).animate(_cardEntryAnimation),
        child: Draggable<int>(
          data: -1,
          feedback: Material(
            color: Colors.transparent,
            child: Transform.scale(
              scale: 0.92,
              child: _EventCard(
                event: card,
                showYear: false,
                isCurrentCard: true,
                isDragging: true,
              ),
            ),
          ),
          childWhenDragging: Opacity(
            opacity: 0.2,
            child: _EventCard(
              event: card,
              showYear: false,
              isCurrentCard: true,
            ),
          ),
          onDragStarted: () => setState(() => _activeDropSlot = null),
          onDragEnd: (_) => setState(() => _activeDropSlot = null),
          child: _EventCard(
            event: card,
            showYear: false,
            isCurrentCard: true,
          ),
        ),
      ),
    );
  }

  // ─── Zaman çizelgesi ─────────────────────────────────────────────
  Widget _buildTimeline() {
    final totalItems = _game.timeline.length * 2 + 1;
    final canDrop = _game.currentCard != null && !_flashController.isAnimating;

    return SizedBox(
      height: 250,
      child: ListView.builder(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: totalItems,
        itemBuilder: (context, index) {
          if (index.isEven) {
            final slotIndex = index ~/ 2;
            return _buildDropSlot(slotIndex, canDrop);
          } else {
            final cardIndex = index ~/ 2;
            return _buildTimelineCard(cardIndex);
          }
        },
      ),
    );
  }

  // ─── Drop slot (artı işareti yok, sadece görünmez bırakma alanı) ──
  Widget _buildDropSlot(int slotIndex, bool canDrop) {
    final isActive = _activeDropSlot == slotIndex;

    return DragTarget<int>(
      onWillAcceptWithDetails: (_) {
        if (!canDrop) return false;
        setState(() => _activeDropSlot = slotIndex);
        return true;
      },
      onLeave: (_) {
        setState(() {
          if (_activeDropSlot == slotIndex) _activeDropSlot = null;
        });
      },
      onAcceptWithDetails: (_) {
        _placeCard(slotIndex);
      },
      builder: (context, candidateData, rejectedData) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: isActive ? 80 : (canDrop ? 20 : 4),
          margin: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: isActive
                ? const Color(0xFF6C5CE7).withValues(alpha: 0.15)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: isActive
                ? Border.all(
                    color: const Color(0xFF6C5CE7).withValues(alpha: 0.5),
                    width: 2.5,
                  )
                : null,
          ),
          child: isActive
              ? Center(
                  child: Icon(
                    Icons.arrow_downward_rounded,
                    color: const Color(0xFF6C5CE7).withValues(alpha: 0.7),
                    size: 22,
                  ),
                )
              : null,
        );
      },
    );
  }

  // ─── Timeline'daki kart ───────────────────────────────────────────
  Widget _buildTimelineCard(int cardIndex) {
    final event = _game.timeline[cardIndex];
    final isFlashing = _flashingIndex == cardIndex && _lastResult != null;

    Color? highlightColor;

    if (isFlashing) {
      highlightColor = _lastResult == PlacementResult.correct
          ? const Color(0xFF6BCB77)
          : const Color(0xFFFF4757);
    }

    return AnimatedBuilder(
      animation: _flashAnimation,
      builder: (context, child) {
        final highlightOpacity =
            isFlashing ? (1.0 - _flashAnimation.value) : 0.0;

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: _EventCard(
            event: event,
            showYear: true,
            highlightColor: isFlashing ? highlightColor : null,
            highlightOpacity: highlightOpacity,
          ),
        );
      },
    );
  }

  Color getYearColor(int year) {
    if (year < 1500) return const Color(0xFFE17055);
    if (year < 1800) return const Color(0xFFFDAA5E);
    if (year < 1950) return const Color(0xFF6BCB77);
    if (year < 2000) return const Color(0xFF74B9FF);
    return const Color(0xFFA29BFE);
  }
}

// ─── Olay Kartı Widget'ı ────────────────────────────────────────────
class _EventCard extends StatelessWidget {
  final HistoricalEvent event;
  final bool showYear;
  final bool isCurrentCard;
  final bool isDragging;
  final Color? highlightColor;
  final double highlightOpacity;

  const _EventCard({
    required this.event,
    this.showYear = true,
    this.isCurrentCard = false,
    this.isDragging = false,
    this.highlightColor,
    this.highlightOpacity = 0.0,
  });

  Color _getYearColor(int year) {
    if (year < 1500) return const Color(0xFFE17055);
    if (year < 1800) return const Color(0xFFFDAA5E);
    if (year < 1950) return const Color(0xFF6BCB77);
    if (year < 2000) return const Color(0xFF74B9FF);
    return const Color(0xFFA29BFE);
  }

  @override
  Widget build(BuildContext context) {
    final cardWidth = isCurrentCard ? 180.0 : 150.0;
    final cardHeight = isCurrentCard ? 120.0 : 100.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Kart gövdesi
        Container(
          width: cardWidth,
          height: cardHeight,
          decoration: BoxDecoration(
            color: const Color(0xFFF5F0E8),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: highlightColor?.withValues(alpha: 0.7) ??
                  (isCurrentCard
                      ? Colors.white.withValues(alpha: 0.25)
                      : Colors.black.withValues(alpha: 0.05)),
              width: highlightColor != null ? 3 : 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: isDragging
                    ? Colors.black.withValues(alpha: 0.35)
                    : (highlightColor?.withValues(
                            alpha: highlightOpacity * 0.35) ??
                        Colors.black.withValues(alpha: 0.12)),
                blurRadius: isDragging ? 24 : 10,
                offset: Offset(0, isDragging ? 10 : 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Stack(
              children: [
                // Flash renk overlay
                if (highlightColor != null && highlightOpacity > 0)
                  Positioned.fill(
                    child: Container(
                      color: highlightColor!
                          .withValues(alpha: highlightOpacity * 0.12),
                    ),
                  ),
                // İçerik
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Center(
                    child: Text(
                      event.title,
                      style: GoogleFonts.nunito(
                        fontSize: isCurrentCard ? 15 : 13,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF2D3436),
                        height: 1.25,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                // Doğru/yanlış ikonu
                if (highlightColor != null && highlightOpacity > 0.3)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: highlightColor!.withValues(alpha: 0.3),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                      child: Icon(
                        highlightColor == const Color(0xFF6BCB77)
                            ? Icons.check_circle_rounded
                            : Icons.cancel_rounded,
                        color: highlightColor,
                        size: 20,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        // Yıl etiketi
        if (showYear) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
            decoration: BoxDecoration(
              color: highlightColor?.withValues(alpha: 0.2) ??
                  _getYearColor(event.year).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: highlightColor?.withValues(alpha: 0.3) ??
                    _getYearColor(event.year).withValues(alpha: 0.3),
              ),
            ),
            child: Text(
              '${event.year}',
              style: GoogleFonts.nunito(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: highlightColor ?? _getYearColor(event.year),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
