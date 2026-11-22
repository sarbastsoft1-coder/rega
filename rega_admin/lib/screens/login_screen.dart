import 'package:flutter/material.dart';
import '../core/api/api_client.dart';
import '../core/localization/app_strings.dart';
import '../core/theme/admin_breakpoints.dart';
import '../core/theme/app_theme.dart';
import '../widgets/admin_top_header.dart';

import '../rega_i18n.dart';
import '../rega_colors.dart';
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
  final _idCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
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

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.sizeOf(context).width;
    final isWide = screenW >= AdminBreakpoints.tablet;

    return Scaffold(
      backgroundColor: RC.bg(Color(0xFF090D16)),
      body: Row(
        children: [
          if (isWide)
            Expanded(
              flex: 6,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      RC.bg(Color(0xFF0F172A)),
                      RC.bg(Color(0xFF111827)),
                      RC.bg(Color(0xFF1E1B4B)),
                    ],
                  ),
                ),
                child: LayoutBuilder(
                  builder: (context, leftConstraints) => SingleChildScrollView(
                    padding: EdgeInsets.all(screenW < 1100 ? 28 : 48),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: (leftConstraints.maxHeight -
                                (screenW < 1100 ? 56 : 96))
                            .clamp(0.0, double.infinity),
                      ),
                      child: IntrinsicHeight(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: RC.bg(Colors.white),
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
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        tx('REGA'),
                                        style: TextStyle(
                                          color: RegaColors.gold,
                                          fontSize: 22,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 1.4,
                                        ),
                                      ),
                                      Text(
                                        AppStrings.tr('login_brand_sub', widget.lang),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(color: RC.fg(Colors.white70), fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),
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
                                  child: Text(
                                    AppStrings.tr('login_ecosystem_badge', widget.lang),
                                    style: const TextStyle(color: RegaColors.gold, fontSize: 12, fontWeight: FontWeight.w700),
                                  ),
                                ),
                                const SizedBox(height: 24),
                                Text(
                                  AppStrings.tr('login_welcome', widget.lang),
                                  style: TextStyle(
                                    color: RC.fg(Colors.white),
                                    fontSize: screenW < 1100 ? 28 : 34,
                                    fontWeight: FontWeight.w900,
                                    height: 1.3,
                                  ),
                                ),
                                const SizedBox(height: 14),
                                Text(
                                  AppStrings.tr('login_subtitle', widget.lang),
                                  style: TextStyle(
                                    color: RC.fg(Color(0xFFCBD5E1)),
                                    fontSize: 15,
                                    height: 1.6,
                                  ),
                                ),
                                const SizedBox(height: 32),
                                Wrap(
                                  spacing: 14,
                                  runSpacing: 14,
                                  children: [
                                    _FeaturePill(icon: Icons.storage_rounded, label: AppStrings.tr('login_pill_db', widget.lang)),
                                    _FeaturePill(icon: Icons.pin_rounded, label: AppStrings.tr('login_pill_pin', widget.lang)),
                                    _FeaturePill(icon: Icons.percent_rounded, label: AppStrings.tr('login_pill_commission', widget.lang)),
                                    _FeaturePill(icon: Icons.two_wheeler_rounded, label: AppStrings.tr('login_pill_fleet', widget.lang)),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),
                            Text(
                              AppStrings.tr('login_footer', widget.lang),
                              style: TextStyle(color: RC.fg(Colors.white38), fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          Expanded(
            flex: 5,
            child: SafeArea(
              child: Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(MediaQuery.sizeOf(context).width < 600 ? 16 : 28),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Container(
                    padding: EdgeInsets.all(MediaQuery.sizeOf(context).width < 600 ? 20 : 32),
                    decoration: BoxDecoration(
                      color: RC.bg(Colors.white),
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: RC.bg(Colors.black).withValues(alpha: 0.3),
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
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: (_serverHealthy == true
                                        ? RegaColors.emerald
                                        : (_serverHealthy == false ? RegaColors.crimson : RC.bg(Colors.amber)))
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
                                        : (_serverHealthy == false ? RegaColors.crimson : RC.bg(Colors.amber)),
                                  ),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      tx(_serverHealthy == true
                                          ? AppStrings.tr('login_server_online', widget.lang)
                                          : (_serverHealthy == false
                                              ? AppStrings.tr('login_server_offline', widget.lang)
                                              : AppStrings.tr('login_server_checking', widget.lang))),
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        color: RC.fg(Color(0xFF0F172A)),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Wrap(
                              spacing: 4,
                              runSpacing: 6,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                ...['ku', 'ar', 'en'].map((code) {
                                  final active = widget.lang == code;
                                  return InkWell(
                                    onTap: () => widget.onLangChanged(code),
                                    borderRadius: BorderRadius.circular(8),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: active ? RegaColors.gold : RC.bg(Color(0xFFF1F5F9)),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        tx(code == 'ku' ? 'کوردی' : (code == 'ar' ? 'عربي' : 'EN')),
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                          color: active ? RC.bg(Color(0xFF0F172A)) : RC.bg(Color(0xFF64748B)),
                                        ),
                                      ),
                                    ),
                                  );
                                }),
                                const SizedBox(width: 4),
                                const AdminThemeToggle(),
                              ],
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
                          style: TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.w900,
                            color: RC.fg(Color(0xFF0F172A)),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          AppStrings.tr('kalar_hub', widget.lang),
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12, color: RC.fg(Color(0xFF64748B))),
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
                              tx(_error!),
                              style: const TextStyle(color: RegaColors.crimson, fontSize: 12, fontWeight: FontWeight.w700),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                        TextField(
                          controller: _idCtrl,
                          style: TextStyle(color: RC.fg(Color(0xFF0F172A)), fontWeight: FontWeight.w700),
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
                          style: TextStyle(color: RC.fg(Color(0xFF0F172A)), fontWeight: FontWeight.w700),
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
                                ? SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2.4, color: RC.bg(Color(0xFF0F172A))),
                                  )
                                : const Icon(Icons.login_rounded),
                            label: Text(AppStrings.tr('sign_in', widget.lang)),
                          ),
                        ),
                      ],
                    ),
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
        color: RC.bg(Colors.white).withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: RC.bg(Colors.white12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: RegaColors.gold, size: 18),
          const SizedBox(width: 8),
          Text(
            tx(label),
            style: TextStyle(color: RC.fg(Colors.white), fontSize: 12.5, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

