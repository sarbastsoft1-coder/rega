import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class RegaColors {
  // Brand Core - REGA Prime Orange
  static const Color orange = Color(0xFFEA580C);
  static const Color orangeDark = Color(0xFFC2410C);
  static const Color orangeSoft = Color(0xFFFFF7ED);
  static const Color orangeBorder = Color(0xFFFFEDD5);

  // Legacy accents kept for backward compatibility
  static const Color gold = Color(0xFFFAC800);
  static const Color goldDark = Color(0xFFD97706);
  static const Color goldSoft = Color(0xFFFEF9C3);

  // Sidebar Palette
  static const Color forestGreen = Color(0xFF113E2E);
  static const Color forestGreenActive = Color(0xFF1D5540);
  static const Color forestGreenBtn = Color(0xFFEA580C);

  // Operational Accents (matching rega_froshyar & rega_delivery)
  static const Color emerald = Color(0xFF10B981);
  static const Color emeraldDark = Color(0xFF059669);
  static const Color blue = Color(0xFF2563EB);
  static const Color purple = Color(0xFF7C3AED);
  static const Color crimson = Color(0xFFE11D48);

  // Surfaces
  static const Color sidebarBg = Color(0xFF113E2E);
  static const Color sidebarCard = Color(0xFF1D5540);
  static const Color lightCanvas = Color(0xFFF8FAFC);
  static const Color darkCanvas = Color(0xFF090D16);
  static const Color darkSurface = Color(0xFF111827);
}

String formatIqd(num? value, {String lang = 'ku'}) {
  final intVal = (value ?? 0).round();
  final formatted = NumberFormat('#,###', 'en_US').format(intVal);
  final suffix = lang == 'en' ? 'IQD' : 'د.ع';
  return '$formatted $suffix';
}

String formatNumber(num? value) {
  return NumberFormat('#,###', 'en_US').format((value ?? 0).round());
}

class AppTheme {
  static ThemeData light() {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: RegaColors.lightCanvas,
      colorScheme: ColorScheme.fromSeed(
        seedColor: RegaColors.orange,
        brightness: Brightness.light,
        primary: RegaColors.orange,
        secondary: const Color(0xFF0F172A),
        surface: Colors.white,
        surfaceContainerHighest: Colors.white,
        surfaceContainerHigh: Colors.white,
        surfaceContainer: Colors.white,
        surfaceContainerLow: const Color(0xFFF8FAFC),
        surfaceContainerLowest: Colors.white,
      ),
    );

    final textTheme = GoogleFonts.notoKufiArabicTextTheme(base.textTheme).apply(
      bodyColor: const Color(0xFF0F172A),
      displayColor: const Color(0xFF0F172A),
    );

    return base.copyWith(
      textTheme: textTheme,
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 10,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: RegaColors.orange, width: 2.0),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: RegaColors.orange,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: GoogleFonts.notoKufiArabic(fontWeight: FontWeight.w700, fontSize: 13),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }

  static ThemeData dark() {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: RegaColors.darkCanvas,
      colorScheme: ColorScheme.fromSeed(
        seedColor: RegaColors.orange,
        brightness: Brightness.dark,
        primary: RegaColors.orange,
        secondary: RegaColors.emerald,
        surface: RegaColors.darkSurface,
      ),
    );

    final textTheme = GoogleFonts.notoKufiArabicTextTheme(base.textTheme).apply(
      bodyColor: const Color(0xFFF8FAFC),
      displayColor: const Color(0xFFF8FAFC),
    );

    return base.copyWith(
      textTheme: textTheme,
      dialogTheme: DialogThemeData(
        backgroundColor: RegaColors.darkSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 10,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      ),
      cardTheme: CardThemeData(
        color: RegaColors.darkSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: Color(0xFF1F2937)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF1E293B),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF334155)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF334155)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: RegaColors.orange, width: 2.0),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: RegaColors.orange,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: GoogleFonts.notoKufiArabic(fontWeight: FontWeight.w700, fontSize: 13),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }
}

