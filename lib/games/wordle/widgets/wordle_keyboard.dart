import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/app_theme.dart';
import '../../../services/language_service.dart';
import '../../../services/app_strings.dart';
import '../wordle_game.dart';

/// Dile göre Q/QWERTY klavye düzeni — ekran genişliğine responsive
class WordleKeyboard extends StatelessWidget {
  final Map<String, LetterStatus> keyStatuses;
  final void Function(String letter) onLetterTap;
  final VoidCallback onEnterTap;
  final VoidCallback onDeleteTap;

  const WordleKeyboard({
    super.key,
    required this.keyStatuses,
    required this.onLetterTap,
    required this.onEnterTap,
    required this.onDeleteTap,
  });

  // Türkçe Q klavye düzeni
  static const List<List<String>> _rowsTr = [
    ['Q', 'W', 'E', 'R', 'T', 'Y', 'U', 'I', 'O', 'P', 'Ğ', 'Ü'],
    ['A', 'S', 'D', 'F', 'G', 'H', 'J', 'K', 'L', 'Ş', 'İ'],
    ['ENT', 'Z', 'X', 'C', 'V', 'B', 'N', 'M', 'Ö', 'Ç', '⌫'],
  ];

  // İngilizce QWERTY klavye düzeni
  static const List<List<String>> _rowsEn = [
    ['Q', 'W', 'E', 'R', 'T', 'Y', 'U', 'I', 'O', 'P'],
    ['A', 'S', 'D', 'F', 'G', 'H', 'J', 'K', 'L'],
    ['ENT', 'Z', 'X', 'C', 'V', 'B', 'N', 'M', '⌫'],
  ];

  List<List<String>> get _rows =>
      LanguageService().isTurkish ? _rowsTr : _rowsEn;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // En geniş satırdaki tuş sayısı
        final maxKeysInRow = _rows.map((r) => r.length).reduce((a, b) => a > b ? a : b);
        final totalHPadding = 2.0 * 2 * maxKeysInRow; // her tuşun sağ-sol padding'i
        final availableWidth = constraints.maxWidth - totalHPadding;
        final keyWidth = (availableWidth / maxKeysInRow).clamp(26.0, 36.0);
        final keyHeight = (keyWidth * 1.5).clamp(42.0, 54.0);
        final specialKeyWidth = (keyWidth * 1.5).clamp(40.0, 56.0);
        final fontSize = (keyWidth * 0.48).clamp(12.0, 16.0);

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: _rows.asMap().entries.map((entry) {
            final row = entry.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: row.map((key) {
                  if (key == 'ENT') {
                    return _buildSpecialKey(
                      label: AppStrings.enterKey,
                      onTap: onEnterTap,
                      color: AppColors.primary,
                      textColor: Colors.white,
                      width: specialKeyWidth,
                      height: keyHeight,
                      fontSize: fontSize * 0.85,
                    );
                  } else if (key == '⌫') {
                    return _buildSpecialKey(
                      icon: Icons.backspace_outlined,
                      onTap: onDeleteTap,
                      color: const Color(0xFFD3D6DA),
                      textColor: AppColors.textPrimary,
                      width: specialKeyWidth,
                      height: keyHeight,
                      fontSize: fontSize,
                    );
                  } else {
                    return _buildLetterKey(
                      key,
                      width: keyWidth,
                      height: keyHeight,
                      fontSize: fontSize,
                    );
                  }
                }).toList(),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildLetterKey(
    String letter, {
    required double width,
    required double height,
    required double fontSize,
  }) {
    final status = keyStatuses[letter] ?? LetterStatus.empty;

    Color bgColor;
    Color textColor;

    switch (status) {
      case LetterStatus.correct:
        bgColor = AppColors.wordleCorrect;
        textColor = Colors.white;
      case LetterStatus.present:
        bgColor = AppColors.wordlePresent;
        textColor = Colors.white;
      case LetterStatus.absent:
        bgColor = const Color(0xFF787C7E);
        textColor = Colors.white;
      case LetterStatus.empty:
        bgColor = const Color(0xFFD3D6DA);
        textColor = AppColors.textPrimary;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: GestureDetector(
        onTap: () => onLetterTap(letter),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 2,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Text(
            letter,
            style: GoogleFonts.nunito(
              fontSize: fontSize,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSpecialKey({
    String? label,
    IconData? icon,
    required VoidCallback onTap,
    required Color color,
    required Color textColor,
    required double width,
    required double height,
    required double fontSize,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 2,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: icon != null
              ? Icon(icon, size: fontSize * 1.3, color: textColor)
              : Text(
                  label ?? '',
                  style: GoogleFonts.nunito(
                    fontSize: fontSize,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                ),
        ),
      ),
    );
  }
}
