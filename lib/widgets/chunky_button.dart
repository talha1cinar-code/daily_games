import 'package:flutter/material.dart';
import '../services/sound_service.dart';

/// Oyun tarzı tok (3D) buton: yüz ve altında koyu bir "dudak"; basınca yüz aşağı iner.
/// [onTap] null ise soluk ve pasif görünür.
class ChunkyButton extends StatefulWidget {
  final Color face;
  final Color lip;
  final double height;
  final double radius;
  final Widget child;
  final VoidCallback? onTap;

  const ChunkyButton({
    super.key,
    required this.face,
    required this.lip,
    required this.height,
    required this.child,
    required this.onTap,
    this.radius = 22,
  });

  @override
  State<ChunkyButton> createState() => _ChunkyButtonState();
}

class _ChunkyButtonState extends State<ChunkyButton> {
  static const double _depth = 7;
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(widget.radius);
    return GestureDetector(
      onTapDown: widget.onTap == null ? null : (_) => setState(() => _down = true),
      onTapUp: widget.onTap == null ? null : (_) => setState(() => _down = false),
      onTapCancel: () => setState(() => _down = false),
      onTap: widget.onTap == null
          ? null
          : () {
              SoundService().playKeyTap();
              widget.onTap!();
            },
      child: Opacity(
        opacity: widget.onTap == null ? 0.45 : 1,
        child: SizedBox(
          height: widget.height + _depth,
          child: Stack(
            children: [
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: widget.height,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: widget.lip,
                    borderRadius: r,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.35),
                        blurRadius: 14,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                ),
              ),
              AnimatedPositioned(
                duration: const Duration(milliseconds: 70),
                left: 0,
                right: 0,
                top: _down ? _depth : 0,
                height: widget.height,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: r,
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color.lerp(widget.face, Colors.white, 0.18)!, widget.face],
                    ),
                  ),
                  child: Stack(
                    children: [
                      // Üstte parlak şerit: oyun butonlarındaki "jöle" görünümü
                      Positioned(
                        left: 10,
                        right: 10,
                        top: 5,
                        height: widget.height * 0.32,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(widget.radius - 6),
                          ),
                        ),
                      ),
                      Center(child: widget.child),
                    ],
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
