import 'dart:math';
import 'package:flutter/material.dart';
import '../../widgets/game_exit_wrapper.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/sound_service.dart';
import '../../services/ticket_service.dart';
import '../../services/stats_service.dart';
import '../../services/leaderboard_service.dart';
import '../../theme/app_theme.dart';
import 'circle_painter.dart';

class PointData {
  final Offset point;
  final DateTime time;
  PointData(this.point, this.time);
}

class CircleScreen extends StatefulWidget {
  final bool isDailyMode;
  final void Function(double score, [int durationMs])? onGameComplete;
  
  const CircleScreen({
    super.key, 
    this.isDailyMode = false,
    this.onGameComplete,
  });

  @override
  State<CircleScreen> createState() => _CircleScreenState();
}

class _CircleScreenState extends State<CircleScreen> with TickerProviderStateMixin {
  final List<PointData> _points = [];
  bool _isDrawing = false;
  bool _isFailed = false;
  bool _isGameOver = false;
  String? _statusText;
  double? _accuracy;
  
  DateTime? _gameStartTime;
  int _attempts = 0;

  final SoundService _sound = SoundService();
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _gameStartTime = DateTime.now();

    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _shakeAnimation = CurvedAnimation(
      parent: _shakeController,
      curve: Curves.elasticIn,
    );
    _shakeController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _shakeController.reset();
      }
    });
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  Offset _centerPoint = const Offset(200, 200);

  void _onPanStart(DragStartDetails details) {
    if (_isGameOver) return;
    
    if (widget.isDailyMode && TicketService().isDailyPlayed('circle')) {
      return;
    }

    setState(() {
      _points.clear();
      _isDrawing = true;
      _isFailed = false;
      _statusText = null;
      _accuracy = null;
      _points.add(PointData(details.localPosition, DateTime.now()));
    });
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (!_isDrawing || _isGameOver || _isFailed) return;

    final now = DateTime.now();
    final newPoint = details.localPosition;
    
    if (_points.isNotEmpty) {
      final lastPoint = _points.last;
      final timeDelta = now.difference(lastPoint.time).inMilliseconds;
      
      if (timeDelta > 200) {
        _failDrawing("Çok Yavaş!");
        return;
      }
      
      final distance = (newPoint - lastPoint.point).distance;
      if (distance > 2.0) {
        setState(() {
          _points.add(PointData(newPoint, now));
          _accuracy = _calculateCurrentAccuracy(center: _centerPoint);
        });
      }
    }
  }

  void _onPanEnd(DragEndDetails details) {
    if (!_isDrawing || _isGameOver || _isFailed) return;

    setState(() {
      _isDrawing = false;
    });

    _evaluateCircle();
  }

  void _failDrawing(String message) {
    _sound.playError();
    _shakeController.forward();
    setState(() {
      _isDrawing = false;
      _isFailed = true;
      _statusText = message;
      _accuracy = null;
    });
    
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted && !_isGameOver) {
        setState(() {
          _points.clear();
          _isFailed = false;
          _statusText = null;
        });
      }
    });
  }

  double _calculateCurrentAccuracy({required Offset center}) {
    if (_points.length < 5) return 100.0;
    
    double sumRadii = 0;
    final List<double> radii = [];
    for (var p in _points) {
      final r = (p.point - center).distance;
      radii.add(r);
      sumRadii += r;
    }
    final avgRadius = sumRadii / _points.length;
    if (avgRadius == 0) return 0.0;

    double errorSum = 0;
    for (var r in radii) {
      errorSum += (r - avgRadius).abs();
    }
    final meanError = errorSum / _points.length;
    double errorPercentage = (meanError / avgRadius) * 100;
    
    // Daha affedici bir hesaplama (çarpanı 3.5 yerine 2.0 yapalım)
    double calculatedAccuracy = 100.0 - (errorPercentage * 2.0);
    if (calculatedAccuracy < 0) calculatedAccuracy = 0;
    if (calculatedAccuracy > 100) calculatedAccuracy = 100;
    
    return calculatedAccuracy;
  }

  void _evaluateCircle() {
    if (_points.length < 20) {
      _failDrawing("Çok Kısa!");
      return;
    }

    final center = _centerPoint;

    // İlk nokta ile son nokta arasındaki mesafe kapalı mı?
    final startPoint = _points.first.point;
    final endPoint = _points.last.point;
    final distanceStartEnd = (startPoint - endPoint).distance;
    
    // Çemberin ortalama yarıçapını hesapla
    double sumRadii = 0;
    final List<double> radii = [];
    for (var p in _points) {
      final r = (p.point - center).distance;
      radii.add(r);
      sumRadii += r;
    }
    final avgRadius = sumRadii / _points.length;

    // Çok küçük çizimlere izin verme
    if (avgRadius < 30) {
      _failDrawing("Çok Küçük!");
      return;
    }

    // Çemberi kapatma toleransını artır (yarıçapın %80'ine kadar kabul et, çok katıydı)
    if (distanceStartEnd > avgRadius * 0.8) {
      _failDrawing("Çemberi Kapat!");
      return;
    }

    // Doğruluk hesaplama (Yeniden daha affedici mantıkla)
    double calculatedAccuracy = _calculateCurrentAccuracy(center: center);

    if (calculatedAccuracy < 20) {
      _failDrawing("Çok Bozuk!");
      return;
    }

    // BAŞARILI ÇİZİM
    _sound.playWin();
    _attempts++;
    
    setState(() {
      _accuracy = calculatedAccuracy;
      _statusText = "%${calculatedAccuracy.toStringAsFixed(1)} Mükemmel!";
      _isGameOver = true;
    });

    _saveScore();
    
    Future.delayed(const Duration(milliseconds: 1500), _showGameOverDialog);
  }

  void _saveScore() {
    final durationMs = DateTime.now().difference(_gameStartTime!).inMilliseconds;
    final score = _accuracy ?? 0.0;

    if (widget.isDailyMode) {
      TicketService().markDailyPlayed('circle');
      StatsService().saveDailyStat(
        gameId: 'circle',
        isWin: true,
        score: score,
        attempts: _attempts,
        maxAttempts: 1,
        durationMs: durationMs,
      );
      LeaderboardService().submitScore(
        gameId: 'circle',
        score: LeaderboardService.calculateLeaderboardScore(
          gameId: 'circle',
          isWin: true,
          score: score,
          durationMs: durationMs,
        ),
        attempts: _attempts,
        maxAttempts: 1,
        durationMs: durationMs,
        isWin: true,
      );
    } else {
      TicketService().useTicket('circle');
    }
  }

  void _showGameOverDialog() {
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      enableDrag: false,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.star_rounded, size: 64, color: Colors.amber),
            const SizedBox(height: 16),
            Text(
              'Oyun Bitti!',
              style: GoogleFonts.outfit(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Doğruluk: %${_accuracy?.toStringAsFixed(1) ?? '0.0'}',
              style: GoogleFonts.outfit(
                fontSize: 20,
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context); // Dialogu kapat
                  Navigator.pop(context); // Ekrani kapat
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Theme.of(context).primaryColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  'Kapat',
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GameExitWrapper(
      gameId: 'circle', isDailyMode: widget.isDailyMode, onGameComplete: widget.onGameComplete,
      child: Scaffold(
        backgroundColor: const Color(0xFF1E272E),
        body: SafeArea(
          child: Column(
            children: [
              // Üst Bar
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    Expanded(
                      child: Text(
                        'Circle',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.outfit(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 48), // Denge için
                  ],
                ),
              ),
              
              // Durum Yazısı (Sadece yüzde veya hata)
              SizedBox(
                height: 60,
                child: Center(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: _isFailed
                        ? AnimatedBuilder(
                            key: ValueKey(_statusText),
                            animation: _shakeAnimation,
                            builder: (context, child) {
                              final offset = sin(_shakeAnimation.value * pi * 4) * 8;
                              return Transform.translate(
                                offset: Offset(offset, 0),
                                child: Text(
                                  _statusText!,
                                  style: GoogleFonts.outfit(
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.redAccent,
                                  ),
                                ),
                              );
                            },
                          )
                        : Text(
                            _accuracy != null ? "%${_accuracy!.toStringAsFixed(1)}" : "",
                            key: ValueKey(_accuracy),
                            style: GoogleFonts.outfit(
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                              color: (_accuracy ?? 0) >= 90 
                                  ? Colors.green 
                                  : ((_accuracy ?? 0) >= 70 ? Colors.orange : AppColors.primary),
                            ),
                          ),
                  ),
                ),
              ),

              // Çizim Alanı
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    _centerPoint = Offset(constraints.maxWidth / 2, (constraints.maxHeight / 2) - 50);
                    
                    return GestureDetector(
                      onPanStart: _onPanStart,
                      onPanUpdate: _onPanUpdate,
                      onPanEnd: _onPanEnd,
                      child: Container(
                        width: constraints.maxWidth,
                        height: constraints.maxHeight,
                        color: Colors.transparent, // Dokunmaları algılaması için
                        child: CustomPaint(
                          painter: CirclePainter(
                            points: _points.map((p) => p.point).toList(),
                            centerPoint: _centerPoint,
                            isFailed: _isFailed,
                            accuracy: _accuracy,
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
      ),
    );
  }
}
