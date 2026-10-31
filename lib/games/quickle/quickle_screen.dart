import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../widgets/game_exit_wrapper.dart';
import '../../widgets/game_result_sheet.dart';
import '../../services/app_strings.dart';
import '../../services/sound_service.dart';
import '../../services/ticket_service.dart';
import '../../services/stats_service.dart';
import '../../services/leaderboard_service.dart';
import '../../services/personal_best_service.dart';
import '../../services/daily_challenge_service.dart';
import '../../services/language_service.dart';
import '../../services/coin_service.dart';
import '../../widgets/coin_offer_dialog.dart';
import 'quickle_game.dart';

class QuickleScreen extends StatefulWidget {
  final bool isDailyMode;
  final void Function(double score, [int durationMs])? onGameComplete;
  const QuickleScreen({super.key, this.isDailyMode = true, this.onGameComplete});

  @override
  State<QuickleScreen> createState() => _QuickleScreenState();
}

enum _Phase { ready, playing, done }

class _QuickleScreenState extends State<QuickleScreen> with SingleTickerProviderStateMixin {
  static const Color _accent = Color(0xFF4DD9FF);
  static const Color _bg = Color(0xFF0F1626);

  late final QuickleGame _game;
  final SoundService _sound = SoundService();
  _Phase _phase = _Phase.ready;
  String _input = '';

  Timer? _ticker;
  DateTime? _startedAt;
  DateTime? _endsAt;
  int _remainingMs = QuickleGame.durationMs;

  // Doğru/yanlış geri bildirimi
  Color? _flash;
  String? _timeDelta;
  late final AnimationController _shake;

  bool get _tr => LanguageService().isTurkish;
  bool _extended = false;
  bool _offering = false;

  // Coin ile süre yalnızca bilet modunda; Daily Run sıralamasını etkilemez
  bool get _ticketMode => widget.onGameComplete == null && !widget.isDailyMode;

  @override
  void initState() {
    super.initState();
    final rng = widget.isDailyMode
        ? Random(DailyChallengeService.getSeededQuickleSeed())
        : Random();
    _game = QuickleGame(rng);
    _shake = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _shake.dispose();
    super.dispose();
  }

  void _start() {
    _sound.playKeyTap();
    _startedAt = DateTime.now();
    _endsAt = _startedAt!.add(const Duration(milliseconds: QuickleGame.durationMs));
    setState(() => _phase = _Phase.playing);
    _ticker = Timer.periodic(const Duration(milliseconds: 100), (_) => _tick());
  }

  void _tick() {
    if (!mounted || _phase != _Phase.playing) return;
    if (_offering) return;
    final left = _endsAt!.difference(DateTime.now()).inMilliseconds;
    if (left <= 0) {
      if (_ticketMode && !_extended) {
        _offerTime();
      } else {
        _finish();
      }
    } else {
      setState(() => _remainingMs = left);
    }
  }

  void _onKey(String key) {
    if (_phase != _Phase.playing) return;
    if (key == '⌫') {
      if (_input.isEmpty) return;
      _sound.playDelete();
      setState(() => _input = _input.substring(0, _input.length - 1));
      return;
    }
    if (key == 'C') {
      setState(() => _input = '');
      return;
    }
    if (_input.length >= 4) return;
    _sound.playKeyTap();
    _input += key;

    final target = _game.current.answer.toString();
    if (_input == target) {
      _game.submit(int.parse(_input));
      String? delta;
      if (_game.earnedStreakBonus) {
        _endsAt = _endsAt!.add(const Duration(milliseconds: QuickleGame.streakBonusMs));
        delta = '+${QuickleGame.streakBonusMs ~/ 1000}s';
      }
      _feedback(Colors.greenAccent, delta);
    } else if (_input.length >= target.length) {
      _game.submit(int.parse(_input));
      _endsAt = _endsAt!.subtract(const Duration(milliseconds: QuickleGame.wrongPenaltyMs));
      _sound.playError();
      _shake.forward(from: 0);
      _feedback(Colors.redAccent, '−${QuickleGame.wrongPenaltyMs ~/ 1000}s');
    } else {
      setState(() {});
    }
  }

  void _feedback(Color color, String? delta) {
    setState(() {
      _input = '';
      _flash = color;
      _timeDelta = delta;
    });
    Future.delayed(const Duration(milliseconds: 350), () {
      if (mounted) setState(() => _flash = null);
    });
    if (delta != null) {
      Future.delayed(const Duration(milliseconds: 900), () {
        if (mounted) setState(() => _timeDelta = null);
      });
    }
  }

  Future<void> _offerTime() async {
    _offering = true;
    setState(() => _remainingMs = 0);
    final ok = await showCoinOffer(
      context,
      icon: Icons.timer_rounded,
      title: AppStrings.secondChance,
      description: AppStrings.secondChanceDesc,
      confirmLabel: AppStrings.plusTime,
      price: CoinService.hintPrice,
      item: 'quickle_time',
    );
    if (!mounted) return;
    _offering = false;
    if (!ok) {
      _finish();
      return;
    }
    _extended = true;
    _endsAt = DateTime.now().add(const Duration(seconds: 10));
  }

  void _finish() {
    _ticker?.cancel();
    final durationMs = DateTime.now().difference(_startedAt!).inMilliseconds;
    setState(() {
      _phase = _Phase.done;
      _remainingMs = 0;
    });
    _sound.playGameEnd(_game.score);
    _saveScore(durationMs);

    final total = _game.correct + _game.wrong;
    final accuracy = total == 0 ? 0 : (_game.correct * 100 / total).round();
    GameResultSheet.show(
      context,
      GameResultSheet(
        title: _game.score >= 60
            ? (_tr ? 'Hesap makinesi gibisin!' : 'Human calculator!')
            : (_tr ? 'Süre doldu' : 'Time\'s up'),
        headline: _game.score.toStringAsFixed(0),
        caption: _tr ? 'Puan' : 'Score',
        accent: _accent,
        isDailyRun: widget.onGameComplete != null,
        stats: [
          GameResultStat(_tr ? 'Doğru' : 'Correct', '${_game.correct}'),
          GameResultStat(_tr ? 'İsabet' : 'Accuracy', '%$accuracy'),
          GameResultStat(_tr ? 'En iyi seri' : 'Best streak', '${_game.bestStreak}'),
        ],
      ),
    );
  }

  void _saveScore(int durationMs) {
    final score = _game.score;
    if (widget.onGameComplete != null) {
      widget.onGameComplete!(score, durationMs);
    } else if (widget.isDailyMode) {
      TicketService().markDailyPlayed('quickle');
      StatsService().saveDailyStat(
        gameId: 'quickle',
        isWin: _game.correct > 0,
        score: score,
        attempts: _game.correct + _game.wrong,
        durationMs: durationMs,
      );
      LeaderboardService().submitScore(
        gameId: 'quickle',
        score: score,
        attempts: _game.correct + _game.wrong,
        durationMs: durationMs,
        isWin: _game.correct > 0,
      );
    } else {
      PersonalBestService().submit('quickle', score);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GameExitWrapper(
      gameId: 'quickle',
      isDailyMode: widget.isDailyMode,
      onGameComplete: widget.onGameComplete,
      child: Scaffold(
        backgroundColor: _bg,
        body: SafeArea(
          child: Column(
            children: [
              _buildTopBar(),
              Expanded(child: _phase == _Phase.ready ? _buildReady() : _buildPlaying()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.maybePop(context),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white70, size: 20),
            ),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Quickle',
                  style: GoogleFonts.nunito(fontSize: 24, fontWeight: FontWeight.w800, color: Colors.white)),
              Text(_tr ? 'Hızlı hesap' : 'Mental math',
                  style: GoogleFonts.nunito(fontSize: 12, color: Colors.white54)),
            ],
          ),
          const Spacer(),
          if (_phase != _Phase.ready)
            Text(
              '${_game.score.toStringAsFixed(0)} ${_tr ? 'puan' : 'pts'}',
              style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w800, color: _accent),
            ),
        ],
      ),
    );
  }

  Widget _buildReady() {
    Widget rule(IconData icon, String text) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              Icon(icon, color: _accent, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Text(text, style: GoogleFonts.nunito(fontSize: 15, color: Colors.white70)),
              ),
            ],
          ),
        );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _tr ? '60 saniye. Kaç işlem çözebilirsin?' : '60 seconds. How many can you solve?',
            style: GoogleFonts.nunito(fontSize: 24, fontWeight: FontWeight.w800, color: Colors.white),
          ),
          const SizedBox(height: 20),
          rule(Icons.check_circle_rounded,
              _tr ? 'Doğru cevap otomatik kabul edilir' : 'Correct answers are accepted instantly'),
          rule(Icons.trending_up_rounded,
              _tr ? 'Sorular ilerledikçe zorlaşır ve daha çok puan verir' : 'Questions get harder and worth more as you go'),
          rule(Icons.local_fire_department_rounded,
              _tr ? 'Arka arkaya 5 doğru: +2 saniye' : '5 in a row: +2 seconds'),
          rule(Icons.remove_circle_rounded, _tr ? 'Yanlış cevap: −3 saniye' : 'Wrong answer: −3 seconds'),
          const SizedBox(height: 36),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _start,
              style: ElevatedButton.styleFrom(
                backgroundColor: _accent,
                foregroundColor: _bg,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: Text(AppStrings.start,
                  style: GoogleFonts.nunito(fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 1)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaying() {
    final fraction = (_remainingMs / QuickleGame.durationMs).clamp(0.0, 1.0);
    final low = _remainingMs < 10000;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: fraction,
                    minHeight: 8,
                    backgroundColor: Colors.white.withValues(alpha: 0.08),
                    valueColor: AlwaysStoppedAnimation(low ? Colors.redAccent : _accent),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 44,
                child: Text(
                  '${(_remainingMs / 1000).ceil()}s',
                  textAlign: TextAlign.right,
                  style: GoogleFonts.nunito(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: low ? Colors.redAccent : Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 24,
          child: _timeDelta == null
              ? null
              : Text(
                  _timeDelta!,
                  style: GoogleFonts.nunito(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: _timeDelta!.startsWith('+') ? Colors.greenAccent : Colors.redAccent,
                  ),
                ),
        ),
        Expanded(
          child: AnimatedBuilder(
            animation: _shake,
            builder: (context, child) => Transform.translate(
              offset: Offset(sin(_shake.value * pi * 6) * 10 * (1 - _shake.value), 0),
              child: child,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _game.current.text,
                  style: GoogleFonts.nunito(fontSize: 52, fontWeight: FontWeight.w900, color: Colors.white),
                ),
                const SizedBox(height: 16),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 180,
                  height: 64,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: (_flash ?? Colors.white).withValues(alpha: _flash == null ? 0.06 : 0.25),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _flash ?? Colors.white24, width: 2),
                  ),
                  child: Text(
                    _input.isEmpty ? '?' : _input,
                    style: GoogleFonts.nunito(
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                      color: _input.isEmpty ? Colors.white24 : Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _game.streak >= 2 ? '🔥 ${_game.streak}' : ' ',
                  style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.orangeAccent),
                ),
              ],
            ),
          ),
        ),
        _buildKeypad(),
      ],
    );
  }

  Widget _buildKeypad() {
    const rows = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['C', '0', '⌫'],
    ];
    final enabled = _phase == _Phase.playing;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        children: [
          for (final row in rows)
            Row(
              children: [
                for (final k in row)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(5),
                      child: Material(
                        color: Colors.white.withValues(alpha: k == 'C' || k == '⌫' ? 0.04 : 0.09),
                        borderRadius: BorderRadius.circular(14),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: enabled ? () => _onKey(k) : null,
                          child: SizedBox(
                            height: 58,
                            child: Center(
                              child: k == '⌫'
                                  ? const Icon(Icons.backspace_outlined, color: Colors.white70)
                                  : Text(
                                      k,
                                      style: GoogleFonts.nunito(
                                        fontSize: 26,
                                        fontWeight: FontWeight.w800,
                                        color: k == 'C' ? Colors.white54 : Colors.white,
                                      ),
                                    ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
