import 'package:flutter/material.dart';

import '../rega_colors.dart';
import '../rega_i18n.dart';

/// Rich accept/decline offer card (30s timer) — matches the driver demo flow.
class IncomingOrderOffer extends StatelessWidget {
  const IncomingOrderOffer({
    super.key,
    required this.orderIdLabel,
    required this.merchant,
    required this.merchantAddress,
    required this.customer,
    required this.customerAddress,
    required this.deliveryFeeLabel,
    required this.totalLabel,
    required this.secondsLeft,
    required this.totalSeconds,
    required this.onAccept,
    required this.onDecline,
    required this.acceptLabel,
    required this.declineLabel,
    required this.pickupLabel,
    required this.dropoffLabel,
    required this.feeCaption,
    required this.totalCaption,
    required this.noteCaption,
    this.distanceLabel,
    this.note,
    this.items = const [],
    this.busy = false,
  });

  final String orderIdLabel;
  final String merchant;
  final String merchantAddress;
  final String customer;
  final String customerAddress;
  final String deliveryFeeLabel;
  final String totalLabel;
  final String? distanceLabel;
  final String? note;
  final List<({String name, int qty, String price})> items;
  final int secondsLeft;
  final int totalSeconds;
  final VoidCallback onAccept;
  final VoidCallback onDecline;
  final String acceptLabel;
  final String declineLabel;
  final String pickupLabel;
  final String dropoffLabel;
  final String feeCaption;
  final String totalCaption;
  final String noteCaption;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final progress = totalSeconds <= 0
        ? 0.0
        : (secondsLeft / totalSeconds).clamp(0.0, 1.0);
    final urgent = secondsLeft <= 10;
    final mm = (secondsLeft ~/ 60).toString().padLeft(2, '0');
    final ss = (secondsLeft % 60).toString().padLeft(2, '0');

    return Material(
      elevation: 28,
      shadowColor: Colors.black54,
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(maxHeight: 520),
        decoration: BoxDecoration(
          color: RC.bg(Colors.white),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: urgent
                ? const Color(0xFFF97316)
                : const Color(0xFF16A34A),
            width: urgent ? 1.8 : 1.4,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: 4,
              decoration: BoxDecoration(
                color: urgent
                    ? const Color(0xFFF97316)
                    : const Color(0xFF16A34A),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Directionality(
                            textDirection: TextDirection.ltr,
                            child: Text(
                              orderIdLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                                color: RC.fg(const Color(0xFF0F172A)),
                              ),
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: urgent
                                ? const Color(0xFFFFEDD5)
                                : const Color(0xFFDCFCE7),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  value: progress,
                                  strokeWidth: 2.2,
                                  backgroundColor: Colors.white54,
                                  color: urgent
                                      ? const Color(0xFFEA580C)
                                      : const Color(0xFF16A34A),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '$mm:$ss',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                  color: urgent
                                      ? const Color(0xFFC2410C)
                                      : const Color(0xFF15803D),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        if (distanceLabel != null &&
                            distanceLabel!.isNotEmpty) ...[
                          _metaChip(
                            Icons.route_rounded,
                            distanceLabel!,
                          ),
                          const SizedBox(width: 8),
                        ],
                        Expanded(
                          child: _metaChip(
                            Icons.payments_outlined,
                            '$feeCaption: $deliveryFeeLabel',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _placeBlock(
                      icon: Icons.storefront_rounded,
                      label: pickupLabel,
                      title: merchant,
                      subtitle: merchantAddress,
                      tint: const Color(0xFFDCFCE7),
                      iconColor: const Color(0xFF16A34A),
                    ),
                    const SizedBox(height: 8),
                    _placeBlock(
                      icon: Icons.home_outlined,
                      label: dropoffLabel,
                      title: customer,
                      subtitle: customerAddress,
                      tint: const Color(0xFFEFF6FF),
                      iconColor: const Color(0xFF2563EB),
                    ),
                    if (note != null && note!.trim().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: RC.bg(const Color(0xFFF1F5F9)),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          tx('$noteCaption: ${note!.trim()}'),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: RC.fg(const Color(0xFF475569)),
                          ),
                        ),
                      ),
                    ],
                    if (items.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      ...items.map(
                        (it) => Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  tx('${it.qty}× ${it.name}'),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                    color: RC.fg(const Color(0xFF1E293B)),
                                  ),
                                ),
                              ),
                              Text(
                                tx(it.price),
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w800,
                                  color: RC.fg(const Color(0xFF0F172A)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Text(
                          tx(totalCaption),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: RC.fg(const Color(0xFF64748B)),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          tx(totalLabel),
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF16A34A),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFDC2626),
                        side: const BorderSide(
                          color: Color(0xFFFECACA),
                          width: 1.4,
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: busy ? null : onDecline,
                      child: Text(
                        tx(declineLabel),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF16A34A),
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: const Color(0xFF86EFAC),
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: busy ? null : onAccept,
                      child: busy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              tx(acceptLabel),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _metaChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: RC.bg(const Color(0xFFF8FAFC)),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: RC.bg(const Color(0xFFE2E8F0))),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: RC.fg(const Color(0xFF64748B))),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              tx(text),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                color: RC.fg(const Color(0xFF334155)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _placeBlock({
    required IconData icon,
    required String label,
    required String title,
    required String subtitle,
    required Color tint,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: RC.bg(Colors.white),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: RC.bg(const Color(0xFFE2E8F0))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: RC.bg(tint),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 15, color: iconColor),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tx(label),
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    color: RC.fg(const Color(0xFF94A3B8)),
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  tx(title),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: RC.fg(const Color(0xFF0F172A)),
                  ),
                ),
                if (subtitle.trim().isNotEmpty)
                  Text(
                    tx(subtitle),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: RC.fg(const Color(0xFF64748B)),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
