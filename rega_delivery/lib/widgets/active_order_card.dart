import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../driver_shell_i18n.dart';
import '../models/order_models.dart';
import '../rega_colors.dart';
import '../rega_i18n.dart';
import '../rega_mobile.dart';

class ActiveOrderCard extends StatefulWidget {
  final OrderModel order;
  final ValueChanged<OrderStatus> onUpdateStatus;
  final VoidCallback onRequestPinVerification;
  final VoidCallback? onClaimWaitingBonus;
  final VoidCallback? onRequestCancel;
  final VoidCallback? onClose;
  final String locale;

  const ActiveOrderCard({
    super.key,
    required this.order,
    required this.onUpdateStatus,
    required this.onRequestPinVerification,
    this.onClaimWaitingBonus,
    this.onRequestCancel,
    this.onClose,
    this.locale = 'ku',
  });

  @override
  State<ActiveOrderCard> createState() => _ActiveOrderCardState();
}

class _ActiveOrderCardState extends State<ActiveOrderCard> {
  bool _isItemsExpanded = false;

  String _t(String key) => tr(key, widget.locale);

  // دیاریکردنی قۆناغ: ئایا لە قۆناغی فرۆشیارە یان کڕیار
  bool get _isPickupStage =>
      widget.order.status == OrderStatus.driverAssigned ||
      widget.order.status == OrderStatus.driverArrivingPickup ||
      widget.order.status == OrderStatus.arrivedPickup;

  int get _stepIndex {
    switch (widget.order.status) {
      case OrderStatus.driverAssigned:
      case OrderStatus.driverArrivingPickup:
        return 0;
      case OrderStatus.arrivedPickup:
        return 1;
      case OrderStatus.pickedUp:
      case OrderStatus.onTheWay:
        return 2;
      case OrderStatus.arrivedCustomer:
      case OrderStatus.delivered:
        return 3;
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusConfig = _getStatusConfig(widget.order.status);
    final vSt = widget.order.vendorStatus;
    final isVendorReady = vSt == 'ready' || vSt == 'completed' || !_isPickupStage;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: RC.bg(Colors.white),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: RC.bg(const Color(0xFFE2E8F0))),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(0, 0, 0, 0.14),
            blurRadius: 28,
            offset: Offset(0, 10),
          ),
        ],
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ١. سەرپەڕەی کارت (Card Header): ژمارەی داواکاری + قۆناغ + دۆخی فرۆشگا + قازانجی شۆفێر
          Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: 5,
                  runSpacing: 5,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Directionality(
                        textDirection: TextDirection.ltr,
                        child: Text(
                          widget.order.displayOrderNumber.isNotEmpty
                              ? widget.order.displayOrderNumber
                              : formatOrderCode(widget.order.orderNumber),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: statusConfig.badgeBg,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: statusConfig.badgeBorder),
                      ),
                      child: Text(
                        tx(statusConfig.badgeLabel),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: statusConfig.badgeTextColor,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: isVendorReady
                            ? const Color(0xFFDCFCE7)
                            : const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        tx(isVendorReady
                            ? 'فرۆشگا: ئامادەیە'
                            : 'فرۆشگا: ئامادەکردن'),
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w900,
                          color: isVendorReady
                              ? const Color(0xFF15803D)
                              : const Color(0xFFB45309),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Text(
                tx('${formatMoney(widget.order.totalEarnings)} د.ع'),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF16A34A),
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: widget.onClose,
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: RC.bg(const Color(0xFFF1F5F9)),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: RC.fg(const Color(0xFF475569)),
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // ٢. هێڵی هەنگاوەکانی گەیاندن (4-Step Progress Bar)
          Row(
            children: List.generate(4, (i) {
              final done = i <= _stepIndex;
              return Expanded(
                child: Container(
                  height: 5,
                  margin: EdgeInsets.only(left: i == 0 ? 0 : 3, right: i == 3 ? 0 : 3),
                  decoration: BoxDecoration(
                    color: done
                        ? const Color(0xFF16A34A)
                        : RC.bg(const Color(0xFFE2E8F0)),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 10),

          // ٣. بەشی زانیاری فرۆشیار / کڕیار (styled-box)
          _buildEntityInfoBox(),
          const SizedBox(height: 10),

          // ٤. پوختەی پارەی وەرگرتن لە کڕیار + تێبینی کڕیار
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: RC.bg(const Color(0xFFF0FDF4)),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: RC.bg(const Color(0xFFBBF7D0))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    tx('بڕی کاشی وەرگرتن لە کڕیار (${widget.order.paymentMethod.toUpperCase()}):'),
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: RC.fg(const Color(0xFF166534)),
                    ),
                  ),
                ),
                Text(
                  tx('${formatMoney(widget.order.customerCashToCollect)} د.ع'),
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF15803D),
                  ),
                ),
              ],
            ),
          ),
          if (widget.order.customerNotes.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: RC.bg(const Color(0xFFFFFBEB)),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: RC.bg(const Color(0xFFFDE68A))),
              ),
              child: Text(
                tx('تێبینی کڕیار: ${widget.order.customerNotes}'),
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: RC.fg(const Color(0xFF92400E)),
                ),
              ),
            ),
          ],
          const SizedBox(height: 10),

          // ٥. بەشی کورتەی بەرهەمەکان (Accordion)
          _buildItemsAccordion(),
          const SizedBox(height: 10),

          // ٦. دوگمە یاریدەدەرەکان (پاداشتی چاوەڕوانی + کێشە/هەڵوەشاندنەوە)
          if (widget.onClaimWaitingBonus != null || widget.onRequestCancel != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  if (_isPickupStage && widget.onClaimWaitingBonus != null)
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFD97706),
                          side: const BorderSide(color: Color(0xFFFCD34D)),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: widget.onClaimWaitingBonus,
                        child: Text(
                          tx('پاداشتی چاوەڕوانی'),
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  if (_isPickupStage &&
                      widget.onClaimWaitingBonus != null &&
                      widget.onRequestCancel != null)
                    const SizedBox(width: 8),
                  if (widget.onRequestCancel != null)
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFDC2626),
                          side: const BorderSide(color: Color(0xFFFECACA)),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: widget.onRequestCancel,
                        child: Text(
                          tx('کێشە / هەڵوەشاندنەوە'),
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

          // ٧. دوگمەی سەرەکی بە ڕەنگی تایبەتی هەر قۆناغێک
          _buildPrimaryActionButton(statusConfig),
        ],
      ),
    );
  }

  // زانیاری شوێن و فرۆشیار/کڕیار
  Widget _buildEntityInfoBox() {
    final title = _isPickupStage ? _t('merchant_pickup') : _t('customer_dropoff');
    final name = _isPickupStage ? widget.order.merchantName : widget.order.customerName;
    final address = _isPickupStage ? widget.order.merchantAddress : widget.order.customerAddress;
    final lat = _isPickupStage ? widget.order.storeLat : widget.order.customerLat;
    final lng = _isPickupStage ? widget.order.storeLng : widget.order.customerLng;

    Widget infoBlock() {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tx(title),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: _isPickupStage ? RC.bg(Color(0xFFC2410C)) : RC.bg(Colors.grey.shade600),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            tx(name),
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: RC.fg(Color(0xFF14532D))),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            tx(address),
            style: TextStyle(
              fontSize: 10,
              color: _isPickupStage
                  ? RC.bg(const Color(0xFF9A3412))
                  : RC.bg(Colors.grey.shade600),
              fontWeight: FontWeight.w600,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (_isPickupStage) ...[
            const SizedBox(height: 4),
            Text(
              tx('GPS فرۆشگا: ${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}'),
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: RC.fg(Color(0xFFEA580C))),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      );
    }

  final contactActions = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildCircularIconButton(Icons.phone, () {
          final phone = _isPickupStage ? widget.order.merchantPhone : widget.order.customerPhone;
          launchUrl(Uri.parse('tel:$phone'));
        }),
        const SizedBox(width: 8),
        _buildCircularIconButton(Icons.navigation, () async {
          final uri = Uri.parse(
            'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving',
          );
          final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
          if (!ok && mounted) {
            _showActionToast('نەتوانرا نەخشە بکرێتەوە');
          }
        }),
      ],
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _isPickupStage ? RC.bg(Color(0xFFFFF7ED)) : RC.bg(Color(0xFFF8F9FA)),
        border: Border.all(color: _isPickupStage ? RC.bg(Color(0xFFFED7AA)) : RC.bg(Colors.grey.shade300)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < RegaBreakpoints.phone) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                infoBlock(),
                const SizedBox(height: 10),
                Align(alignment: AlignmentDirectional.centerEnd, child: contactActions),
              ],
            );
          }
          return Row(
            children: [
              Expanded(child: infoBlock()),
              const SizedBox(width: 8),
              contactActions,
            ],
          );
        },
      ),
    );
  }

  Widget _buildCircularIconButton(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: RC.bg(Color(0xFF00E676)),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 18, color: RC.fg(Colors.black)),
      ),
    );
  }

  // لیستی بەرهەمەکان (Accordion)
  Widget _buildItemsAccordion() {
    return Container(
      decoration: BoxDecoration(
        color: RC.bg(Color(0xFFF8FAFC)),
        border: Border.all(color: RC.bg(Color(0xFFE2E8F0))),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _isItemsExpanded = !_isItemsExpanded),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      tx(trFill('items_total', widget.locale, {
                        'count': '${widget.order.items.length}',
                        'total': formatMoney(widget.order.itemsTotal),
                      })),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: RC.fg(Color(0xFF1E293B))),
                    ),
                  ),
                  AnimatedRotation(
                    turns: _isItemsExpanded ? 0.5 : 0.0,
                    duration: const Duration(milliseconds: 250),
                    child: Icon(Icons.keyboard_arrow_down, size: 20, color: RC.fg(Color(0xFF64748B))),
                  ),
                ],
              ),
            ),
          ),
          if (_isItemsExpanded) ...[
            Container(height: 1, color: RC.bg(Color(0xFFE2E8F0))),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 180),
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: 4),
                itemCount: widget.order.items.length,
                separatorBuilder: (ctx, i) => Divider(height: 1, color: RC.bg(Color(0xFFF1F5F9)), indent: 16, endIndent: 16),
                itemBuilder: (ctx, i) {
                  final item = widget.order.items[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Flexible(
                                child: Text(
                                  tx(item.name),
                                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: RC.fg(Color(0xFF1E293B))),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                tx('× ${item.quantity}'),
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: RC.fg(Color(0xFFEF4444))),
                              ),
                            ],
                          ),
                        ),
                        Flexible(
                          child: Text(
                            tx('${formatMoney(item.price * item.quantity)} د.ع'),
                            textAlign: TextAlign.end,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: RC.fg(Color(0xFF16A34A))),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  // دوگمەی سەرەکی کارتی داواکاری
  Widget _buildPrimaryActionButton(_StatusConfig config) {
    return SizedBox(
      height: 42,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: config.buttonBg,
          foregroundColor: config.buttonTextColor,
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        onPressed: () {
          _handleNextStep();
        },
        child: Text(
          tx(config.buttonLabel),
          maxLines: 2,
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
        ),
      ),
    );
  }

  void _handleNextStep() {
    switch (widget.order.status) {
      case OrderStatus.driverAssigned:
        widget.onUpdateStatus(OrderStatus.driverArrivingPickup);
        break;
      case OrderStatus.driverArrivingPickup:
        widget.onUpdateStatus(OrderStatus.arrivedPickup);
        break;
      case OrderStatus.arrivedPickup:
        widget.onUpdateStatus(OrderStatus.pickedUp);
        break;
      case OrderStatus.pickedUp:
        widget.onUpdateStatus(OrderStatus.onTheWay);
        break;
      case OrderStatus.onTheWay:
        widget.onUpdateStatus(OrderStatus.arrivedCustomer);
        break;
      case OrderStatus.arrivedCustomer:
        widget.onRequestPinVerification();
        break;
      case OrderStatus.delivered:
        break;
    }
  }

  void _showActionToast(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tx(text)), duration: const Duration(seconds: 1)));
  }

  _StatusConfig _getStatusConfig(OrderStatus status) {
    switch (status) {
      case OrderStatus.driverAssigned:
        return _StatusConfig(
          badgeLabel: _t('badge_new_order'),
          badgeBg: RC.bg(Color(0xFFE8F5E9)),
          badgeBorder: RC.bg(Color(0xFFBBF7D0)),
          badgeTextColor: RC.bg(Color(0xFF16A34A)),
          buttonLabel: _t('btn_start_to_merchant'),
          buttonBg: RC.bg(Color(0xFF22C55E)),
          buttonTextColor: RC.bg(Colors.white),
          buttonIcon: Icons.arrow_back,
        );
      case OrderStatus.driverArrivingPickup:
        return _StatusConfig(
          badgeLabel: _t('badge_to_merchant'),
          badgeBg: RC.bg(Color(0xFFEFF6FF)),
          badgeBorder: RC.bg(Color(0xFFBFDBFE)),
          badgeTextColor: RC.bg(Color(0xFF2563EB)),
          buttonLabel: _t('btn_arrived_merchant'),
          buttonBg: RC.bg(Color(0xFF2563EB)),
          buttonTextColor: RC.bg(Colors.white),
          buttonIcon: Icons.store,
        );
      case OrderStatus.arrivedPickup:
        return _StatusConfig(
          badgeLabel: _t('badge_at_merchant'),
          badgeBg: RC.bg(Color(0xFFFFF7ED)),
          badgeBorder: RC.bg(Color(0xFFFED7AA)),
          badgeTextColor: RC.bg(Color(0xFFEA580C)),
          buttonLabel: _t('btn_picked_up'),
          buttonBg: RC.bg(Color(0xFFEA580C)),
          buttonTextColor: RC.bg(Colors.white),
          buttonIcon: Icons.shopping_bag,
        );
      case OrderStatus.pickedUp:
        return _StatusConfig(
          badgeLabel: _t('badge_picked'),
          badgeBg: RC.bg(Color(0xFFF5F3FF)),
          badgeBorder: RC.bg(Color(0xFFDDD6FE)),
          badgeTextColor: RC.bg(Color(0xFF7C3AED)),
          buttonLabel: _t('btn_start_to_customer'),
          buttonBg: RC.bg(Color(0xFF7C3AED)),
          buttonTextColor: RC.bg(Colors.white),
          buttonIcon: Icons.navigation,
        );
      case OrderStatus.onTheWay:
        return _StatusConfig(
          badgeLabel: _t('badge_to_customer'),
          badgeBg: RC.bg(Color(0xFFF0F9FF)),
          badgeBorder: RC.bg(Color(0xFFBAE6FD)),
          badgeTextColor: RC.bg(Color(0xFF0284C7)),
          buttonLabel: _t('btn_arrived_customer'),
          buttonBg: RC.bg(Color(0xFF0284C7)),
          buttonTextColor: RC.bg(Colors.white),
          buttonIcon: Icons.home,
        );
      case OrderStatus.arrivedCustomer:
        return _StatusConfig(
          badgeLabel: _t('badge_at_customer'),
          badgeBg: RC.bg(Color(0xFFECFDF5)),
          badgeBorder: RC.bg(Color(0xFFA7F3D0)),
          badgeTextColor: RC.bg(Color(0xFF059669)),
          buttonLabel: _t('btn_complete_pin'),
          buttonBg: RC.bg(Color(0xFF059669)),
          buttonTextColor: RC.bg(Colors.white),
          buttonIcon: Icons.check_circle,
        );
      case OrderStatus.delivered:
        return _StatusConfig(
          badgeLabel: _t('badge_delivered'),
          badgeBg: RC.bg(Color(0xFFE8F5E9)),
          badgeBorder: RC.bg(Color(0xFFBBF7D0)),
          badgeTextColor: RC.bg(Color(0xFF16A34A)),
          buttonLabel: _t('btn_completed'),
          buttonBg: RC.bg(Color(0xFF16A34A)),
          buttonTextColor: RC.bg(Colors.white),
          buttonIcon: Icons.check,
        );
    }
  }
}

class _StatusConfig {
  final String badgeLabel;
  final Color badgeBg;
  final Color badgeBorder;
  final Color badgeTextColor;
  final String buttonLabel;
  final Color buttonBg;
  final Color buttonTextColor;
  final IconData buttonIcon;

  _StatusConfig({
    required this.badgeLabel,
    required this.badgeBg,
    required this.badgeBorder,
    required this.badgeTextColor,
    required this.buttonLabel,
    required this.buttonBg,
    required this.buttonTextColor,
    required this.buttonIcon,
  });
}

// نەخشەی نەخشێندراوی تایبەت (Custom Map Painter)
// ---------------------------------------------------------

