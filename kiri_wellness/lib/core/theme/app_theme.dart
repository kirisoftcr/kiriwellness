import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // ── Kiri Wellness brand palette ───────────────────────────────────────────
  static const Color primary     = Color(0xFF9D87BC); // lavender – CTAs & accents
  static const Color primaryDark = Color(0xFF4A5240); // dark olive – headers & nav
  static const Color primaryLight= Color(0xFFD4C8E8); // lavender light
  static const Color secondary   = Color(0xFF9B8B7A); // warm taupe
  static const Color secondaryLight = Color(0xFFD4C4B0);
  static const Color accent      = Color(0xFF9D87BC); // lavender
  static const Color background  = Color(0xFFF0EBE0); // warm cream
  static const Color surface     = Color(0xFFFFFFFF);
  static const Color textPrimary = Color(0xFF2D2A25);
  static const Color textSecondary = Color(0xFF9B8B7A); // taupe
  static const Color error       = Color(0xFFE57373);
  static const Color success     = Color(0xFF81C784);
  static const Color warning     = Color(0xFFFFB74D);
  // Olive shades used as surface tints
  static const Color oliveLight  = Color(0xFFE8E6E0);

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryDark,
        primary: primary,
        secondary: secondary,
        surface: surface,
        error: error,
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: background,
      textTheme: GoogleFonts.latoTextTheme().copyWith(
        displayLarge: GoogleFonts.cormorantGaramond(
          fontSize: 36,
          fontWeight: FontWeight.w600,
          color: primaryDark,
        ),
        displayMedium: GoogleFonts.cormorantGaramond(
          fontSize: 28,
          fontWeight: FontWeight.w600,
          color: primaryDark,
        ),
        titleLarge: GoogleFonts.cormorantGaramond(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: primaryDark,
        ),
        titleMedium: GoogleFonts.lato(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        bodyLarge: GoogleFonts.lato(fontSize: 16, color: textPrimary),
        bodyMedium: GoogleFonts.lato(fontSize: 14, color: textPrimary),
        labelLarge: GoogleFonts.lato(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: surface,
        elevation: 0,
        centerTitle: false,
        iconTheme: const IconThemeData(color: primaryDark),
        titleTextStyle: GoogleFonts.cormorantGaramond(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: primaryDark,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryDark,
          side: const BorderSide(color: primaryDark),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFE6DFCF)),
        ),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: background,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFD4C4B0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFD4C4B0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: primaryLight.withValues(alpha: 0.3),
        selectedColor: primary,
        labelStyle: GoogleFonts.lato(fontSize: 12),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      dividerTheme: const DividerThemeData(color: Color(0xFFE6DFCF), thickness: 1),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: surface,
        selectedIconTheme: const IconThemeData(color: primary),
        unselectedIconTheme: const IconThemeData(color: Color(0xFFBBB0A0)),
        selectedLabelTextStyle: GoogleFonts.lato(
          color: primaryDark,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
        unselectedLabelTextStyle: GoogleFonts.lato(
          color: secondary,
          fontSize: 12,
        ),
        indicatorColor: primaryLight.withValues(alpha: 0.4),
      ),
    );
  }
}

