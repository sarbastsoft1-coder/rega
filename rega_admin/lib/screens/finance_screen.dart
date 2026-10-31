import 'package:flutter/material.dart';
import '../core/api/api_client.dart';
import '../core/localization/app_strings.dart';
import '../core/theme/app_theme.dart';
import '../widgets/common_widgets.dart';

class FinanceScreen extends StatefulWidget {
  final ApiClient api;
  final String lang;

  const FinanceScreen({super.key, required this.api, required this.lang});

  @override
  State<FinanceScreen> createState() => _FinanceScreenState();
}

class _FinanceScreenState extends State<FinanceScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;
  bool _loading = true;
  String? _error;
  Map<String, dynamic> _finance = {};
  List<dynamic> _payouts = [];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        widget.api.getFinanceSummary(),
        widget.api.getPayouts(),
      ]);
      if (mounted) {
        setState(() {
          _finance = results[0] as Map<String, dynamic>;
          _payouts = results[1] as List<dynamic>;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showSnack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: error ? RegaColors.crimson : RegaColors.emeraldDark,
      ),
    );
  }

  void _showQuickSettlementDialog({
    required String title,
    required String recipientType,
    required String direction,
    int? storeId,
    int? userId,
    required int suggestedAmount,
  }) {
    final amtCtrl = TextEditingController(text: suggestedAmount > 0 ? suggestedAmount.toString() : '10000');
    final notesCtrl = TextEditingController();
    String method = 'cash';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(title),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: amtCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'بڕی پارە بە دینار (د.ع) *'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: method,
                  decoration: const InputDecoration(labelText: 'شێوازی پارەدان'),
                  items: const [
                    DropdownMenuItem(value: 'cash', child: Text('نەختینە (Cash)')),
                    DropdownMenuItem(value: 'fib', child: Text('FIB — بانکی یەکەمی عێراقی')),
                    DropdownMenuItem(value: 'fastpay', child: Text('FastPay')),
                    DropdownMenuItem(value: 'bank_transfer', child: Text('حەواڵەی بانکی')),
                  ],
                  onChanged: (v) => setDialogState(() => method = v ?? 'cash'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notesCtrl,
                  decoration: const InputDecoration(labelText: 'تێبینی ژمێریاری'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(AppStrings.tr('cancel', widget.lang))),
            ElevatedButton(
              onPressed: () async {
                final amount = int.tryParse(amtCtrl.text.trim()) ?? 0;
                if (amount < 250) return;
                Navigator.pop(ctx);
                try {
                  await widget.api.createPayout({
                    'recipient_type': recipientType,
                    'direction': direction,
                    'store_id': ?storeId,
                    'user_id': ?userId,
                    'amount': amount,
                    'payment_method': method,
                    'status': 'completed',
                    'notes': notesCtrl.text.trim(),
                  });
                  _showSnack('مامەڵەی دارایی تۆمارکرا و باڵانس نوێکرایەوە ✅');
                  _load();
                } catch (e) {
                  _showSnack(e.toString(), error: true);
                }
              },
              child: const Text('تەواوکردن و تۆمارکردن'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final summary = _finance['summary'] as Map<String, dynamic>? ?? {};
    final storesLedger = _finance['stores_ledger'] as List<dynamic>? ?? [];
    final driversLedger = _finance['drivers_ledger'] as List<dynamic>? ?? [];

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
          child: Column(
            children: [
              SectionHeader(
                title: AppStrings.tr('nav_finance', widget.lang),
                subtitle: 'ژمێریاری ناوەندی: کۆمیسیۆنی ١٢٪، شایستەی فرۆشگاکان و وەرگرتنەوەی کاشی شۆفێران (COD)',
              ),
              const SizedBox(height: 16),
              LayoutBuilder(
                builder: (context, constraints) {
                  final cols = constraints.maxWidth >= 1000 ? 4 : 2;
                  return GridView.count(
                    crossAxisCount: cols,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                    childAspectRatio: 2.1,
                    children: [
                      StatKpiCard(
                        title: 'کۆی گشتی کۆمیسیۆنی ڕێگا',
                        value: formatIqd(summary['total_platform_commission'] as num?, lang: widget.lang),
                        icon: Icons.trending_up_rounded,
                        accentColor: RegaColors.emeraldDark,
                      ),
                      StatKpiCard(
                        title: 'باڵانسی پاکتاونەکراوی فرۆشگاکان',
                        value: formatIqd(summary['unsettled_vendor_wallets'] as num?, lang: widget.lang),
                        icon: Icons.storefront_rounded,
                        accentColor: RegaColors.blue,
                      ),
                      StatKpiCard(
                        title: 'پارەی کاشی کۆکراوە لای شۆفێران (COD)',
                        value: formatIqd(summary['driver_cod_cash_held'] as num?, lang: widget.lang),
                        icon: Icons.payments_rounded,
                        accentColor: RegaColors.purple,
                      ),
                      StatKpiCard(
                        title: 'کۆی پاکتاوکراوی فرۆشیار و شۆفێر',
                        value: formatIqd(summary['completed_partner_payouts'] as num?, lang: widget.lang),
                        icon: Icons.check_circle_outline_rounded,
                        accentColor: RegaColors.goldDark,
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
        TabBar(
          controller: _tabCtrl,
          tabs: [
            Tab(text: '📜 تۆماری مامەڵەکان (${_payouts.length})'),
            Tab(text: '🏪 حساباتی فرۆشگاکان (${storesLedger.length})'),
            Tab(text: '🏍️ شۆفێران و COD (${driversLedger.length})'),
          ],
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? ErrorRetryView(message: _error!, onRetry: _load)
                  : TabBarView(
                      controller: _tabCtrl,
                      children: [
                        // Payouts History
                        ListView.separated(
                          padding: const EdgeInsets.all(24),
                          itemCount: _payouts.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 10),
                          itemBuilder: (_, idx) {
                            final p = _payouts[idx] as Map<String, dynamic>;
                            final u = p['user'] as Map<String, dynamic>?;
                            final st = p['store'] as Map<String, dynamic>?;
                            final isCod = p['direction'] == 'cod_collection_from_driver';
                            final status = p['status']?.toString() ?? 'pending';

                            return Card(
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: (isCod ? RegaColors.purple : RegaColors.emerald).withValues(alpha: 0.14),
                                  child: Icon(
                                    isCod ? Icons.call_received_rounded : Icons.call_made_rounded,
                                    color: isCod ? RegaColors.purple : RegaColors.emeraldDark,
                                  ),
                                ),
                                title: Text(
                                  '${p['reference_code']} • ${st?['name_ku'] ?? u?['name'] ?? ''}',
                                  style: const TextStyle(fontWeight: FontWeight.w800),
                                ),
                                subtitle: Text(
                                  '${isCod ? 'وەرگرتنەوەی کاشی COD لە شۆفێر' : 'پێدانی شایستەی دارایی'} (${p['payment_method']}) — ${p['notes'] ?? ''}',
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      formatIqd(p['amount'] as num?, lang: widget.lang),
                                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
                                    ),
                                    const SizedBox(width: 10),
                                    StatusBadge(status: status, lang: widget.lang),
                                    if (status == 'pending') ...[
                                      const SizedBox(width: 8),
                                      ElevatedButton(
                                        onPressed: () async {
                                          await widget.api.updatePayoutStatus(p['id'] as int, 'completed');
                                          _showSnack('مامەڵەکە پەسەند و پاکتاو کرا ✅');
                                          _load();
                                        },
                                        child: const Text('پەسەندکردن'),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            );
                          },
                        ),

                        // Vendors Ledger
                        ListView.separated(
                          padding: const EdgeInsets.all(24),
                          itemCount: storesLedger.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 10),
                          itemBuilder: (_, idx) {
                            final s = storesLedger[idx] as Map<String, dynamic>;
                            final wallet = (s['wallet_balance'] as num?)?.toInt() ?? 0;
                            return Card(
                              child: ListTile(
                                title: Text(s['name_ku']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.w900)),
                                subtitle: Text(
                                  'کۆی فرۆش: ${formatIqd(s['gross_sales'] as num?, lang: widget.lang)}  •  کۆمیسیۆنی ڕێگا (${s['commission_rate']}%): ${formatIqd(s['commission_paid'] as num?, lang: widget.lang)}',
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'باڵانس: ${formatIqd(wallet, lang: widget.lang)}',
                                      style: const TextStyle(fontWeight: FontWeight.w900, color: RegaColors.blue),
                                    ),
                                    const SizedBox(width: 12),
                                    ElevatedButton(
                                      onPressed: () => _showQuickSettlementDialog(
                                        title: 'پاکتاوکردنی باڵانسی ${s['name_ku']}',
                                        recipientType: 'vendor',
                                        direction: 'payout_to_partner',
                                        storeId: s['id'] as int,
                                        suggestedAmount: wallet,
                                      ),
                                      child: const Text('پێدانی شایستە'),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),

                        // Drivers COD & Wallet Ledger
                        ListView.separated(
                          padding: const EdgeInsets.all(24),
                          itemCount: driversLedger.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 10),
                          itemBuilder: (_, idx) {
                            final dp = driversLedger[idx] as Map<String, dynamic>;
                            final u = dp['user'] as Map<String, dynamic>? ?? {};
                            final cod = (dp['cash_collected_hand'] as num?)?.toInt() ?? 0;
                            final wallet = (dp['wallet_balance'] as num?)?.toInt() ?? 0;

                            return Card(
                              child: ListTile(
                                title: Text(
                                  '${u['name'] ?? ''} (${dp['driver_code'] ?? ''})',
                                  style: const TextStyle(fontWeight: FontWeight.w900),
                                ),
                                subtitle: Text(
                                  'شایستەی شۆفێر: ${formatIqd(wallet, lang: widget.lang)}  •  کاشی لای شۆفێر (COD): ${formatIqd(cod, lang: widget.lang)}',
                                ),
                                trailing: Wrap(
                                  spacing: 8,
                                  children: [
                                    OutlinedButton(
                                      onPressed: () => _showQuickSettlementDialog(
                                        title: 'وەرگرتنەوەی کاشی COD لە ${u['name']}',
                                        recipientType: 'driver',
                                        direction: 'cod_collection_from_driver',
                                        userId: dp['user_id'] as int,
                                        suggestedAmount: cod,
                                      ),
                                      child: const Text('وەرگرتنەوەی COD'),
                                    ),
                                    ElevatedButton(
                                      onPressed: () => _showQuickSettlementDialog(
                                        title: 'پێدانی کرێی شۆفێر ${u['name']}',
                                        recipientType: 'driver',
                                        direction: 'payout_to_partner',
                                        userId: dp['user_id'] as int,
                                        suggestedAmount: wallet,
                                      ),
                                      child: const Text('پێدانی شایستە'),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
        ),
      ],
    );
  }
}

