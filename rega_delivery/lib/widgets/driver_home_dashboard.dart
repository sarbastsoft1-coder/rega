import 'package:flutter/material.dart';

import '../rega_colors.dart';
import '../rega_i18n.dart';
import '../rega_mobile.dart';

/// Idle home: full-bleed map with metrics pill + compact bottom sheet.
class DriverHomeDashboard extends StatelessWidget {
  const DriverHomeDashboard({
    super.key,
    required this.mapChild,
    required this.isOnline,
    required this.onlineBusy,
    required this.todayEarningsLabel,
    required this.completedCount,
    required this.incomingCount,
    required this.nearbyTitle,
    required this.onToggleOnline,
    required this.onOpenIncoming,
    required this.onOpenOrders,
    required this.todayEarningsCaption,
    required this.completedCaption,
    required this.offlineLabel,
    required this.waitingLabel,
    required this.acceptLabel,
    required this.ordersLabel,
    required this.goOnlineLabel,
  });

  final Widget mapChild;
  final bool isOnline;
  final bool onlineBusy;
  final String todayEarningsLabel;
  final int completedCount;
  final int incomingCount;
  final String nearbyTitle;
  final VoidCallback onToggleOnline;
  final VoidCallback onOpenIncoming;
  final VoidCallback onOpenOrders;
  final String todayEarningsCaption;
  final String completedCaption;
  final String offlineLabel;
  final String waitingLabel;
  final String acceptLabel;
  final String ordersLabel;
  final String goOnlineLabel;

  @override
  Widget build(BuildContext context) {
    final padH = RegaResponsive.pagePadding(context);
    final phone = RegaResponsive.isPhone(context);
    final hasNearby = incomingCount > 0;

    final String statusTitle;
    final String ctaLabel;
    final IconData statusIcon;
    final VoidCallback? onCta;
    final VoidCallback? onRowTap;

    if (!isOnline) {
      statusTitle = offlineLabel;
      ctaLabel = goOnlineLabel;
      statusIcon = Icons.wifi_off_rounded;
      onCta = onlineBusy ? null : onToggleOnline;
      onRowTap = onlineBusy ? null : onToggleOnline;
    } else if (hasNearby) {
      statusTitle = nearbyTitle;
      ctaLabel = acceptLabel;
      statusIcon = Icons.storefront_rounded;
      onCta = onOpenIncoming;
      onRowTap = onOpenIncoming;
    } else {
      statusTitle = waitingLabel;
      ctaLabel = ordersLabel;
      statusIcon = Icons.delivery_dining_rounded;
      onCta = onOpenOrders;
      onRowTap = onOpenOrders;
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(child: mapChild),

        // Metrics pill — mirrors ETA/distance card language on the live map.
        Positioned(
          top: 58,
          left: padH,
          right: padH,
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: RegaResponsive.dialogMaxWidth(context, cap: 560),
              ),
              child: Material(
                color: RC.bg(Colors.white),
                elevation: 5,
                shadowColor: Colors.black26,
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: phone ? 14 : 18,
                    vertical: phone ? 10 : 12,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _metricCell(
                          icon: Icons.payments_rounded,
                          caption: todayEarningsCaption,
                          value: todayEarningsLabel,
                          phone: phone,
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 28,
                        color: RC.bg(const Color(0xFFE2E8F0)),
                      ),
                      Expanded(
                        child: _metricCell(
                          icon: Icons.check_circle_outline_rounded,
                          caption: completedCaption,
                          value: '$completedCount',
                          phone: phone,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),

        // Compact bottom sheet — store row + primary CTA.
        Positioned(
          left: padH,
          right: padH,
          bottom: 12,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Material(
                color: RC.bg(Colors.white),
                elevation: 10,
                shadowColor: Colors.black26,
                borderRadius: BorderRadius.circular(22),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: RC.bg(const Color(0xFFCBD5E1)),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 12),
                      InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: onRowTap,
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: const Color(0xFFDCFCE7),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                statusIcon,
                                color: const Color(0xFF16A34A),
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                tx(statusTitle),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: RC.fg(const Color(0xFF0F172A)),
                                  fontWeight: FontWeight.w900,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            Icon(
                              Icons.chevron_right_rounded,
                              color: RC.fg(const Color(0xFF16A34A)),
                              size: 28,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF16A34A),
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: const Color(0xFF86EFAC),
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(28),
                            ),
                          ),
                          onPressed: onCta,
                          icon: Icon(
                            !isOnline
                                ? Icons.power_settings_new_rounded
                                : hasNearby
                                    ? Icons.check_rounded
                                    : Icons.list_alt_rounded,
                            size: 20,
                          ),
                          label: Text(
                            tx(ctaLabel),
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 15,
                            ),
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
      ],
    );
  }

  Widget _metricCell({
    required IconData icon,
    required String caption,
    required String value,
    required bool phone,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: phone ? 16 : 18,
              color: RC.fg(const Color(0xFF64748B)),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                tx(caption),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: RC.fg(const Color(0xFF64748B)),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          tx(value),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: RC.fg(const Color(0xFF0F172A)),
            fontSize: phone ? 15 : 16,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}
