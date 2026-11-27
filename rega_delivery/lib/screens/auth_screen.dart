import 'package:flutter/material.dart';

import '../blocked_account.dart';
import '../driver_api_service.dart';
import '../driver_shell_i18n.dart';
import '../iraq_phone_formatter.dart';
import '../rega_colors.dart';
import '../rega_i18n.dart';
import '../rega_mobile.dart';

// ---------------------------------------------------------
// شاشەی چوونەژوورەوە (Auth Screen) ڕێک وەک وێنەکە
// ---------------------------------------------------------

class AuthScreen extends StatefulWidget {
  final String currentLocale;
  final Future<void> Function(String phone) onLogin;

  const AuthScreen({
    super.key,
    required this.currentLocale,
    required this.onLogin,
  });

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final TextEditingController _authPhoneCtrl = TextEditingController();
  final TextEditingController _authPasswordCtrl = TextEditingController();
  bool _isAuthenticating = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _authPhoneCtrl.dispose();
    _authPasswordCtrl.dispose();
    super.dispose();
  }
  String t(String key) => tr(key, widget.currentLocale);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: RC.bg(Color(0xFFF1F5F9)),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: RegaResponsive.pagePadding(context),
              vertical: 40,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: RegaResponsive.dialogMaxWidth(context, cap: 440),
              ),
            child: Container(
              padding: EdgeInsets.all(
                RegaResponsive.scale(context, 32).clamp(18.0, 32.0),
              ),
              decoration: BoxDecoration(
                color: RC.bg(Colors.white),
                borderRadius: BorderRadius.circular(40),
                boxShadow: [
                  BoxShadow(
                    color: RC.bg(Colors.black).withOpacity(0.05),
                    blurRadius: 30,
                    offset: const Offset(0, 15),
                  ),
                ],
              ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Logo Image
                SizedBox(
                  height: 100,
                  child: Image.asset(
                    RC.isDark ? 'assets1/logo2_dark.png' : 'assets1/logo2.png',
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => Icon(Icons.delivery_dining_rounded, size: 80, color: RC.fg(Color(0xFF16A34A))),
                  ),
                ),
                const SizedBox(height: 32),

                // Phone Input Field
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t('phone_label'),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: RC.fg(Color(0xFF1E293B)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      decoration: BoxDecoration(
                        color: RC.bg(Colors.white),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: RC.bg(Color(0xFFE2E8F0)), width: 1.5),
                      ),
                      child: Directionality(
                        textDirection: TextDirection.ltr,
                        child: TextField(
                          controller: _authPhoneCtrl,
                          textDirection: TextDirection.ltr,
                          textAlign: TextAlign.left,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1),
                          keyboardType: TextInputType.phone,
                          inputFormatters: [IraqPhoneFormatter()],
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            suffixIcon: Icon(Icons.phone_android_rounded, color: RC.fg(Color(0xFF94A3B8))),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t('password_label').contains('password_label') ? 'وشەی تێپەڕ' : t('password_label'),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: RC.fg(Color(0xFF1E293B)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      decoration: BoxDecoration(
                        color: RC.bg(Colors.white),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: RC.bg(Color(0xFFE2E8F0)), width: 1.5),
                      ),
                      child: TextField(
                        controller: _authPasswordCtrl,
                        obscureText: _obscurePassword,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          prefixIcon: Icon(
                            Icons.lock_outline_rounded,
                            color: RC.fg(const Color(0xFF94A3B8)),
                          ),
                          suffixIcon: IconButton(
                            onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword,
                            ),
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              color: RC.fg(const Color(0xFF94A3B8)),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                // Continue Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: RC.bg(Color(0xFF16A34A)),
                      foregroundColor: RC.fg(Colors.white),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: _isAuthenticating
                        ? null
                        : () async {
                            setState(() => _isAuthenticating = true);
                            try {
                              final ok = await DriverApiService.instance.ensureAuthenticated(
                                phone: _authPhoneCtrl.text,
                                password: _authPasswordCtrl.text,
                              );
                              if (!mounted) return;
                              setState(() => _isAuthenticating = false);
                              if (ok) {
                                await widget.onLogin(_authPhoneCtrl.text.trim());
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(t('login_failed') == 'login_failed'
                                      ? 'چوونە ژوورەوە سەرکەوتوو نەبوو'
                                      : t('login_failed'))),
                                );
                              }
                            } on AccountBlockedException catch (e) {
                              if (!mounted) return;
                              setState(() => _isAuthenticating = false);
                              await BlockedAccountContacts.show(context, e);
                            }
                          },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.arrow_back_rounded, size: 20), // Back arrow is forward in RTL
                        const SizedBox(width: 12),
                        Text(
                          t('continue'),
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      ),
    ),
  );
  }
}
