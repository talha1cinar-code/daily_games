import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Wordle ve Nerdle'ın ortak tahta ve tuş görünümü.
/// Durumlar: 0 boş, 1 yok, 2 var ama yeri yanlış, 3 doğru yer.
class GuessPalette {
  final Color correct;
  final Color present;
  final Color absent;
  final Color tile;
  final Color tileBorder;
  final Color key;

  const GuessPalette({
    required this.correct,
    required this.present,
    this.absent = const Color(0xFF3A3F55),
    this.tile = const Color(0xFF20263A),
    this.tileBorder = const Color(0xFF353D58),
    this.key = const Color(0xFF4A5170),
  });

  Color forStatus(int s) => switch (s) {
    3 => correct,
    2 => present,
    1 => absent,
    _ => tile,
  };

  /// Basılı kenar rengi (chunky görünüm)
  static Color lipOf(Color c) => Color.lerp(c, Colors.black, 0.35)!;
}

class GuessBoard extends StatelessWidget {
  final int rows;
  final int cols;
  final List<List<String>> guesses;
  final List<List<int>> statuses;
  final List<String> current;
  final bool isOver;
  final GuessPalette palette;
  final Animation<double> reveal;
  final int? revealingRow;
  final Animation<double> shake;
  final int? shakingRow;
  final int? bouncingCell;
  final double maxTile;

  /// Hücrede gösterilecek yazı (ör. "*" yerine "×")
  final String Function(String)? display;

  const GuessBoard({
    super.key,
    required this.rows,
    required this.cols,
    required this.guesses,
    required this.statuses,
    required this.current,
    required this.isOver,
    required this.palette,
    required this.reveal,
    required this.revealingRow,
    required this.shake,
    required this.shakingRow,
    required this.bouncingCell,
    this.maxTile = 62,
    this.display,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        const gap = 6.0;
        final byWidth = (c.maxWidth - gap * (cols - 1)) / cols;
        final byHeight = (c.maxHeight - gap * (rows - 1)) / rows;
        final size = [byWidth, byHeight, maxTile].reduce(min).floorToDouble();
        return Center(
          child: AnimatedBuilder(
            animation: Listenable.merge([reveal, shake]),
            builder: (context, _) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var r = 0; r < rows; r++)
                  Padding(
                    padding: EdgeInsets.only(bottom: r == rows - 1 ? 0 : gap),
                    child: Transform.translate(
                      offset: Offset(shakingRow == r ? sin(shake.value * pi * 5) * 10 * (1 - shake.value) : 0, 0),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (var col = 0; col < cols; col++)
                            Padding(
                              padding: EdgeInsets.only(right: col == cols - 1 ? 0 : gap),
                              child: _tile(r, col, size),
                            ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _tile(int r, int col, double size) {
    var letter = '';
    var status = 0;
    var typed = false;
    final isCurrent = r == guesses.length && !isOver;
    if (r < guesses.length) {
      letter = guesses[r][col];
      status = statuses[r][col];
    } else if (isCurrent && col < current.length) {
      letter = current[col];
      typed = true;
    }

    // Açılış animasyonu: harfler soldan sağa sırayla döner
    var flip = 1.0;
    if (revealingRow == r) {
      final start = col / cols * 0.6;
      flip = ((reveal.value - start) / 0.4).clamp(0.0, 1.0);
    }
    final showColor = flip > 0.5;
    final shown = showColor ? status : 0;
    final angle = flip < 1 ? (flip <= 0.5 ? flip : 1 - flip) * pi : 0.0;

    final filled = shown > 0;
    final bg = palette.forStatus(shown);
    final border = filled
        ? bg
        : (typed || (r < guesses.length) ? Colors.white.withValues(alpha: 0.45) : palette.tileBorder);
    final bounce = isCurrent && bouncingCell == col && typed;

    Widget tile = AnimatedScale(
      scale: bounce ? 1.1 : 1,
      duration: const Duration(milliseconds: 90),
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(size * 0.18),
          border: Border.all(color: border, width: 2),
          boxShadow: filled ? [BoxShadow(color: GuessPalette.lipOf(bg), offset: const Offset(0, 3))] : null,
        ),
        child: Text(
          display?.call(letter) ?? letter,
          style: GoogleFonts.nunito(fontSize: size * 0.5, fontWeight: FontWeight.w900, color: Colors.white, height: 1),
        ),
      ),
    );
    if (angle != 0) {
      tile = Transform(
        alignment: Alignment.center,
        transform: Matrix4.identity()
          ..setEntry(3, 2, 0.001)
          ..rotateX(angle),
        child: tile,
      );
    }
    return tile;
  }
}

/// Chunky tuş: rengi duruma göre değişir, basınca içe göçer
class GuessKey extends StatefulWidget {
  final String? label;
  final IconData? icon;
  final Color color;
  final double width;
  final double height;
  final double fontSize;
  final VoidCallback onTap;

  const GuessKey({
    super.key,
    this.label,
    this.icon,
    required this.color,
    required this.width,
    required this.height,
    required this.fontSize,
    required this.onTap,
  });

  @override
  State<GuessKey> createState() => _GuessKeyState();
}

class _GuessKeyState extends State<GuessKey> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    const lip = 4.0;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _down = true),
      onTapCancel: () => setState(() => _down = false),
      onTapUp: (_) {
        setState(() => _down = false);
        widget.onTap();
      },
      child: SizedBox(
        width: widget.width,
        height: widget.height,
        child: Stack(
          children: [
            Positioned.fill(
              top: lip,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: GuessPalette.lipOf(widget.color),
                  borderRadius: BorderRadius.circular(9),
                ),
              ),
            ),
            AnimatedPositioned(
              duration: const Duration(milliseconds: 60),
              left: 0,
              right: 0,
              top: _down ? lip : 0,
              bottom: _down ? 0 : lip,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                alignment: Alignment.center,
                decoration: BoxDecoration(color: widget.color, borderRadius: BorderRadius.circular(9)),
                child: widget.icon != null
                    ? Icon(widget.icon, color: Colors.white, size: widget.fontSize * 1.25)
                    : FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: Text(
                            widget.label ?? '',
                            style: GoogleFonts.nunito(
                              fontSize: widget.fontSize,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
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
}

/// Satır satır tuş takımı. Özel tuşlar ("ENTER", "DEL") daha geniştir.
class GuessKeyboard extends StatelessWidget {
  final List<List<String>> rows;
  final int Function(String key) statusOf;
  final GuessPalette palette;
  final void Function(String key) onKey;
  final VoidCallback onEnter;
  final VoidCallback onDelete;
  final String enterLabel;
  final double keyHeight;
  final double fontSize;
  final String Function(String)? display;

  const GuessKeyboard({
    super.key,
    required this.rows,
    required this.statusOf,
    required this.palette,
    required this.onKey,
    required this.onEnter,
    required this.onDelete,
    required this.enterLabel,
    this.keyHeight = 54,
    this.fontSize = 17,
    this.display,
  });

  static const double _gap = 5;
  static const double _wide = 1.55;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        // En kalabalık satıra göre birim genişlik
        double units(List<String> r) => r.fold(0.0, (a, k) => a + (k == 'ENTER' || k == 'DEL' ? _wide : 1));
        final unit = rows.map((r) => (c.maxWidth - _gap * (r.length - 1)) / units(r)).reduce(min).clamp(0.0, 46.0);
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final r in rows)
              Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < r.length; i++) ...[if (i > 0) const SizedBox(width: _gap), _key(r[i], unit)],
                  ],
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _key(String k, double unit) {
    if (k == 'ENTER') {
      return GuessKey(
        label: enterLabel,
        color: palette.correct,
        width: unit * _wide,
        height: keyHeight,
        fontSize: fontSize * 0.75,
        onTap: onEnter,
      );
    }
    if (k == 'DEL') {
      return GuessKey(
        icon: Icons.backspace_rounded,
        color: palette.key,
        width: unit * _wide,
        height: keyHeight,
        fontSize: fontSize,
        onTap: onDelete,
      );
    }
    final s = statusOf(k);
    return GuessKey(
      label: display?.call(k) ?? k,
      color: s == 0 ? palette.key : palette.forStatus(s),
      width: unit,
      height: keyHeight,
      fontSize: fontSize,
      onTap: () => onKey(k),
    );
  }
}

/// Tahtanın üstünde kısa uyarı balonu
class GuessToast extends StatelessWidget {
  final String message;
  const GuessToast(this.message, {super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: Center(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
          child: message.isEmpty
              ? const SizedBox.shrink()
              : Container(
                  key: ValueKey(message),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                  child: Text(
                    message,
                    style: GoogleFonts.nunito(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF1B1B2F),
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}

/// Sonuç sayfası için emoji ızgarası (🟩🟨⬛)
String guessEmojiGrid(List<List<int>> statuses, {String present = '🟨'}) => statuses
    .map(
      (row) => row
          .map(
            (s) => switch (s) {
              3 => '🟩',
              2 => present,
              _ => '⬛',
            },
          )
          .join(),
    )
    .join('\n');
