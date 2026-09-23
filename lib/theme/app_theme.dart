import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  // Ana palet
  static const Color background = Color(0xFFF5F5FA);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color primary = Color(0xFF6C5CE7);
  static const Color primaryLight = Color(0xFFD5D0F5);
  static const Color secondary = Color(0xFF00B894);
  static const Color secondaryLight = Color(0xFFB8F0E0);
  static const Color accent = Color(0xFFFF6B6B);
  static const Color accentLight = Color(0xFFFFD4D4);
  static const Color textPrimary = Color(0xFF2D3436);
  static const Color textSecondary = Color(0xFF636E72);
  static const Color textLight = Color(0xFFB2BEC3);

  // Oyun kartları için canlı gradientler
  static const List<List<Color>> cardGradients = [
    [Color(0xFF6C5CE7), Color(0xFFA29BFE)], // Mor
    [Color(0xFF00B894), Color(0xFF55EFC4)], // Yeşil
    [Color(0xFFFF6B6B), Color(0xFFFF8E8E)], // Kırmızı
    [Color(0xFFFDAA5E), Color(0xFFFFC988)], // Turuncu
    [Color(0xFF0984E3), Color(0xFF74B9FF)], // Mavi
    [Color(0xFFE84393), Color(0xFFFD79A8)], // Pembe
    [Color(0xFF00CEC9), Color(0xFF81ECEC)], // Turkuaz
    [Color(0xFFF39C12), Color(0xFFFECE54)], // Altın
    [Color(0xFF6D5BBA), Color(0xFF8D58BF)], // Koyu mor
  ];

  // Wordle renkleri
  static const Color wordleCorrect = Color(0xFF6AAA64);
  static const Color wordlePresent = Color(0xFFC9B458);
  static const Color wordleAbsent = Color(0xFF787C7E);
  static const Color wordleEmpty = Color(0xFFD3D6DA);
  static const Color wordleBorder = Color(0xFF878A8C);
}

class AppTheme {
  static TextTheme get _gameTextTheme {
    return GoogleFonts.nunitoTextTheme();
  }

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.background,
      textTheme: _gameTextTheme,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        brightness: Brightness.light,
        surface: AppColors.surface,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.nunito(
          color: AppColors.textPrimary,
          fontSize: 28,
          fontWeight: FontWeight.w700,
        ),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
    );
  }
}
