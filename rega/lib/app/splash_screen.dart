import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../state/navigation_notifier.dart';
import '../state/session_notifier.dart';

/// Brand-first launch screen for the customer app (gold accent).
class CustomerSplashScreen extends StatefulWidget {
  const CustomerSplashScreen({super.key});

  static const String logoAsset = 'assets1/logo.png';
  static const Color accent = Color(0xFFFAC800);

  @override
  State<CustomerSplashScreen> createState() => _CustomerSplashScreenState();
}

class _CustomerSplashScreenState extends State<CustomerSplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _enter;
  late final AnimationController _glow;
  late final AnimationController _exit;
  late final Animation<double> _fade;
  late final Animation<double> _scale;
  late final Animation<double> _wordFade;
  late final Animation<double> _glowPulse;
  late final Animation<double> _exitFade;

  bool _minTimeDone = false;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    _enter = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _glow = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _exit = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );

    _fade = CurvedAnimation(parent: _enter, curve: const Interval(0.0, 0.55, curve: Curves.easeOut));
    _scale = Tween<double>(begin: 0.78, end: 1.0).animate(
      CurvedAnimation(parent: _enter, curve: const Interval(0.0, 0.7, curve: Curves.easeOutBack)),
    );
    _wordFade = CurvedAnimation(parent: _enter, curve: const Interval(0.45, 1.0, curve: Curves.easeOut));
    _glowPulse = Tween<double>(begin: 0.35, end: 0.75).animate(
      CurvedAnimation(parent: _glow, curve: Curves.easeInOut),
    );
    _exitFade = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _exit, curve: Curves.easeIn),
    );

    _enter.forward();
    Future<void>.delayed(const Duration(milliseconds: 1750), () {
      if (!mounted) return;
      _minTimeDone = true;
      _tryNavigate();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    context.watch<SessionNotifier>();
    _tryNavigate();
  }

  Future<void> _tryNavigate() async {
    if (_navigated || !_minTimeDone || !mounted) return;
    final session = context.read<SessionNotifier>();
    if (session.isRestoring) return;

    _navigated = true;
    await _exit.forward();
    if (!mounted) return;
    if (session.isLoggedIn) {
      context.go(NavigationNotifier.pathForIndex(0));
    } else {
      context.go('/login');
    }
  }

  @override
  void dispose() {
    _enter.dispose();
    _glow.dispose();
    _exit.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_enter, _glow, _exit]),
      builder: (context, _) {
        return Opacity(
          opacity: _exitFade.value,
          child: Scaffold(
            backgroundColor: const Color(0xFF0B1120),
            body: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -0.15),
                  radius: 1.05,
                  colors: [
                    CustomerSplashScreen.accent.withValues(alpha: 0.22 * _glowPulse.value),
                    const Color(0xFF0B1120),
                    const Color(0xFF020617),
                  ],
                  stops: const [0.0, 0.55, 1.0],
                ),
              ),
              child: SafeArea(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FadeTransition(
                        opacity: _fade,
                        child: ScaleTransition(
                          scale: _scale,
                          child: Container(
                            width: 168,
                            height: 168,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(36),
                              boxShadow: [
                                BoxShadow(
                                  color: CustomerSplashScreen.accent.withValues(
                                    alpha: 0.28 + 0.22 * _glowPulse.value,
                                  ),
                                  blurRadius: 36 + 18 * _glowPulse.value,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: Image.asset(
                              CustomerSplashScreen.logoAsset,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const ColoredBox(
                                color: Colors.black,
                                child: Center(
                                  child: Text(
                                    'R',
                                    style: TextStyle(
                                      color: CustomerSplashScreen.accent,
                                      fontSize: 72,
                                      fontWeight: FontWeight.w900,
                                      fontFamily: 'NotoKufiArabic',
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),
                      FadeTransition(
                        opacity: _wordFade,
                        child: const Text(
                          'REGA',
                          style: TextStyle(
                            fontFamily: 'NotoKufiArabic',
                            fontSize: 34,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 6,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      FadeTransition(
                        opacity: _wordFade,
                        child: Text(
                          'ڕێگا مارکێت',
                          style: TextStyle(
                            fontFamily: 'NotoKufiArabic',
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: CustomerSplashScreen.accent.withValues(alpha: 0.95),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
