import 'package:flutter/material.dart';

/// Shared light / dark color adapter for every REGA app.
///
/// Screens were designed with light-mode colors written inline
/// (white cards, slate text, pale badges). Instead of hand-editing each one,
/// every inline color goes through [RC.bg] (surfaces, borders, fills) or
/// [RC.fg] (text, icons). In light mode they return the color unchanged.
/// In dark mode:
///   * light neutral surfaces  -> dark slate surfaces (page < card < border),
///   * pale tinted badges      -> deep tinted badges (same hue),
///   * dark neutral text       -> light text,
///   * dark tinted text        -> lighter tint (same hue),
///   * brand / accent colors   -> unchanged.
class RC {
  RC._();

  static bool _dark = false;
  static bool get isDark => _dark;

  /// Called from each app's root build. Rebuilds the whole tree on change.
  static void setDark(bool value) {
    if (value == _dark) return;
    _dark = value;
    _bgCache.clear();
    _fgCache.clear();
    final binding = WidgetsBinding.instance;
    binding.addPostFrameCallback((_) {
      final root = binding.rootElement;
      if (root == null) return;
      void visit(Element e) {
        e.markNeedsBuild();
        e.visitChildren(visit);
      }

      root.visitChildren(visit);
    });
    binding.scheduleFrame();
  }

  // Dark palette (slate) used for neutral surfaces.
  static const Color darkPage = Color(0xFF0F172A);
  static const Color darkCard = Color(0xFF1A2333);
  static const Color darkRaised = Color(0xFF243045);
  static const Color darkBorder = Color(0xFF334155);

  static final Map<int, Color> _bgCache = {};
  static final Map<int, Color> _fgCache = {};

  static int _key(Color c) => c.toARGB32();

  /// Surface / fill / border color.
  static Color bg(Color c) {
    if (!_dark) return c;
    return _bgCache.putIfAbsent(_key(c), () => _mapBg(c));
  }

  /// Text / icon color.
  static Color fg(Color c) {
    if (!_dark) return c;
    return _fgCache.putIfAbsent(_key(c), () => _mapFg(c));
  }

  /// Nullable helpers for optional params.
  static Color? bgn(Color? c) => c == null ? null : bg(c);
  static Color? fgn(Color? c) => c == null ? null : fg(c);

  static Color _mapBg(Color c) {
    final a = c.a;
    if (a == 0) return c;
    final hsl = HSLColor.fromColor(c.withValues(alpha: 1));
    final l = hsl.lightness;
    final s = hsl.saturation;
    if (l < 0.55) return c; // already dark (overlays, dark buttons, accents)
    final neutral = s < 0.22 || l > 0.985;
    if (neutral) {
      Color target;
      if (l >= 0.995) {
        target = darkCard; // white cards / sheets
      } else if (l >= 0.95) {
        target = darkPage; // page backgrounds (F8FAFC, F1F5F9, F4F5F7 …)
      } else if (l >= 0.86) {
        target = darkRaised; // grey.shade100–200, chips, inputs
      } else {
        target = darkBorder; // borders / dividers (E2E8F0, CBD5E1, grey)
      }
      return target.withValues(alpha: a);
    }
    if (l > 0.82) {
      // pale tinted badge / soft background -> deep tint of the same hue
      return HSLColor.fromAHSL(a, hsl.hue, (s * 0.55).clamp(0.25, 0.55), 0.17).toColor();
    }
    return c; // saturated accent (yellow, orange, green …)
  }

  static Color _mapFg(Color c) {
    final a = c.a;
    if (a == 0) return c;
    final hsl = HSLColor.fromColor(c.withValues(alpha: 1));
    final l = hsl.lightness;
    final s = hsl.saturation;
    if (s < 0.3) {
      if (l >= 0.6) return c; // light text (white on buttons) stays
      // slate / grey / black text -> light slate
      final nl = (1.0 - l).clamp(0.66, 0.95);
      return HSLColor.fromAHSL(a, hsl.hue, s.clamp(0.0, 0.2), nl).toColor();
    }
    if (l >= 0.45) return c; // accents stay
    // dark tinted text (dark green / red labels) -> readable tint
    return HSLColor.fromAHSL(a, hsl.hue, s.clamp(0.0, 0.85), 0.68).toColor();
  }
}
