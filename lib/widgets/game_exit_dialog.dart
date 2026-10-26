import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/app_strings.dart';

Future<bool> showExitConfirmDialog(BuildContext context, {bool isDailyRun = false}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: const Color(0xFF1B1B2F),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(
        AppStrings.areYouSure,
        style: GoogleFonts.nunito(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
      content: Text(
        isDailyRun ? AppStrings.exitConfirmationDailyRun : AppStrings.exitConfirmation,
        style: GoogleFonts.nunito(
          color: Colors.white70,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false), // Continue
          child: Text(
            AppStrings.continueGame,
            style: GoogleFonts.nunito(color: Colors.blueAccent, fontWeight: FontWeight.bold),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true), // Exit
          child: Text(
            AppStrings.quit,
            style: GoogleFonts.nunito(color: Colors.redAccent, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    ),
  );
  return result ?? false;
}
