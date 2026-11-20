import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../rega_colors.dart';
import '../rega_i18n.dart';
import '../state/locale_notifier.dart';
import 'onboarding_notifier.dart';

/// Amada-style first-launch flow: splash → language → location benefits.
class SplashOnboardingFlow extends StatefulWidget {
  const SplashOnboardingFlow({super.key, this.logoAssetPath = 'assets1/logo.png'});

  final String logoAssetPath;

  @override
  State<SplashOnboardingFlow> createState() => _SplashOnboardingFlowState();
}

class _SplashOnboardingFlowState extends State<SplashOnboardingFlow>
    with TickerProviderStateMixin {
  static const _brand = Color(0xFFFAC800);

  int _step = 0; // 0 splash, 1 language, 2 location
  bool _busy = false;
  late final AnimationController _splashFade;
  late final AnimationController _stepFade;
  Timer? _splashTimer;

  @override
  void initState() {
    super.initState();
    _splashFade = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();
    _stepFade = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
      value: 1,
    );
    _splashTimer = Timer(const Duration(milliseconds: 1800), () {
      if (mounted && _step == 0) _goTo(1);
    });
  }

  @override
  void dispose() {
    _splashTimer?.cancel();
    _splashFade.dispose();
    _stepFade.dispose();
    super.dispose();
  }

  Future<void> _goTo(int step) async {
    await _stepFade.reverse();
    if (!mounted) return;
    setState(() => _step = step);
    await _stepFade.forward();
  }

  Future<void> _finish() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await _requestLocationSoft();
      if (!mounted) return;
      await context.read<OnboardingNotifier>().complete();
      if (!mounted) return;
      context.go('/login');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Request OS location; never block onboarding if denied.
  Future<void> _requestLocationSoft() async {
    if (kIsWeb) {
      try {
        await Geolocator.requestPermission();
      } catch (_) {}
      return;
    }
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) {
        try {
          await Geolocator.openLocationSettings();
        } catch (_) {}
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<LocaleNotifier>();
    RegaI18n.setLang(locale.langCode);

    return Directionality(
      textDirection: locale.textDirection,
      child: Scaffold(
        backgroundColor: RC.bg(Colors.white),
        body: FadeTransition(
          opacity: _stepFade,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 280),
            child: switch (_step) {
              0 => KeyedSubtree(
                  key: const ValueKey('splash'),
                  child: _buildSplash(),
                ),
              1 => KeyedSubtree(
                  key: const ValueKey('lang'),
                  child: _buildLanguage(locale),
                ),
              _ => KeyedSubtree(
                  key: const ValueKey('loc'),
                  child: _buildLocation(),
                ),
            },
          ),
        ),
      ),
    );
  }

  Widget _buildSplash() {
    return GestureDetector(
      onTap: () => _goTo(1),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Container(color: RC.bg(const Color(0xFFF1F5F9))),
          ClipPath(
            clipper: const _SplashCurveClipper(),
            child: Container(color: RC.bg(_brand)),
          ),
          FadeTransition(
            opacity: _splashFade,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    height: 110,
                    child: Image.asset(
                      widget.logoAssetPath,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => Icon(
                        Icons.storefront_rounded,
                        size: 88,
                        color: RC.fg(Colors.white),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'REGA',
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                      color: RC.fg(Colors.white),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    tx('ڕێگا'),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: RC.fg(Colors.white).withValues(alpha: 0.92),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLanguage(LocaleNotifier locale) {
    final code = locale.langCode;
    return SafeArea(
      child: Column(
        children: [
          Expanded(
            flex: 5,
            child: Stack(
              fit: StackFit.expand,
              children: [
                ClipPath(
                  clipper: const _SplashCurveClipper(),
                  child: Container(color: RC.bg(_brand)),
                ),
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        height: 88,
                        child: Image.asset(
                          widget.logoAssetPath,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => Icon(
                            Icons.storefront_rounded,
                            size: 72,
                            color: RC.fg(Colors.white),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'REGA',
                        style: TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w900,
                          color: RC.fg(Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 4,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 8, 22, 20),
              child: Column(
                children: [
                  const Spacer(),
                  Text.rich(
                    TextSpan(
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: RC.fg(const Color(0xFF0F172A)),
                        height: 1.4,
                      ),
                      children: [
                        TextSpan(text: tx('بەخێر بێن بۆ ئەپی')),
                        const TextSpan(text: ' '),
                        TextSpan(
                          text: 'REGA',
                          style: TextStyle(color: RC.fg(_brand)),
                        ),
                      ],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 22),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _LangChip(
                        label: tx('کوردی'),
                        selected: code == 'ku',
                        onTap: () => locale.setLanguage('ku'),
                      ),
                      _LangChip(
                        label: tx('العربية'),
                        selected: code == 'ar',
                        onTap: () => locale.setLanguage('ar'),
                      ),
                      _LangChip(
                        label: 'English',
                        selected: code == 'en',
                        onTap: () => locale.setLanguage('en'),
                      ),
                    ],
                  ),
                  const Spacer(),
                  _PrimaryButton(
                    label: tx('بەردەوام بە'),
                    onPressed: () => _goTo(2),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocation() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: IconButton(
                onPressed: _busy ? null : _finish,
                icon: Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 18,
                  color: RC.fg(_brand),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              tx('لۆکەیشنەکەت کارا بکە تاوەکو بتوانین:'),
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: RC.fg(const Color(0xFF0F172A)),
                height: 1.35,
              ),
            ),
            const SizedBox(height: 18),
            _BenefitCard(
              icon: Icons.storefront_rounded,
              text: tx('فرۆشگاکانی شار و ناوچەکەت پیشان بدەین.'),
            ),
            const SizedBox(height: 12),
            _BenefitCard(
              icon: Icons.delivery_dining_rounded,
              text: tx('ستافی دلیڤەری داواکارییەکەت بگەیەنێتە شوێنەکەت.'),
            ),
            const SizedBox(height: 12),
            _BenefitCard(
              icon: Icons.percent_rounded,
              text: tx('نوێترین داشکاندن و ئۆفەرەکانی شارەکەت پێ پیشان بدەین.'),
            ),
            const Spacer(),
            _PrimaryButton(
              label: tx('بەردەوام بە'),
              busy: _busy,
              onPressed: _finish,
            ),
          ],
        ),
      ),
    );
  }
}

class _LangChip extends StatelessWidget {
  const _LangChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  static const _brand = Color(0xFFFAC800);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? RC.bg(_brand) : RC.bg(const Color(0xFFF1F5F9)),
      borderRadius: BorderRadius.circular(28),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(28),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.language_rounded,
                size: 18,
                color: selected ? RC.fg(Colors.black) : RC.fg(const Color(0xFF64748B)),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  color: selected ? RC.fg(Colors.black) : RC.fg(const Color(0xFF334155)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BenefitCard extends StatelessWidget {
  const _BenefitCard({required this.icon, required this.text});

  final IconData icon;
  final String text;

  static const _brand = Color(0xFFFAC800);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: RC.bg(Colors.white),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: RC.bg(Colors.black).withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: RC.bg(const Color(0xFFF1F5F9))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                height: 1.4,
                color: RC.fg(const Color(0xFF1E293B)),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: RC.bg(_brand).withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: RC.fg(const Color(0xFFB45309)), size: 24),
          ),
        ],
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.label,
    required this.onPressed,
    this.busy = false,
  });

  final String label;
  final VoidCallback onPressed;
  final bool busy;

  static const _brand = Color(0xFFFAC800);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: busy ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: RC.bg(_brand),
          foregroundColor: RC.fg(Colors.black),
          disabledBackgroundColor: RC.bg(_brand).withValues(alpha: 0.7),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        ),
        child: busy
            ? SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: RC.fg(Colors.black),
                ),
              )
            : Text(
                label,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
              ),
      ),
    );
  }
}

/// Yellow brand block with a soft upward curve into the white sheet.
class _SplashCurveClipper extends CustomClipper<Path> {
  const _SplashCurveClipper();

  @override
  Path getClip(Size size) {
    final path = Path();
    path.lineTo(0, size.height * 0.78);
    path.quadraticBezierTo(
      size.width * 0.5,
      size.height * 0.98,
      size.width,
      size.height * 0.78,
    );
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
