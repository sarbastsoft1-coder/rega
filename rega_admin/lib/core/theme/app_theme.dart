import 'package:flutter/material.dart';
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
  static const Color darkCard = Color(0xFF1A2332);
  static const Color darkBorder = Color(0xFF243044);
  static const Color lightBorder = Color(0xFFE2E8F0);
  static const Color lightMuted = Color(0xFF64748B);
  static const Color darkMuted = Color(0xFF94A3B8);
}

/// Theme-aware surface / text tokens so screens avoid hardcoded white cards.
class AdminSurfaces {
  AdminSurfaces._(this.isDark);

  factory AdminSurfaces.of(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return AdminSurfaces._(brightness == Brightness.dark);
  }

  final bool isDark;

  Color get canvas => isDark ? RegaColors.darkCanvas : RegaColors.lightCanvas;
  Color get card => isDark ? RegaColors.darkCard : Colors.white;
  Color get elevated => isDark ? RegaColors.darkSurface : Colors.white;
  Color get border => isDark ? RegaColors.darkBorder : RegaColors.lightBorder;
  Color get hairline => isDark ? const Color(0xFF1F2937) : const Color(0xFFF1F5F9);
  Color get mutedFill => isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC);
  Color get chipFill => isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9);
  Color get textPrimary => isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
  Color get textSecondary => isDark ? RegaColors.darkMuted : RegaColors.lightMuted;
  Color get textTertiary => isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8);
  Color get shadow => isDark ? Colors.black38 : const Color(0x06000000);
  Color get inputFill => isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC);
  Color get dialog => isDark ? RegaColors.darkSurface : Colors.white;
  Color get sidebar => RegaColors.sidebarBg;
  Color get dangerSoft => isDark ? const Color(0xFF3F1D1D) : const Color(0xFFFEE2E2);
  Color get successSoft => isDark ? const Color(0xFF14532D) : const Color(0xFFDCFCE7);
  Color get warnSoft => isDark ? const Color(0xFF422006) : const Color(0xFFFEF3C7);
  Color get infoSoft => isDark ? const Color(0xFF1E3A5F) : const Color(0xFFDBEAFE);

  /// Standard panel / KPI / table chrome used across admin screens.
  BoxDecoration cardDecoration({
    double radius = 16,
    Color? color,
    Color? borderColor,
    List<BoxShadow>? boxShadow,
  }) {
    return BoxDecoration(
      color: color ?? card,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: borderColor ?? hairline),
      boxShadow: boxShadow ??
          [
            BoxShadow(
              color: shadow,
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
    );
  }
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
      fontFamily: 'NotoKufiArabic',
      scaffoldBackgroundColor: RegaColors.lightCanvas,
      colorScheme: ColorScheme.fromSeed(
        seedColor: RegaColors.orange,
        brightness: Brightness.light,
        primary: RegaColors.orange,
        secondary: const Color(0xFF0F172A),
        surface: Colors.white,
        onSurface: const Color(0xFF0F172A),
        surfaceContainerHighest: Colors.white,
        surfaceContainerHigh: Colors.white,
        surfaceContainer: Colors.white,
        surfaceContainerLow: const Color(0xFFF8FAFC),
        surfaceContainerLowest: Colors.white,
      ),
    );

    final textTheme = base.textTheme.apply(
      bodyColor: const Color(0xFF0F172A),
      displayColor: const Color(0xFF0F172A),
      fontFamily: 'NotoKufiArabic',
    );

    return base.copyWith(
      textTheme: textTheme,
      dividerTheme: const DividerThemeData(color: Color(0xFFF1F5F9), thickness: 1, space: 1),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: Color(0xFF0F172A),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(
          fontFamily: 'NotoKufiArabic',
          color: Color(0xFF0F172A),
          fontWeight: FontWeight.w600,
        ),
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        menuStyle: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(Colors.white),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        ),
        textStyle: const TextStyle(
          fontFamily: 'NotoKufiArabic',
          color: Color(0xFF0F172A),
          fontWeight: FontWeight.w600,
        ),
      ),
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
          side: const BorderSide(color: RegaColors.lightBorder),
        ),
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: Color(0xFF0F172A),
        contentTextStyle: TextStyle(
          fontFamily: 'NotoKufiArabic',
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
        behavior: SnackBarBehavior.floating,
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
        hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontFamily: 'NotoKufiArabic'),
        labelStyle: const TextStyle(color: Color(0xFF64748B), fontFamily: 'NotoKufiArabic'),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: RegaColors.orange,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: const TextStyle(
            fontFamily: 'NotoKufiArabic',
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }

  static ThemeData dark() {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      fontFamily: 'NotoKufiArabic',
      scaffoldBackgroundColor: RegaColors.darkCanvas,
      colorScheme: ColorScheme.fromSeed(
        seedColor: RegaColors.orange,
        brightness: Brightness.dark,
        primary: RegaColors.orange,
        secondary: RegaColors.emerald,
        surface: RegaColors.darkCard,
        onSurface: const Color(0xFFF8FAFC),
        surfaceContainerHighest: RegaColors.darkSurface,
        surfaceContainerHigh: RegaColors.darkCard,
        surfaceContainer: RegaColors.darkCard,
        surfaceContainerLow: const Color(0xFF0F172A),
        surfaceContainerLowest: RegaColors.darkCanvas,
      ),
    );

    final textTheme = base.textTheme.apply(
      bodyColor: const Color(0xFFF8FAFC),
      displayColor: const Color(0xFFF8FAFC),
      fontFamily: 'NotoKufiArabic',
    );

    return base.copyWith(
      textTheme: textTheme,
      dividerTheme: const DividerThemeData(color: Color(0xFF1F2937), thickness: 1, space: 1),
      appBarTheme: const AppBarTheme(
        backgroundColor: RegaColors.darkSurface,
        foregroundColor: Color(0xFFF8FAFC),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: RegaColors.darkSurface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(
          fontFamily: 'NotoKufiArabic',
          color: Color(0xFFF8FAFC),
          fontWeight: FontWeight.w600,
        ),
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        menuStyle: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(RegaColors.darkSurface),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        ),
        textStyle: const TextStyle(
          fontFamily: 'NotoKufiArabic',
          color: Color(0xFFF8FAFC),
          fontWeight: FontWeight.w600,
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: RegaColors.darkSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 10,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      ),
      cardTheme: CardThemeData(
        color: RegaColors.darkCard,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: RegaColors.darkBorder),
        ),
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: Color(0xFF1E293B),
        contentTextStyle: TextStyle(
          fontFamily: 'NotoKufiArabic',
          color: Color(0xFFF8FAFC),
          fontWeight: FontWeight.w700,
        ),
        behavior: SnackBarBehavior.floating,
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
        hintStyle: const TextStyle(color: Color(0xFF64748B), fontFamily: 'NotoKufiArabic'),
        labelStyle: const TextStyle(color: Color(0xFF94A3B8), fontFamily: 'NotoKufiArabic'),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: RegaColors.orange,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: const TextStyle(
            fontFamily: 'NotoKufiArabic',
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }
}
