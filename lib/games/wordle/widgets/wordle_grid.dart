import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/app_theme.dart';
import '../wordle_game.dart';

/// 6 satır x 5 sütun Wordle ızgarası — animasyonlu
class WordleGrid extends StatelessWidget {
  final WordleGame game;
  final Animation<double>? shakeAnimation;
  final int? shakingRow;
  final int? revealingRow;
  final Animation<double>? revealAnimation;
  final int? bouncingCell; // Harf girildiğinde bounce yapacak hücre

  const WordleGrid({
    super.key,
    required this.game,
    this.shakeAnimation,
    this.shakingRow,
    this.revealingRow,
    this.revealAnimation,
    this.bouncingCell,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(game.maxAttempts, (row) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: _buildRow(row),
        );
      }),
    );
  }

  Widget _buildRow(int row) {
    Widget rowWidget = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(game.wordLength, (col) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: _buildCell(row, col),
        );
      }),
    );

    // Sallama animasyonu — geçersiz kelime
    if (shakingRow == row && shakeAnimation != null) {
      return AnimatedBuilder(
        animation: shakeAnimation!,
        builder: (context, child) {
          final progress = shakeAnimation!.value;
          // Sönümleyen sinüs dalgası
          final offset = sin(progress * pi * 4) * 8 * (1 - progress);
          return Transform.translate(
            offset: Offset(offset, 0),
            child: child,
          );
        },
        child: rowWidget,
      );
    }

    return rowWidget;
  }

  Widget _buildCell(int row, int col) {
    String letter = '';
    LetterStatus status = LetterStatus.empty;
    bool isCurrentRow = row == game.guesses.length && !game.isGameOver;
    bool hasLetter = false;

    if (row < game.guesses.length) {
      letter = game.guesses[row][col];
      status = game.guessStatuses[row][col];
      hasLetter = true;
    } else if (isCurrentRow && col < game.currentGuess.length) {
      letter = game.currentGuess[col];
      hasLetter = true;
    }

    // Renk belirleme
    Color bgColor;
    Color borderColor;
    Color textColor;

    // Reveal animasyonu sırasında renk geçişi
    bool isRevealing = revealingRow == row && revealAnimation != null;
    double cellProgress = 0.0;

    if (isRevealing) {
      final cellDelay = col * 0.18;
      cellProgress = ((revealAnimation!.value * 1.5 - cellDelay)).clamp(0.0, 1.0);
    }

    if (isRevealing && cellProgress > 0.5) {
      // Flip'in ikinci yarısı — renkli göster
      switch (status) {
        case LetterStatus.correct:
          bgColor = AppColors.wordleCorrect;
          borderColor = AppColors.wordleCorrect;
          textColor = Colors.white;
        case LetterStatus.present:
          bgColor = AppColors.wordlePresent;
          borderColor = AppColors.wordlePresent;
          textColor = Colors.white;
        case LetterStatus.absent:
          bgColor = AppColors.wordleAbsent;
          borderColor = AppColors.wordleAbsent;
          textColor = Colors.white;
        case LetterStatus.empty:
          bgColor = Colors.white;
          borderColor = AppColors.wordleEmpty;
          textColor = AppColors.textPrimary;
      }
    } else if (isRevealing && cellProgress > 0.0) {
      // Flip'in ilk yarısı — beyaz göster
      bgColor = Colors.white;
      borderColor = AppColors.wordleBorder;
      textColor = AppColors.textPrimary;
    } else {
      // Normal durum (tamamlanmış veya boş)
      switch (status) {
        case LetterStatus.correct:
          bgColor = AppColors.wordleCorrect;
          borderColor = AppColors.wordleCorrect;
          textColor = Colors.white;
        case LetterStatus.present:
          bgColor = AppColors.wordlePresent;
          borderColor = AppColors.wordlePresent;
          textColor = Colors.white;
        case LetterStatus.absent:
          bgColor = AppColors.wordleAbsent;
          borderColor = AppColors.wordleAbsent;
          textColor = Colors.white;
        case LetterStatus.empty:
          bgColor = Colors.white;
          borderColor = hasLetter ? AppColors.wordleBorder : AppColors.wordleEmpty;
          textColor = AppColors.textPrimary;
      }
    }

    // Harf girişi bounce animasyonu
    bool shouldBounce = isCurrentRow &&
        bouncingCell != null &&
        col == bouncingCell &&
        hasLetter;

    Widget cell = Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: bgColor,
        border: Border.all(color: borderColor, width: 2),
        borderRadius: BorderRadius.circular(8),
      ),
      alignment: Alignment.center,
      child: Text(
        letter,
        style: GoogleFonts.nunito(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          color: textColor,
        ),
      ),
    );

    // Bounce efekti — harf girildiğinde
    if (shouldBounce) {
      cell = TweenAnimationBuilder<double>(
        key: ValueKey('bounce_${row}_${col}_$letter'),
        tween: Tween(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 150),
        builder: (context, value, child) {
          final scale = value < 0.5 ? 1.0 + value * 0.2 : 1.0 + (1.0 - value) * 0.2;
          return Transform.scale(scale: scale, child: child);
        },
        child: cell,
      );
    }

    // Flip efekti — reveal sırasında
    if (isRevealing && cellProgress > 0.0) {
      final flipValue = cellProgress;
      final angle = flipValue <= 0.5
          ? flipValue * pi // 0 -> π/2
          : (1.0 - flipValue) * pi; // π/2 -> 0

      cell = Transform(
        alignment: Alignment.center,
        transform: Matrix4.identity()
          ..setEntry(3, 2, 0.001) // perspektif
          ..rotateX(angle),
        child: cell,
      );
    }

    return cell;
  }
}

