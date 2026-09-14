import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const bgDark = Color(0xFF0F1218);
  static const surfaceDark = Color(0xFF161B24);
  static const cardDark = Color(0xFF1F2533);
  static const cardHover = Color(0xFF283042);
  static const borderDark = Color(0xFF2C3446);

  static const primaryGold = Color(0xFFEAB308);
  static const accentBlue = Color(0xFF38BDF8);
  static const accentGreen = Color(0xFF22C55E);
  static const accentRed = Color(0xFFEF4444);
  static const accentPurple = Color(0xFFA855F7);

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: bgDark,
      canvasColor: surfaceDark,
      cardColor: cardDark,
      dividerColor: borderDark,
      colorScheme: const ColorScheme.dark(
        primary: primaryGold,
        secondary: accentBlue,
        surface: surfaceDark,
        error: accentRed,
      ),
      textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme).copyWith(
        titleLarge: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white),
        titleMedium: GoogleFonts.outfit(fontWeight: FontWeight.w600, color: Colors.white),
        bodyMedium: GoogleFonts.inter(color: Colors.white70),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: surfaceDark,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: cardDark,
        side: const BorderSide(color: borderDark),
        labelStyle: GoogleFonts.inter(fontSize: 12, color: Colors.white),
      ),
    );
  }
}
