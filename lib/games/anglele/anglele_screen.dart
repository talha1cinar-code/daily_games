import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../widgets/game_exit_wrapper.dart';
import '../../widgets/game_result_sheet.dart';
import '../../widgets/chunky_button.dart';
import '../../services/sound_service.dart';
import '../../services/daily_challenge_service.dart';
import '../../services/language_service.dart';
import '../common/game_common.dart';
import 'anglele_game.dart';

class AngleleScreen extends StatefulWidget {
  final bool isDailyMode;
  final void Function(double score, [int durationMs])? onGameComplete;
  const AngleleScreen({super.key, this.isDailyMode = true, this.onGameComplete});

  @override
  State<AngleleScreen> createState() => _AngleleScreenState();
}

class _AngleleScreenState extends State<AngleleScreen> {
  static const Color _accent = Color(0xFF7CF5C4);
  static const Color _guessColor = Color(0xFFFFC233);
  static const Color _bg = Color(0xFF0F1B2A);

  late final AngleleGame _game;
  final SoundService _sound = SoundService();
  final Stopwatch _stopwatch = Stopwatch()..start();

  int _round = 0;
  int _guess = 90;
  bool _revealed = false;
  final List<double> _scores = [];
  final List<int> _diffs = [];

  bool get _tr => LanguageService().isTurkish;
  AngleRound get _current => _game.rounds[_round];
  double get _total => _scores.fold(0.0, (a, b) => a + b);

  @override
  void initState() {
    super.initState();
    _game = AngleleGame(widget.isDailyMode ? Random(DailyChallengeService.getSeededSeed('anglele')) : Random());
  }

  void _setGuess(int v) {
    final next = v.clamp(1, 359);
    if (next != _guess) {
      if (next % 5 == 0) HapticFeedback.selectionClick();
      setState(() => _guess = next);
    }
  }

  void _submit() {
    final score = AngleleGame.roundScore(_current.angle, _guess);
    score >= 16 ? _sound.playCorrect() : _sound.playFlip();
    setState(() {
      _revealed = true;
      _scores.add(score);
      _diffs.add((_current.angle - _guess).abs());
    });
  }

  void _next() {
    if (_round + 1 >= AngleleGame.totalRounds) {
      _finish();
      return;
    }
    _sound.playKeyTap();
    setState(() {
      _round++;
      _revealed = false;
      _guess = 90;
    });
  }

  void _finish() {
    _stopwatch.stop();
    final score = _total;
    reportGameScore(
      gameId: 'anglele',
      isDailyMode: widget.isDailyMode,
      onGameComplete: widget.onGameComplete,
      score: score,
      durationMs: _stopwatch.elapsedMilliseconds,
      attempts: AngleleGame.totalRounds,
      maxAttempts: AngleleGame.totalRounds,
    );
    final avg = _diffs.reduce((a, b) => a + b) / _diffs.length;
    GameResultSheet.show(
      context,
      GameResultSheet(
        title: avg <= 3 ? (_tr ? 'Gönye gibi göz!' : 'Eyes like a protractor!') : (_tr ? 'Açılar tamam' : 'Angles done'),
        headline: score.toStringAsFixed(0),
        caption: _tr ? 'Puan (100 üzerinden)' : 'Score (out of 100)',
        accent: _accent,
        isDailyRun: widget.onGameComplete != null,
        stats: [
          GameResultStat(_tr ? 'Ort. sapma' : 'Avg. miss', '${avg.toStringAsFixed(1)}°'),
          GameResultStat(_tr ? 'En iyi' : 'Best', '${_diffs.reduce(min)}°'),
          GameResultStat(_tr ? 'Tur' : 'Rounds', '${AngleleGame.totalRounds}'),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GameExitWrapper(
      gameId: 'anglele',
      isDailyMode: widget.isDailyMode,
      onGameComplete: widget.onGameComplete,
      child: Scaffold(
        backgroundColor: _bg,
        body: SafeArea(
          child: Column(
            children: [
              GameTopBar(
                title: 'Anglele',
                subtitle: _tr ? 'Boyalı açıyı tahmin et' : 'Guess the shaded angle',
                trailing: _total.toStringAsFixed(0),
                accent: _accent,
              ),
              RoundDots(total: AngleleGame.totalRounds, current: _round, done: _scores.length, accent: _accent),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: CustomPaint(
                    size: Size.infinite,
                    painter: _AnglePainter(
                      round: _current,
                      guess: _revealed ? _guess : null,
                      accent: _accent,
                      guessColor: _guessColor,
                    ),
                  ),
                ),
              ),
              _revealed ? _buildResult() : _buildPicker(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stepButton(String label, int delta) {
    return GestureDetector(
      onTap: () {
        _sound.playKeyTap();
        _setGuess(_guess + delta);
      },
      child: Container(
        width: 52,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12)),
        child: Text(label, style: GoogleFonts.nunito(fontSize: 15, fontWeight: FontWeight.w900, color: Colors.white)),
      ),
    );
  }

  Widget _buildPicker() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        children: [
          Text(
            '$_guess°',
            style: GoogleFonts.nunito(
              fontSize: 54,
              fontWeight: FontWeight.w900,
              color: _guessColor,
              height: 1,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 10,
              activeTrackColor: _guessColor,
              inactiveTrackColor: Colors.white12,
              thumbColor: Colors.white,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 14),
              overlayColor: _guessColor.withValues(alpha: 0.2),
            ),
            child: Slider(
              value: _guess.toDouble(),
              min: 1,
              max: 359,
              onChanged: (v) => _setGuess(v.round()),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _stepButton('−5', -5),
              _stepButton('−1', -1),
              _stepButton('+1', 1),
              _stepButton('+5', 5),
            ],
          ),
          const SizedBox(height: 14),
          ChunkyButton(
            face: const Color(0xFF3DDC84),
            lip: const Color(0xFF1E9E55),
            height: 56,
            onTap: _submit,
            child: Text(_tr ? 'TAHMİN ET' : 'GUESS',
                style: GoogleFonts.nunito(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildResult() {
    final diff = _diffs.last;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('${_current.angle}°',
                  style: GoogleFonts.nunito(fontSize: 40, fontWeight: FontWeight.w900, color: _accent)),
              const SizedBox(width: 16),
              Text('${_tr ? 'Senin' : 'You'}: $_guess°',
                  style: GoogleFonts.nunito(fontSize: 18, fontWeight: FontWeight.w800, color: _guessColor)),
            ],
          ),
          Text(
            diff == 0
                ? (_tr ? 'Tam isabet! +20' : 'Bullseye! +20')
                : '${_tr ? '$diff° fark' : '$diff° off'} · +${_scores.last.toStringAsFixed(0)}',
            style: GoogleFonts.nunito(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white70),
          ),
          const SizedBox(height: 14),
          ChunkyButton(
            face: _accent,
            lip: const Color(0xFF2FA07A),
            height: 56,
            onTap: _next,
            child: Text(
              _round + 1 >= AngleleGame.totalRounds ? (_tr ? 'SONUÇ' : 'RESULT') : (_tr ? 'SONRAKİ' : 'NEXT'),
              style: GoogleFonts.nunito(fontSize: 20, fontWeight: FontWeight.w900, color: const Color(0xFF0F1B2A)),
            ),
          ),
        ],
      ),
    );
  }
}

class _AnglePainter extends CustomPainter {
  final AngleRound round;
  final int? guess;
  final Color accent;
  final Color guessColor;

  _AnglePainter({required this.round, required this.guess, required this.accent, required this.guessColor});

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide * 0.42;
    final base = round.baseRotation;
    // Açı ekranda saat yönünün tersine ölçülür (y aşağı olduğu için eksi)
    Offset dir(double a) => Offset(cos(a), -sin(a));

    canvas.drawCircle(c, r, Paint()..color = Colors.white.withValues(alpha: 0.04));

    void arc(double sweepDeg, double radius, Color color, double stroke) {
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: radius),
        -base,
        -sweepDeg * pi / 180,
        false,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..strokeCap = StrokeCap.round,
      );
    }

    final ray = Paint()
      ..color = Colors.white
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round;

    // Ölçülen taraf her zaman boyalı: iki ışın hem θ'yı hem 360-θ'yı tanımlar,
    // dilim hangisinin sorulduğunu gösterir (özellikle 180°'den büyük açılarda)
    final wedge = Path()
      ..moveTo(c.dx, c.dy)
      ..arcTo(Rect.fromCircle(center: c, radius: r), -base, -round.angle * pi / 180, false)
      ..close();
    canvas.drawPath(wedge, Paint()..color = accent.withValues(alpha: guess == null ? 0.16 : 0.08));

    if (guess == null) {
      arc(round.angle.toDouble(), r * 0.26, accent.withValues(alpha: 0.9), 5);
    } else {
      arc(round.angle.toDouble(), r * 0.32, accent.withValues(alpha: 0.9), 6);
      arc(guess!.toDouble(), r * 0.44, guessColor, 4);
      canvas.drawLine(
        c,
        c + dir(base + guess! * pi / 180) * r,
        Paint()
          ..color = guessColor
          ..strokeWidth = 5
          ..strokeCap = StrokeCap.round,
      );
    }

    canvas.drawLine(c, c + dir(base) * r, ray);
    canvas.drawLine(c, c + dir(base + round.angle * pi / 180) * r, ray);
    canvas.drawCircle(c, 9, Paint()..color = accent);
  }

  @override
  bool shouldRepaint(covariant _AnglePainter old) => old.round != round || old.guess != guess;
}
