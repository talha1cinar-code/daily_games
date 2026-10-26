import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../widgets/game_exit_wrapper.dart';
import '../../widgets/game_result_sheet.dart';
import '../../widgets/chunky_button.dart';
import '../../services/sound_service.dart';
import '../../services/daily_challenge_service.dart';
import '../../services/language_service.dart';
import '../common/game_common.dart';
import 'echole_game.dart';

class EcholeScreen extends StatefulWidget {
  final bool isDailyMode;
  final void Function(double score, [int durationMs])? onGameComplete;
  const EcholeScreen({super.key, this.isDailyMode = true, this.onGameComplete});

  @override
  State<EcholeScreen> createState() => _EcholeScreenState();
}

enum _Phase { ready, playing, input, over }

class _EcholeScreenState extends State<EcholeScreen> {
  static const Color _bg = Color(0xFF151226);
  static const Color _accent = Color(0xFF7CF5C4);
  static const List<Color> _colors = [Color(0xFFFF5D73), Color(0xFF4F8BFF), Color(0xFFFFC94D), Color(0xFF3DDC84)];

  late final EcholeGame _game;
  final SoundService _sound = SoundService();
  final Stopwatch _stopwatch = Stopwatch()..start();

  _Phase _phase = _Phase.ready;
  int _length = EcholeGame.startLength;
  int _inputIndex = 0;
  int _completed = 0;
  int _lives = EcholeGame.lives;
  int? _lit;
  bool _wrongFlash = false;

  bool get _tr => LanguageService().isTurkish;

  @override
  void initState() {
    super.initState();
    _game = EcholeGame(widget.isDailyMode ? Random(DailyChallengeService.getSeededSeed('echole')) : Random());
  }

  Future<void> _flash(int pad, int ms) async {
    _sound.playPad(pad);
    setState(() => _lit = pad);
    await Future.delayed(Duration(milliseconds: (ms * 0.6).round()));
    if (!mounted) return;
    setState(() => _lit = null);
    await Future.delayed(Duration(milliseconds: (ms * 0.4).round()));
  }

  Future<void> _playSequence() async {
    setState(() {
      _phase = _Phase.playing;
      _inputIndex = 0;
    });
    await Future.delayed(const Duration(milliseconds: 500));
    final ms = EcholeGame.stepMs(_length);
    for (var i = 0; i < _length; i++) {
      if (!mounted) return;
      await _flash(_game.sequence[i], ms);
    }
    if (!mounted) return;
    setState(() => _phase = _Phase.input);
  }

  Future<void> _tap(int pad) async {
    if (_phase != _Phase.input) return;
    if (pad != _game.sequence[_inputIndex]) {
      _sound.playError();
      setState(() {
        _lives--;
        _wrongFlash = true;
        _phase = _Phase.playing;
      });
      await Future.delayed(const Duration(milliseconds: 450));
      if (!mounted) return;
      setState(() => _wrongFlash = false);
      if (_lives <= 0) {
        _gameOver();
      } else {
        // Yedek hakla aynı diziyi bir kez daha dinle
        _playSequence();
      }
      return;
    }
    _sound.playPad(pad);
    setState(() {
      _lit = pad;
      _inputIndex++;
    });
    Future.delayed(const Duration(milliseconds: 180), () {
      if (mounted && _lit == pad) setState(() => _lit = null);
    });
    if (_inputIndex >= _length) {
      // Sonraki dizi başlayana kadar dokunuşlar sayılmasın
      setState(() {
        _completed = _length;
        _phase = _Phase.playing;
      });
      if (_length >= EcholeGame.maxLength) {
        _gameOver();
        return;
      }
      await Future.delayed(const Duration(milliseconds: 350));
      if (!mounted) return;
      _sound.playCorrect();
      setState(() => _length++);
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) _playSequence();
    }
  }

  void _gameOver() {
    _stopwatch.stop();
    setState(() => _phase = _Phase.over);
    final score = EcholeGame.score(_completed);
    reportGameScore(
      gameId: 'echole',
      isDailyMode: widget.isDailyMode,
      onGameComplete: widget.onGameComplete,
      score: score,
      durationMs: _stopwatch.elapsedMilliseconds,
      attempts: _completed,
      maxAttempts: EcholeGame.maxLength,
    );
    Future.delayed(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      GameResultSheet.show(
        context,
        GameResultSheet(
          title: _completed >= 10 ? (_tr ? 'Fil hafızası!' : 'Elephant memory!') : (_tr ? 'Yankı sustu' : 'The echo fades'),
          headline: score.toStringAsFixed(0),
          caption: _tr ? 'Puan (100 üzerinden)' : 'Score (out of 100)',
          accent: _accent,
          isDailyRun: widget.onGameComplete != null,
          stats: [
            GameResultStat(_tr ? 'En uzun dizi' : 'Longest', '$_completed'),
            GameResultStat(_tr ? 'Süre' : 'Time', '${(_stopwatch.elapsedMilliseconds / 1000).round()} sn'),
          ],
        ),
      );
    });
  }

  String get _status {
    switch (_phase) {
      case _Phase.ready:
        return _tr ? 'Diziyi izle ve aynı sırayla tekrar et' : 'Watch the sequence, then repeat it';
      case _Phase.playing:
        return _tr ? 'İzle...' : 'Watch...';
      case _Phase.input:
        return _tr ? 'Sıra sende: ${_inputIndex + 1}/$_length' : 'Your turn: ${_inputIndex + 1}/$_length';
      case _Phase.over:
        return _tr ? 'Bitti!' : 'Game over!';
    }
  }

  @override
  Widget build(BuildContext context) {
    return GameExitWrapper(
      gameId: 'echole',
      isDailyMode: widget.isDailyMode,
      onGameComplete: widget.onGameComplete,
      child: Scaffold(
        backgroundColor: _bg,
        body: SafeArea(
          child: Column(
            children: [
              GameTopBar(
                title: 'Echole',
                subtitle: _tr ? 'Diziyi tekrar et' : 'Repeat the sequence',
                trailing: '$_completed',
                accent: _accent,
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < EcholeGame.lives; i++)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: Icon(Icons.favorite_rounded,
                          size: 20, color: i < _lives ? const Color(0xFFFF5D73) : Colors.white12),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(_status, style: GoogleFonts.nunito(fontSize: 17, fontWeight: FontWeight.w900, color: Colors.white)),
              Text(
                '${_tr ? 'Dizi uzunluğu' : 'Length'}: $_length',
                style: GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white38),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(child: AspectRatio(aspectRatio: 1, child: _buildPads())),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: ChunkyButton(
                  face: _accent,
                  lip: const Color(0xFF2FA07A),
                  height: 56,
                  onTap: _phase == _Phase.ready ? _playSequence : null,
                  child: Text(_tr ? 'BAŞLA' : 'START',
                      style: GoogleFonts.nunito(fontSize: 20, fontWeight: FontWeight.w900, color: _bg)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPads() {
    Widget pad(int i) {
      final lit = _lit == i;
      final color = _colors[i];
      return Expanded(
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: GestureDetector(
            onTapDown: (_) => _tap(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 90),
              decoration: BoxDecoration(
                color: _wrongFlash
                    ? const Color(0xFF3A1520)
                    : lit
                        ? Color.lerp(color, Colors.white, 0.35)
                        : color.withValues(alpha: 0.32),
                borderRadius: BorderRadius.circular(28),
                boxShadow: lit ? [BoxShadow(color: color.withValues(alpha: 0.7), blurRadius: 28)] : null,
              ),
            ),
          ),
        ),
      );
    }

    return Column(
      children: [
        Expanded(child: Row(children: [pad(0), pad(1)])),
        Expanded(child: Row(children: [pad(2), pad(3)])),
      ],
    );
  }
}
