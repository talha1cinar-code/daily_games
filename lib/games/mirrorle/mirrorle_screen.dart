import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../widgets/game_exit_wrapper.dart';
import '../../widgets/game_result_sheet.dart';
import '../../services/sound_service.dart';
import '../../services/ticket_service.dart';
import '../../services/stats_service.dart';
import '../../services/leaderboard_service.dart';
import '../../services/personal_best_service.dart';
import '../../services/daily_challenge_service.dart';
import '../../services/language_service.dart';
import 'mirrorle_game.dart';

class MirrorleScreen extends StatefulWidget {
  final bool isDailyMode;
  final void Function(double score, [int durationMs])? onGameComplete;
  const MirrorleScreen({super.key, this.isDailyMode = true, this.onGameComplete});

  @override
  State<MirrorleScreen> createState() => _MirrorleScreenState();
}

class _MirrorleScreenState extends State<MirrorleScreen> with SingleTickerProviderStateMixin {
  static const Color _bg = Color(0xFF101722);
  static const Color _axis = Color(0xFFB9F6CA);
  static const List<Color> _palette = [Colors.transparent, Color(0xFF4DD0E1), Color(0xFFFF6FA5)];
  static const int n = MirrorleGame.n;

  late final MirrorleGame _game;
  final SoundService _sound = SoundService();
  final Stopwatch _stopwatch = Stopwatch()..start();

  int _round = 0;
  Map<int, int> _answer = {};
  final List<double> _roundScores = [];
  bool _revealing = false;

  // Desenin görünür kaldığı süre (bitince kaynak yarı söner)
  late final AnimationController _view;

  bool get _tr => LanguageService().isTurkish;
  MirrorRound get _current => _game.rounds[_round];
  double get _total => _roundScores.fold(0.0, (a, b) => a + b);
  bool get _sourceHidden => _view.isCompleted && !_revealing;

  @override
  void initState() {
    super.initState();
    final rng = widget.isDailyMode
        ? Random(DailyChallengeService.getSeededMirrorleSeed())
        : Random();
    _game = MirrorleGame(rng);
    _view = AnimationController(vsync: this)
      ..addStatusListener((s) {
        if (s == AnimationStatus.completed && mounted) setState(() {});
      });
    _startView();
  }

  @override
  void dispose() {
    _view.dispose();
    super.dispose();
  }

  void _startView() {
    _view.duration = Duration(milliseconds: MirrorleGame.viewMs[_round]);
    _view.forward(from: 0);
  }

  void _onCellTap(int i) {
    if (_revealing || !MirrorleGame.isTarget(_current.type, i)) return;
    _sound.playKeyTap();
    setState(() {
      final next = ((_answer[i] ?? 0) + 1) % (_current.colorCount + 1);
      next == 0 ? _answer.remove(i) : _answer[i] = next;
    });
  }

  void _check() {
    if (_revealing) return;
    _view.stop();
    final score = MirrorleGame.roundScore(_current, _answer);
    score >= MirrorleGame.maxRoundScore
        ? _sound.playCorrect()
        : (score > 0 ? _sound.playFlip() : _sound.playError());
    setState(() {
      _revealing = true;
      _roundScores.add(score);
    });
    Future.delayed(const Duration(milliseconds: 1800), () {
      if (!mounted) return;
      if (_round + 1 >= MirrorleGame.totalRounds) {
        _finish();
        return;
      }
      setState(() {
        _round++;
        _answer = {};
        _revealing = false;
      });
      _startView();
    });
  }

  void _finish() {
    _stopwatch.stop();
    final durationMs = _stopwatch.elapsedMilliseconds;
    final score = _total;
    _saveScore(score, durationMs);
    final flawless = _roundScores.where((s) => s >= MirrorleGame.maxRoundScore).length;
    final secs = (durationMs / 1000).round();
    GameResultSheet.show(
      context,
      GameResultSheet(
        title: flawless == MirrorleGame.totalRounds
            ? (_tr ? 'Kusursuz simetri!' : 'Perfect symmetry!')
            : (_tr ? 'Ayna kapandı' : 'Mirror closed'),
        headline: score.toStringAsFixed(0),
        caption: _tr ? 'Puan (100 üzerinden)' : 'Score (out of 100)',
        accent: _palette[1],
        isDailyRun: widget.onGameComplete != null,
        stats: [
          GameResultStat(_tr ? 'Kusursuz tur' : 'Perfect rounds', '$flawless/${MirrorleGame.totalRounds}'),
          GameResultStat(_tr ? 'Süre' : 'Time', '${secs ~/ 60}:${(secs % 60).toString().padLeft(2, '0')}'),
        ],
      ),
    );
  }

  void _saveScore(double score, int durationMs) {
    if (widget.onGameComplete != null) {
      widget.onGameComplete!(score, durationMs);
    } else if (widget.isDailyMode) {
      TicketService().markDailyPlayed('mirrorle');
      StatsService().saveDailyStat(
        gameId: 'mirrorle',
        isWin: score > 0,
        score: score,
        attempts: MirrorleGame.totalRounds,
        maxAttempts: MirrorleGame.totalRounds,
        durationMs: durationMs,
      );
      LeaderboardService().submitScore(
        gameId: 'mirrorle',
        score: score,
        attempts: MirrorleGame.totalRounds,
        maxAttempts: MirrorleGame.totalRounds,
        durationMs: durationMs,
        isWin: score > 0,
      );
    } else {
      PersonalBestService().submit('mirrorle', score);
    }
  }

  (String, String) _roundText() {
    switch (_current.type) {
      case MirrorType.vertical:
        return (_tr ? 'Dikey ayna' : 'Vertical mirror',
            _tr ? 'Sol yarının aynadaki yansımasını sağa çiz' : 'Draw the left half\'s reflection on the right');
      case MirrorType.horizontal:
        return (_tr ? 'Yatay ayna' : 'Horizontal mirror',
            _tr ? 'Üst yarıyı aşağıya yansıt' : 'Reflect the top half downwards');
      case MirrorType.rotate:
        return (_tr ? '180° döndür' : 'Rotate 180°',
            _tr ? 'Sol yarıyı merkez etrafında ters çevirip sağa koy' : 'Spin the left half around the centre onto the right');
      case MirrorType.diagonal:
        return (_tr ? 'Çapraz ayna' : 'Diagonal mirror',
            _tr ? 'Alt üçgeni köşegen boyunca yansıt' : 'Reflect the lower triangle across the diagonal');
    }
  }

  @override
  Widget build(BuildContext context) {
    final (title, subtitle) = _roundText();
    return GameExitWrapper(
      gameId: 'mirrorle',
      isDailyMode: widget.isDailyMode,
      onGameComplete: widget.onGameComplete,
      child: Scaffold(
        backgroundColor: _bg,
        body: SafeArea(
          child: Column(
            children: [
              _buildTopBar(),
              _buildRoundDots(),
              const SizedBox(height: 16),
              Text(title, style: GoogleFonts.nunito(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white)),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.nunito(fontSize: 14, color: Colors.white60),
                ),
              ),
              const SizedBox(height: 14),
              _buildViewTimer(),
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: AspectRatio(aspectRatio: 1, child: _buildBoard()),
                  ),
                ),
              ),
              _buildBottom(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBoard() {
    final expected = _revealing ? MirrorleGame.expected(_current) : const <int, int>{};
    return Stack(
      children: [
        GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: n,
            mainAxisSpacing: 6,
            crossAxisSpacing: 6,
          ),
          itemCount: n * n,
          itemBuilder: (context, i) {
            final isSource = MirrorleGame.isSource(_current.type, i);
            final isTarget = MirrorleGame.isTarget(_current.type, i);
            int value = 0;
            if (isSource) value = _current.source[i] ?? 0;
            if (isTarget) value = _answer[i] ?? 0;
            final faded = isSource && _sourceHidden;

            Color? ring;
            if (_revealing && isTarget) {
              final want = expected[i] ?? 0;
              if (want != value) {
                ring = Colors.redAccent;
              } else if (want != 0) {
                ring = Colors.greenAccent;
              }
            }

            final base = isTarget
                ? Colors.white.withValues(alpha: 0.08)
                : isSource
                    ? Colors.white.withValues(alpha: 0.03)
                    : Colors.transparent;

            return GestureDetector(
              onTap: () => _onCellTap(i),
              child: AnimatedContainer(
                duration: Duration(milliseconds: faded ? 450 : 150),
                decoration: BoxDecoration(
                  color: value == 0 || faded ? base : _palette[value],
                  borderRadius: BorderRadius.circular(8),
                  border: ring != null ? Border.all(color: ring, width: 3) : null,
                ),
                // Yanlışta, olması gereken rengi küçük bir nokta olarak göster
                child: _revealing && isTarget && ring == Colors.redAccent && (expected[i] ?? 0) != 0
                    ? Center(
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(color: _palette[expected[i]!], shape: BoxShape.circle),
                        ),
                      )
                    : null,
              ),
            );
          },
        ),
        Positioned.fill(
          child: IgnorePointer(child: CustomPaint(painter: _AxisPainter(_current.type, _axis))),
        ),
      ],
    );
  }

  Widget _buildBottom() {
    final canCheck = !_revealing;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Column(
        children: [
          SizedBox(
            height: 22,
            child: Text(
              _revealing
                  ? '+${_roundScores.last.toStringAsFixed(0)} ${_tr ? 'puan' : 'pts'}'
                  : (_current.colorCount > 1 ? (_tr ? 'Rengi değiştirmek için tekrar dokun' : 'Tap again to change colour') : ''),
              style: GoogleFonts.nunito(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: _revealing ? _axis : Colors.white54,
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: canCheck ? _check : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: _palette[1],
                foregroundColor: _bg,
                disabledBackgroundColor: Colors.white12,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              child: Text(_tr ? 'Kontrol et' : 'Check',
                  style: GoogleFonts.nunito(fontSize: 17, fontWeight: FontWeight.w800)),
            ),
          ),
        ],
      ),
    );
  }

  /// Desen sönene kadar kalan süre
  Widget _buildViewTimer() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: AnimatedBuilder(
        animation: _view,
        builder: (context, _) {
          final left = 1 - _view.value;
          final gone = _sourceHidden;
          final secs = (left * MirrorleGame.viewMs[_round] / 1000).ceil();
          return Column(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: _revealing ? 0 : left,
                  minHeight: 6,
                  backgroundColor: Colors.white10,
                  valueColor: AlwaysStoppedAnimation(left < 0.3 ? const Color(0xFFFF6FA5) : _axis),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _revealing
                    ? ''
                    : gone
                        ? (_tr ? 'Desen kayboldu, hafızandan devam et' : 'It\'s gone, finish from memory')
                        : (_tr ? 'Desen $secs sn sonra kayboluyor' : 'Pattern fades in ${secs}s'),
                style: GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white54),
              ),
            ],
          );
        },
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
              Text('Mirrorle',
                  style: GoogleFonts.nunito(fontSize: 24, fontWeight: FontWeight.w800, color: Colors.white)),
              Text(_tr ? 'Simetriyi tamamla' : 'Complete the symmetry',
                  style: GoogleFonts.nunito(fontSize: 12, color: Colors.white54)),
            ],
          ),
          const Spacer(),
          Text(
            _total.toStringAsFixed(0),
            style: GoogleFonts.nunito(fontSize: 22, fontWeight: FontWeight.w900, color: _palette[1]),
          ),
        ],
      ),
    );
  }

  Widget _buildRoundDots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(MirrorleGame.totalRounds, (i) {
        final done = i < _roundScores.length;
        final current = i == _round;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: current ? 28 : 10,
          height: 10,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: done ? _palette[1] : (current ? Colors.white : Colors.white24),
            borderRadius: BorderRadius.circular(5),
          ),
        );
      }),
    );
  }
}

class _AxisPainter extends CustomPainter {
  final MirrorType type;
  final Color color;
  _AxisPainter(this.type, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.8)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    final c = size.center(Offset.zero);
    switch (type) {
      case MirrorType.horizontal:
        canvas.drawLine(Offset(0, c.dy), Offset(size.width, c.dy), paint);
        break;
      case MirrorType.diagonal:
        canvas.drawLine(Offset.zero, Offset(size.width, size.height), paint);
        break;
      case MirrorType.rotate:
        canvas.drawLine(Offset(c.dx, 0), Offset(c.dx, size.height), paint..color = color.withValues(alpha: 0.35));
        canvas.drawCircle(c, 9, Paint()..color = color);
        canvas.drawCircle(c, 4, Paint()..color = const Color(0xFF101722));
        break;
      default:
        canvas.drawLine(Offset(c.dx, 0), Offset(c.dx, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _AxisPainter old) => old.type != type;
}
