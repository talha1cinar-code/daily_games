import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

Future<bool> showExitConfirmDialog(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: const Color(0xFF1B1B2F),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(
        'Emin misin?',
        style: GoogleFonts.nunito(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
      content: Text(
        'Oyundan çıkmak istediğine emin misin? İlerlemen kaydedilmeyecek.',
        style: GoogleFonts.nunito(
          color: Colors.white70,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false), // Continue
          child: Text(
            'Devam Et',
            style: GoogleFonts.nunito(color: Colors.blueAccent, fontWeight: FontWeight.bold),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true), // Exit
          child: Text(
            'Çık',
            style: GoogleFonts.nunito(color: Colors.redAccent, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    ),
  );
  return result ?? false;
}
