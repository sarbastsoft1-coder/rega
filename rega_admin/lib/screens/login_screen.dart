import 'package:flutter/material.dart';
import '../core/api/api_client.dart';
import '../core/localization/app_strings.dart';
import '../core/theme/app_theme.dart';

class LoginScreen extends StatefulWidget {
  final ApiClient api;
  final String lang;
  final ValueChanged<String> onLangChanged;
  final ValueChanged<Map<String, dynamic>> onLoggedIn;

  const LoginScreen({
    super.key,
    required this.api,
    required this.lang,
    required this.onLangChanged,
    required this.onLoggedIn,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _idCtrl = TextEditingController(text: '07700000001');
  final _passCtrl = TextEditingController(text: 'password123');
  bool _obscure = true;
  bool _loading = false;
  bool? _serverHealthy;
  String? _error;

  @override
  void initState() {
    super.initState();
    _pingServer();
  }

  @override
  void dispose() {
    _idCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _pingServer() async {
    try {
      final res = await widget.api.checkHealth();
      if (mounted) {
        setState(() => _serverHealthy = res['db_connected'] == true);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _serverHealthy = false);
      }
    }
  }

  Future<void> _submit() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await widget.api.login(_idCtrl.text.trim(), _passCtrl.text);
      final user = data['user'] as Map<String, dynamic>? ?? {};
      widget.onLoggedIn(user);
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _showServerConfigDialog() {
    final urlCtrl = TextEditingController(text: widget.api.baseUrl);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ڕێکخستنی ناونیشانی سێرڤەر (API URL)'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: urlCtrl,
              textDirection: TextDirection.ltr,
              decoration: const InputDecoration(
                labelText: 'Laravel API Base URL',
                hintText: 'http://127.0.0.1:8001/api/v1',
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              children: [
                ActionChip(
                  label: const Text('Port 8001 (Default)'),
                  onPressed: () => urlCtrl.text = 'http://127.0.0.1:8001/api/v1',
                ),
                ActionChip(
                  label: const Text('Port 8000'),
                  onPressed: () => urlCtrl.text = 'http://127.0.0.1:8000/api/v1',
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(AppStrings.tr('cancel', widget.lang)),
          ),
          ElevatedButton(
            onPressed: () async {
              await widget.api.setBaseUrl(urlCtrl.text);
              if (ctx.mounted) Navigator.pop(ctx);
              _pingServer();
            },
            child: Text(AppStrings.tr('save', widget.lang)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 900;

    return Scaffold(
      backgroundColor: const Color(0xFF090D16),
      body: Row(
        children: [
          if (isWide)
            Expanded(
              flex: 6,
              child: Container(
                padding: const EdgeInsets.all(56),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF0F172A),
                      Color(0xFF111827),
                      Color(0xFF1E1B4B),
                    ],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Image.asset(
                            'assets/logo2.png',
                            width: 44,
                            height: 44,
                            errorBuilder: (_, _, _) => const Icon(Icons.bolt_rounded, color: RegaColors.gold, size: 36),
                          ),
                        ),
                        const SizedBox(width: 16),
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'REGA CENTRAL',
                              style: TextStyle(
                                color: RegaColors.gold,
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.4,
                              ),
                            ),
                            Text(
                              'Unified Ecosystem • Laravel 12 + PostgreSQL',
                              style: TextStyle(color: Colors.white70, fontSize: 12),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: RegaColors.gold.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(color: RegaColors.gold.withValues(alpha: 0.4)),
                          ),
                          child: const Text(
                            '⚡ سیستەمی یەکگرتووی کەلار — کڕیار • فرۆشیار • شۆفێر • ئەدمین',
                            style: TextStyle(color: RegaColors.gold, fontSize: 12, fontWeight: FontWeight.w700),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          AppStrings.tr('login_welcome', widget.lang),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 34,
                            fontWeight: FontWeight.w900,
                            height: 1.3,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          AppStrings.tr('login_subtitle', widget.lang),
                          style: const TextStyle(
                            color: Color(0xFFCBD5E1),
                            fontSize: 15,
                            height: 1.6,
                          ),
                        ),
                        const SizedBox(height: 36),
                        const Wrap(
                          spacing: 14,
                          runSpacing: 14,
                          children: [
                            _FeaturePill(icon: Icons.storage_rounded, label: 'PostgreSQL 18 Live'),
                            _FeaturePill(icon: Icons.pin_rounded, label: 'Dual 4-Digit PIN Security'),
                            _FeaturePill(icon: Icons.percent_rounded, label: '12% Commission Ledger'),
                            _FeaturePill(icon: Icons.two_wheeler_rounded, label: 'Driver KYC & COD Cash'),
                          ],
                        ),
                      ],
                    ),
                    const Text(
                      '© 2026 REGA Marketplace — Kalar, Kurdistan Region',
                      style: TextStyle(color: Colors.white38, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          Expanded(
            flex: 5,
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(28),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 40,
                          offset: const Offset(0, 18),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            InkWell(
                              onTap: _showServerConfigDialog,
                              borderRadius: BorderRadius.circular(20),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: (_serverHealthy == true
                                          ? RegaColors.emerald
                                          : (_serverHealthy == false ? RegaColors.crimson : Colors.amber))
                                      .withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.circle,
                                      size: 9,
                                      color: _serverHealthy == true
                                          ? RegaColors.emerald
                                          : (_serverHealthy == false ? RegaColors.crimson : Colors.amber),
                                    ),
                                    const SizedBox(width: 6),
                                    Flexible(
                                      child: Text(
                                        _serverHealthy == true
                                            ? 'PostgreSQL ئۆنلاینە'
                                            : (_serverHealthy == false ? 'سێرڤەر ئۆفلاینە (ڕێکخستن)' : 'پشکنین...'),
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                          color: Color(0xFF0F172A),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: ['ku', 'ar', 'en'].map((code) {
                                final active = widget.lang == code;
                                return Padding(
                                  padding: const EdgeInsets.only(left: 4),
                                  child: InkWell(
                                    onTap: () => widget.onLangChanged(code),
                                    borderRadius: BorderRadius.circular(8),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: active ? RegaColors.gold : const Color(0xFFF1F5F9),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        code == 'ku' ? 'کوردی' : (code == 'ar' ? 'عربي' : 'EN'),
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                          color: active ? const Color(0xFF0F172A) : const Color(0xFF64748B),
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        Center(
                          child: Image.asset(
                            'assets/logo2.png',
                            height: 68,
                            errorBuilder: (_, _, _) => const Icon(Icons.admin_panel_settings, size: 58),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          AppStrings.tr('app_title', widget.lang),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          AppStrings.tr('kalar_hub', widget.lang),
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        ),
                        const SizedBox(height: 24),
                        if (_error != null) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: RegaColors.crimson.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: RegaColors.crimson.withValues(alpha: 0.3)),
                            ),
                            child: Text(
                              _error!,
                              style: const TextStyle(color: RegaColors.crimson, fontSize: 12, fontWeight: FontWeight.w700),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                        TextField(
                          controller: _idCtrl,
                          style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.w700),
                          decoration: InputDecoration(
                            labelText: AppStrings.tr('identifier_label', widget.lang),
                            prefixIcon: const Icon(Icons.person_outline_rounded),
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: _passCtrl,
                          obscureText: _obscure,
                          onSubmitted: (_) => _submit(),
                          style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.w700),
                          decoration: InputDecoration(
                            labelText: AppStrings.tr('password_label', widget.lang),
                            prefixIcon: const Icon(Icons.lock_outline_rounded),
                            suffixIcon: IconButton(
                              onPressed: () => setState(() => _obscure = !_obscure),
                              icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          height: 52,
                          child: ElevatedButton.icon(
                            onPressed: _loading ? null : _submit,
                            icon: _loading
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2.4, color: Color(0xFF0F172A)),
                                  )
                                : const Icon(Icons.login_rounded),
                            label: Text(AppStrings.tr('sign_in', widget.lang)),
                          ),
                        ),
                        const SizedBox(height: 18),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'هەژمارە خێراکان بۆ تاقیکردنەوە:',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF475569)),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: () {
                                        setState(() {
                                          _idCtrl.text = '07700000001';
                                          _passCtrl.text = 'password123';
                                        });
                                      },
                                      child: const Text('بەڕێوەبەری گشتی', style: TextStyle(fontSize: 11.5)),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: () {
                                        setState(() {
                                          _idCtrl.text = '07700000002';
                                          _passCtrl.text = 'password123';
                                        });
                                      },
                                      child: const Text('ئۆپەرەیشن', style: TextStyle(fontSize: 11.5)),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeaturePill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _FeaturePill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: RegaColors.gold, size: 18),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

