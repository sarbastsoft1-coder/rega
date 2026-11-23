import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/customer_l10n.dart';
import '../rega_colors.dart';

/// Redesigned Language & Appearance preferences card for the REGA customer app.
///
/// Used on both the logged-in Profile screen and the pre-login Auth screen.
/// Supports Kurdish (RTL), Arabic (RTL), and English (LTR) in both Light and
/// Dark modes with proper directional alignment, an animated 3-option language
/// selector tray, and a dedicated always-visible Appearance toggle row.
class ProfilePreferencesCard extends StatefulWidget {
  const ProfilePreferencesCard({
    super.key,
    required this.currentLanguage,
    required this.isDark,
    required this.onLanguageSelected,
    required this.onDarkModeChanged,
    this.isExpanded,
    this.onExpandedChanged,
    this.initiallyExpanded = false,
  });

  /// Active language display name or code (e.g. 'کوردی', 'العربية', 'English',
  /// 'ku', 'ar', 'en').
  final String currentLanguage;

  /// Whether Dark Mode is currently active.
  final bool isDark;

  /// Invoked with the canonical language display name ('کوردی', 'العربية', or
  /// 'English') when the customer selects a language tile.
  final ValueChanged<String> onLanguageSelected;

  /// Invoked with the desired dark-mode state when the customer toggles theme.
  final ValueChanged<bool> onDarkModeChanged;

  /// Optional controlled expansion state for the language picker tray.
  final bool? isExpanded;

  /// Called when the language header is tapped if [isExpanded] is controlled.
  final ValueChanged<bool>? onExpandedChanged;

  /// Initial expansion state when uncontrolled (defaults to collapsed).
  final bool initiallyExpanded;

  @override
  State<ProfilePreferencesCard> createState() => _ProfilePreferencesCardState();
}

class _LanguageChoice {
  const _LanguageChoice({
    required this.code,
    required this.badge,
    required this.value,
    required this.labelKey,
  });

  final String code;
  final String badge;
  final String value;
  final String labelKey;
}

class _ProfilePreferencesCardState extends State<ProfilePreferencesCard> {
  static const _fontFamily = 'NotoKufiArabic';

  // Brand amber & warm gold accents consistent with the REGA customer app.
  static const _brandGold = Color(0xFFFAC800);
  static const _brandAmber = Color(0xFFF59E0B);
  static const _brandAmberDeep = Color(0xFFB45309);
  static const _brandAmberText = Color(0xFF92400E);
  static const _brandInk = Color(0xFF422006);

  static const List<_LanguageChoice> _languages = [
    _LanguageChoice(
      code: 'ku',
      badge: 'KU',
      value: 'کوردی',
      labelKey: 'کوردی',
    ),
    _LanguageChoice(
      code: 'ar',
      badge: 'AR',
      value: 'العربية',
      labelKey: 'العربية',
    ),
    _LanguageChoice(
      code: 'en',
      badge: 'EN',
      value: 'English',
      labelKey: 'English',
    ),
  ];

  late bool _localExpanded;

  @override
  void initState() {
    super.initState();
    _localExpanded = widget.initiallyExpanded;
  }

  bool get _expanded => widget.isExpanded ?? _localExpanded;

  void _toggleExpanded() {
    HapticFeedback.selectionClick();
    final next = !_expanded;
    if (widget.onExpandedChanged != null) {
      widget.onExpandedChanged!(next);
    } else {
      setState(() => _localExpanded = next);
    }
  }

  void _handleLanguageTap(_LanguageChoice choice) {
    final activeCode = CustomerL10n.normalizeLang(widget.currentLanguage);
    if (choice.code == activeCode) return;
    HapticFeedback.selectionClick();
    widget.onLanguageSelected(choice.value);
  }

  void _handleDarkChange(bool value) {
    if (value == widget.isDark) return;
    HapticFeedback.selectionClick();
    widget.onDarkModeChanged(value);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final langCode = CustomerL10n.normalizeLang(widget.currentLanguage);
    final activeChoice = _languages.firstWhere(
      (c) => c.code == langCode,
      orElse: () => _languages.first,
    );

    final cardBg = isDark ? RC.darkCard : Colors.white;
    final cardBorder = isDark ? RC.darkBorder : const Color(0xFFEEF2F6);
    final dividerColor = isDark
        ? RC.darkBorder.withValues(alpha: 0.65)
        : const Color(0xFFF1F5F9);
    final titleColor = isDark
        ? const Color(0xFFF8FAFC)
        : const Color(0xFF0F172A);
    final subtitleColor = isDark
        ? const Color(0xFF94A3B8)
        : const Color(0xFF64748B);

    final languagesTitle = CustomerL10n.tr('زمانەکان', langCode);
    final activeLangLabel = CustomerL10n.tr(activeChoice.labelKey, langCode);
    final appearanceTitle = CustomerL10n.tr('ڕووکار', langCode);
    final appearanceSubtitle = CustomerL10n.tr(
      isDark ? 'دۆخی تاریک' : 'دۆخی ڕووناک',
      langCode,
    );

    return AnimatedContainer(
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: cardBorder),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.24)
                : const Color(0xFF0F172A).withValues(alpha: 0.045),
            blurRadius: 16,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(23),
        child: Material(
          type: MaterialType.transparency,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 1. LANGUAGE HEADER ROW
              Semantics(
                button: true,
                expanded: _expanded,
                label: '$languagesTitle, $activeLangLabel',
                child: InkWell(
                  key: const ValueKey('preferences_language_header'),
                  onTap: _toggleExpanded,
                  splashColor: _brandAmber.withValues(alpha: 0.10),
                  highlightColor: _brandAmber.withValues(alpha: 0.05),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    child: Row(
                      children: [
                        _buildIconBadge(
                          isDark: isDark,
                          icon: Icons.translate_rounded,
                          iconColor: isDark
                              ? const Color(0xFFFCD34D)
                              : _brandAmberDeep,
                          gradientColors: isDark
                              ? [
                                  _brandAmber.withValues(alpha: 0.18),
                                  _brandAmber.withValues(alpha: 0.09),
                                ]
                              : const [Color(0xFFFFFBEB), Color(0xFFFEF3C7)],
                          borderColor: isDark
                              ? _brandAmber.withValues(alpha: 0.30)
                              : const Color(0xFFFDE68A),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                languagesTitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontFamily: _fontFamily,
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w700,
                                  color: titleColor,
                                  height: 1.25,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                activeLangLabel,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontFamily: _fontFamily,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w500,
                                  color: subtitleColor,
                                  height: 1.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Compact active language pill
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 220),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: isDark
                                ? _brandAmber.withValues(alpha: 0.16)
                                : const Color(0xFFFFFBEB),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: isDark
                                  ? _brandAmber.withValues(alpha: 0.35)
                                  : const Color(0xFFFDE68A),
                            ),
                          ),
                          child: Text(
                            activeChoice.badge,
                            style: TextStyle(
                              fontFamily: _fontFamily,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                              color: isDark
                                  ? const Color(0xFFFCD34D)
                                  : _brandAmberDeep,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Animated rotating chevron container
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 220),
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: _expanded
                                ? (isDark
                                      ? _brandAmber.withValues(alpha: 0.20)
                                      : const Color(0xFFFEF3C7))
                                : (isDark
                                      ? RC.darkRaised
                                      : const Color(0xFFF1F5F9)),
                            shape: BoxShape.circle,
                          ),
                          child: AnimatedRotation(
                            turns: _expanded ? 0.5 : 0.0,
                            duration: const Duration(milliseconds: 240),
                            curve: Curves.easeOutCubic,
                            child: Icon(
                              Icons.keyboard_arrow_down_rounded,
                              size: 19,
                              color: _expanded
                                  ? (isDark
                                        ? const Color(0xFFFCD34D)
                                        : _brandAmberDeep)
                                  : subtitleColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // 2. EXPANDABLE 3-COLUMN LANGUAGE PICKER TRAY
              ClipRect(
                child: AnimatedSize(
                  duration: const Duration(milliseconds: 240),
                  curve: Curves.easeOutCubic,
                  alignment: Alignment.topCenter,
                  child: _expanded
                      ? Padding(
                          padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                          child: Container(
                            key: const ValueKey('preferences_language_tray'),
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? RC.darkPage
                                  : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: isDark
                                    ? RC.darkRaised
                                    : const Color(0xFFF1F5F9),
                              ),
                            ),
                            child: Row(
                              children: [
                                for (var i = 0; i < _languages.length; i++) ...[
                                  if (i > 0) const SizedBox(width: 6),
                                  Expanded(
                                    child: _LanguageTile(
                                      choice: _languages[i],
                                      label: CustomerL10n.tr(
                                        _languages[i].labelKey,
                                        langCode,
                                      ),
                                      isSelected:
                                          _languages[i].code == langCode,
                                      isDark: isDark,
                                      onTap: () =>
                                          _handleLanguageTap(_languages[i]),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        )
                      : const SizedBox(width: double.infinity),
                ),
              ),

              // INSET HAIRLINE DIVIDER
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(height: 1, color: dividerColor),
              ),

              // 3. APPEARANCE / LIGHT-DARK MODE ROW (ALWAYS VISIBLE)
              Semantics(
                toggled: isDark,
                label: '$appearanceTitle, $appearanceSubtitle',
                child: InkWell(
                  key: const ValueKey('preferences_theme_row'),
                  onTap: () => _handleDarkChange(!isDark),
                  splashColor: _brandAmber.withValues(alpha: 0.10),
                  highlightColor: _brandAmber.withValues(alpha: 0.05),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 13,
                    ),
                    child: Row(
                      children: [
                        _buildIconBadge(
                          isDark: isDark,
                          icon: isDark
                              ? Icons.dark_mode_rounded
                              : Icons.light_mode_rounded,
                          iconKey: ValueKey(isDark ? 'moon_icon' : 'sun_icon'),
                          iconColor: isDark
                              ? const Color(0xFFFACC15)
                              : const Color(0xFFD97706),
                          gradientColors: isDark
                              ? const [Color(0xFF232C4D), Color(0xFF1A223B)]
                              : const [Color(0xFFFFFBEB), Color(0xFFFEF3C7)],
                          borderColor: isDark
                              ? const Color(0xFF6366F1).withValues(alpha: 0.38)
                              : const Color(0xFFFDE68A),
                          animateIcon: true,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                appearanceTitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontFamily: _fontFamily,
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w700,
                                  color: titleColor,
                                  height: 1.25,
                                ),
                              ),
                              const SizedBox(height: 2),
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 200),
                                layoutBuilder: (currentChild, previousChildren) {
                                  return Stack(
                                    alignment: AlignmentDirectional.centerStart,
                                    children: [
                                      ...previousChildren,
                                      if (currentChild != null) currentChild,
                                    ],
                                  );
                                },
                                child: Text(
                                  appearanceSubtitle,
                                  key: ValueKey(appearanceSubtitle),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontFamily: _fontFamily,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w500,
                                    color: subtitleColor,
                                    height: 1.3,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        _ThemeSegmentedToggle(
                          isDark: isDark,
                          lightTooltip: CustomerL10n.tr('ڕووناک', langCode),
                          darkTooltip: CustomerL10n.tr('تاریک', langCode),
                          onChanged: _handleDarkChange,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIconBadge({
    required bool isDark,
    required IconData icon,
    required Color iconColor,
    required List<Color> gradientColors,
    required Color borderColor,
    Key? iconKey,
    bool animateIcon = false,
  }) {
    final iconWidget = Icon(icon, key: iconKey, color: iconColor, size: 20);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradientColors,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Center(
        child: animateIcon
            ? AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                transitionBuilder: (child, animation) => ScaleTransition(
                  scale: animation,
                  child: FadeTransition(opacity: animation, child: child),
                ),
                child: iconWidget,
              )
            : iconWidget,
      ),
    );
  }
}

class _LanguageTile extends StatelessWidget {
  const _LanguageTile({
    required this.choice,
    required this.label,
    required this.isSelected,
    required this.isDark,
    required this.onTap,
  });

  final _LanguageChoice choice;
  final String label;
  final bool isSelected;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final selectedBg = isDark
        ? Color.alphaBlend(
            _ProfilePreferencesCardState._brandGold.withValues(alpha: 0.11),
            RC.darkCard,
          )
        : Colors.white;
    final unselectedBg = isDark
        ? RC.darkCard.withValues(alpha: 0.55)
        : Colors.white.withValues(alpha: 0.65);

    final borderColor = isSelected
        ? (isDark
              ? _ProfilePreferencesCardState._brandGold
              : _ProfilePreferencesCardState._brandAmber)
        : (isDark
              ? RC.darkBorder.withValues(alpha: 0.55)
              : const Color(0xFFE2E8F0).withValues(alpha: 0.75));

    final badgeBg = isSelected
        ? _ProfilePreferencesCardState._brandGold
        : (isDark ? RC.darkRaised : const Color(0xFFEEF2F6));
    final badgeFg = isSelected
        ? _ProfilePreferencesCardState._brandInk
        : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B));

    final labelColor = isSelected
        ? (isDark
              ? const Color(0xFFFDE68A)
              : _ProfilePreferencesCardState._brandAmberText)
        : (isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155));

    return Semantics(
      button: true,
      selected: isSelected,
      label: label,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          key: ValueKey('preferences_lang_${choice.code}'),
          onTap: onTap,
          borderRadius: BorderRadius.circular(13),
          splashColor: _ProfilePreferencesCardState._brandAmber.withValues(
            alpha: 0.14,
          ),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            decoration: BoxDecoration(
              color: isSelected ? selectedBg : unselectedBg,
              borderRadius: BorderRadius.circular(13),
              border: Border.all(
                color: borderColor,
                width: isSelected ? 1.6 : 1,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color:
                            (isDark
                                    ? _ProfilePreferencesCardState._brandGold
                                    : _ProfilePreferencesCardState._brandAmber)
                                .withValues(alpha: isDark ? 0.14 : 0.16),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ]
                  : null,
            ),
            child: Stack(
              children: [
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 11,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: badgeBg,
                            borderRadius: BorderRadius.circular(7),
                          ),
                          child: Text(
                            choice.badge,
                            style: TextStyle(
                              fontFamily:
                                  _ProfilePreferencesCardState._fontFamily,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.6,
                              color: badgeFg,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            label,
                            maxLines: 1,
                            style: TextStyle(
                              fontFamily:
                                  _ProfilePreferencesCardState._fontFamily,
                              fontSize: 13,
                              fontWeight: isSelected
                                  ? FontWeight.w800
                                  : FontWeight.w600,
                              color: labelColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                PositionedDirectional(
                  top: 5,
                  end: 5,
                  child: IgnorePointer(
                    child: AnimatedScale(
                      scale: isSelected ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutBack,
                      child: AnimatedOpacity(
                        opacity: isSelected ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 160),
                        child: Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            color: isDark
                                ? _ProfilePreferencesCardState._brandGold
                                : _ProfilePreferencesCardState._brandAmber,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.check_rounded,
                            size: 11,
                            color: isDark
                                ? _ProfilePreferencesCardState._brandInk
                                : Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ThemeSegmentedToggle extends StatelessWidget {
  const _ThemeSegmentedToggle({
    required this.isDark,
    required this.lightTooltip,
    required this.darkTooltip,
    required this.onChanged,
  });

  final bool isDark;
  final String lightTooltip;
  final String darkTooltip;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final trackBg = isDark ? RC.darkPage : const Color(0xFFF1F5F9);
    final trackBorder = isDark ? RC.darkBorder : const Color(0xFFE2E8F0);
    final thumbBg = isDark ? const Color(0xFF28354E) : Colors.white;
    final thumbBorder = isDark
        ? _ProfilePreferencesCardState._brandGold.withValues(alpha: 0.48)
        : const Color(0xFFFDE68A);

    return Container(
      width: 88,
      height: 38,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: trackBg,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: trackBorder),
      ),
      child: Stack(
        children: [
          AnimatedAlign(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            alignment: isDark
                ? AlignmentDirectional.centerEnd
                : AlignmentDirectional.centerStart,
            child: FractionallySizedBox(
              widthFactor: 0.5,
              heightFactor: 1.0,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutCubic,
                decoration: BoxDecoration(
                  color: thumbBg,
                  borderRadius: BorderRadius.circular(9.5),
                  border: Border.all(color: thumbBorder, width: 0.9),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha: isDark ? 0.30 : 0.08,
                      ),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: Tooltip(
                  message: lightTooltip,
                  child: GestureDetector(
                    key: const ValueKey('preferences_theme_light'),
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onChanged(false),
                    child: Center(
                      child: Icon(
                        Icons.light_mode_rounded,
                        size: 18,
                        color: !isDark
                            ? const Color(0xFFD97706)
                            : const Color(0xFF64748B),
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Tooltip(
                  message: darkTooltip,
                  child: GestureDetector(
                    key: const ValueKey('preferences_theme_dark'),
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onChanged(true),
                    child: Center(
                      child: Icon(
                        Icons.dark_mode_rounded,
                        size: 17,
                        color: isDark
                            ? _ProfilePreferencesCardState._brandGold
                            : const Color(0xFF94A3B8),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
