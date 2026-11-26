import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'customer_api_service.dart';
import 'iraq_phone_formatter.dart';
import 'rega_colors.dart';
import 'rega_i18n.dart';
import 'rega_mobile.dart';
import 'services/customer_image_pick.dart';
import 'services/service_area.dart';

/// داواکاری ڕاستەوخۆ — full-screen form under the home pill button.
class DirectRequestScreen extends StatefulWidget {
  const DirectRequestScreen({
    super.key,
    this.initialPhone = '',
    this.initialAddress = '',
    this.deliveryLat,
    this.deliveryLng,
    this.onPickAddress,
  });

  final String initialPhone;
  final String initialAddress;

  /// Saved delivery pin — used for instant service-area check (no GPS wait).
  final double? deliveryLat;
  final double? deliveryLng;

  /// Opens the customer location picker; returns the chosen label (or null).
  final Future<String?> Function()? onPickAddress;

  @override
  State<DirectRequestScreen> createState() => _DirectRequestScreenState();
}

class _DirectRequestScreenState extends State<DirectRequestScreen> {
  final _subjectCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _subjectAddressCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();

  Uint8List? _imageBytes;
  String? _imageName;
  String? _uploadedImageUrl;
  bool _picking = false;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _phoneCtrl.text = IraqPhoneFormatter.format(widget.initialPhone);
    _subjectAddressCtrl.text = widget.initialAddress;
    _addressCtrl.text = widget.initialAddress;
  }

  @override
  void dispose() {
    _subjectCtrl.dispose();
    _notesCtrl.dispose();
    _subjectAddressCtrl.dispose();
    _addressCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage({required bool fromCamera}) async {
    if (_picking || _submitting) return;
    setState(() => _picking = true);
    try {
      final picked = await pickCustomerImage(fromCamera: fromCamera);
      if (picked == null || !mounted) return;
      setState(() {
        _imageBytes = picked.bytes;
        _imageName = picked.name;
        _uploadedImageUrl = null;
      });
    } catch (e) {
      if (!mounted) return;
      debugPrint('REGA direct-request image pick failed: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tx('نەتوانرا وێنە هەڵبژێردرێت'))),
      );
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _pickAddress() async {
    if (widget.onPickAddress == null) return;
    final label = await widget.onPickAddress!();
    if (!mounted || label == null || label.trim().isEmpty) return;
    setState(() {
      final place = label.trim();
      _addressCtrl.text = place;
      if (_subjectAddressCtrl.text.trim().isEmpty) {
        _subjectAddressCtrl.text = place;
      }
    });
  }

  void _openImagePreview(Uint8List bytes) {
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: RC.bg(Colors.black),
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          children: [
            InteractiveViewer(
              child: Center(
                child: Image.memory(
                  bytes,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      tx('نەتوانرا وێنە پیشان بدرێت'),
                      style: TextStyle(color: RC.fg(Colors.white), fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 4,
              right: 4,
              child: IconButton(
                onPressed: () => Navigator.pop(ctx),
                icon: Icon(Icons.close_rounded, color: RC.fg(Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (_submitting) return;
    final subject = _subjectCtrl.text.trim();
    final subjectAddress = _subjectAddressCtrl.text.trim();
    final mapAddress = _addressCtrl.text.trim();
    final address = subjectAddress.isNotEmpty ? subjectAddress : mapAddress;
    final phoneDigits = IraqPhoneFormatter.digitsOnly(_phoneCtrl.text);

    if (subject.isEmpty) {
      _toast(tx('تکایە ناوی بابەت بنووسە'));
      return;
    }
    if (address.isEmpty) {
      _toast(tx('تکایە ناونیشانی بابەت بنووسە'));
      return;
    }
    if (!IraqPhoneFormatter.isValidIraqMobile(phoneDigits)) {
      _toast(tx('ژمارەی مۆبایل دروست نییە'));
      return;
    }

    // Show spinner immediately — never hang on silent GPS before feedback.
    setState(() => _submitting = true);
    HapticFeedback.lightImpact();

    try {
      // Instant area check from saved pin only (no multi-second live GPS).
      final lat = widget.deliveryLat;
      final lng = widget.deliveryLng;
      if (lat != null && lng != null && !ServiceAreaGate.config.contains(lat, lng)) {
        if (!mounted) return;
        setState(() => _submitting = false);
        final allowed = await Navigator.of(context).push<bool>(
          MaterialPageRoute(
            fullscreenDialog: true,
            builder: (blockedCtx) => ServiceAreaBlockedScreen(
              onRetry: () async {
                final retry = await ServiceAreaGate.check(requestPermission: true);
                if (!blockedCtx.mounted) return;
                if (!retry.blocksApp) {
                  Navigator.of(blockedCtx).pop(true);
                }
              },
            ),
          ),
        );
        if (allowed != true || !mounted) return;
        setState(() => _submitting = true);
      }

      if (!CustomerApiService.instance.hasToken) {
        await CustomerApiService.instance.initToken();
      }
      if (!CustomerApiService.instance.hasToken) {
        throw Exception('تکایە دووبارە بچۆ ژوورەوە');
      }

      String? imageUrl = _uploadedImageUrl;
      if (_imageBytes != null && imageUrl == null) {
        final up = await CustomerApiService.instance.uploadDirectRequestImage(
          bytes: _imageBytes!,
          filename: _imageName ?? 'direct-request.jpg',
        );
        final resolved = RegaApiHost.resolveMediaUrl(up?['url']?.toString());
        imageUrl = resolved.isEmpty ? null : resolved;
        _uploadedImageUrl = imageUrl;
      } else if (imageUrl != null && imageUrl.isNotEmpty) {
        final resolved = RegaApiHost.resolveMediaUrl(imageUrl);
        imageUrl = resolved.isEmpty ? null : resolved;
      }

      await CustomerApiService.instance.submitDirectRequest(
        subject: subject,
        notes: _notesCtrl.text.trim(),
        address: address,
        phone: phoneDigits,
        imageUrl: imageUrl,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tx('داواکارییەکەت بە سەرکەوتوویی نێردرا')),
          backgroundColor: RC.bg(const Color(0xFF059669)),
        ),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      var msg = e.toString().replaceFirst('Exception: ', '');
      if (msg == 'login_required' || msg.contains('Unauthorized')) {
        msg = 'تکایە دووبارە بچۆ ژوورەوە';
      } else if (msg == 'upload_failed') {
        msg = 'بارکردنی وێنە سەرکەوتوو نەبوو';
      } else if (msg == 'direct_request_failed') {
        msg = 'ناردنی داواکاری سەرکەوتوو نەبوو';
      }
      _toast(tx(msg.isNotEmpty ? msg : 'ناردنی داواکاری سەرکەوتوو نەبوو'));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  InputDecoration _fieldDecoration({
    required String hint,
    Widget? prefixIcon,
  }) {
    return InputDecoration(
      hintText: tx(hint),
      hintStyle: TextStyle(
        color: RC.fg(const Color(0xFF94A3B8)),
        fontWeight: FontWeight.w600,
        fontSize: 14,
      ),
      filled: true,
      fillColor: RC.bg(Colors.white),
      prefixIcon: prefixIcon,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: RC.bg(const Color(0xFFFAC800)), width: 1.5),
      ),
    );
  }

  BoxDecoration get _cardShadow => BoxDecoration(
        color: RC.bg(Colors.white),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: RC.bg(Colors.black).withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      );

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    final bottom = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: RC.bg(const Color(0xFFF1F5F9)),
      body: Column(
        children: [
          // Yellow header
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(8, top + 8, 8, 16),
            decoration: BoxDecoration(
              color: RC.bg(const Color(0xFFFAC800)),
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(22)),
            ),
            child: Row(
              children: [
                IconButton(
                  onPressed: _submitting ? null : () => Navigator.of(context).pop(),
                  icon: Icon(
                    Icons.arrow_forward_rounded,
                    color: RC.fg(Colors.black),
                    size: 26,
                  ),
                ),
                Expanded(
                  child: Text(
                    tx('داواکاری ڕاستەوخۆ'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: RC.fg(Colors.black),
                    ),
                  ),
                ),
                const SizedBox(width: 48),
              ],
            ),
          ),

          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
              children: [
                // ناوی بابەت
                Container(
                  decoration: _cardShadow,
                  child: TextField(
                    controller: _subjectCtrl,
                    enabled: !_submitting,
                    textInputAction: TextInputAction.next,
                    decoration: _fieldDecoration(hint: 'ناوی بابەت'),
                  ),
                ),
                const SizedBox(height: 14),

                // تێبینی بابەت
                Container(
                  decoration: _cardShadow,
                  child: TextField(
                    controller: _notesCtrl,
                    enabled: !_submitting,
                    minLines: 4,
                    maxLines: 6,
                    decoration: _fieldDecoration(hint: 'تێبینی بابەت'),
                  ),
                ),
                const SizedBox(height: 14),

                // ناونیشانی بابەت
                Container(
                  decoration: _cardShadow,
                  child: TextField(
                    controller: _subjectAddressCtrl,
                    enabled: !_submitting,
                    textInputAction: TextInputAction.next,
                    decoration: _fieldDecoration(hint: 'ناونیشانی بابەت'),
                  ),
                ),
                const SizedBox(height: 14),

                // شوێنی گەیاندن (نەخشە)
                Container(
                  decoration: _cardShadow,
                  child: TextField(
                    controller: _addressCtrl,
                    enabled: !_submitting,
                    textInputAction: TextInputAction.next,
                    decoration: _fieldDecoration(
                      hint: 'شوێنی گەیاندن',
                      prefixIcon: IconButton(
                        onPressed: _submitting ? null : _pickAddress,
                        icon: Icon(
                          Icons.location_on_rounded,
                          color: RC.fg(const Color(0xFFFAC800)),
                          size: 26,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // ژمارەی مۆبایل
                Container(
                  decoration: _cardShadow,
                  child: TextField(
                    controller: _phoneCtrl,
                    enabled: !_submitting,
                    keyboardType: TextInputType.phone,
                    textDirection: TextDirection.ltr,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      IraqPhoneFormatter(),
                      LengthLimitingTextInputFormatter(13),
                    ],
                    decoration: _fieldDecoration(
                      hint: 'ژمارەی مۆبایل',
                      prefixIcon: Icon(
                        Icons.phone_rounded,
                        color: RC.fg(Colors.black87),
                        size: 22,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                // وێنەی بابەت
                Text(
                  tx('وێنەی بابەت'),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: RC.fg(const Color(0xFF0F172A)),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  textDirection: TextDirection.ltr,
                  children: [
                    Expanded(
                      child: _ImagePickButton(
                        label: tx('کامێرا'),
                        icon: Icons.photo_camera_outlined,
                        busy: _picking || _submitting,
                        onTap: () => _pickImage(fromCamera: true),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _ImagePickButton(
                        label: tx('گەلەری'),
                        icon: Icons.image_outlined,
                        busy: _picking || _submitting,
                        onTap: () => _pickImage(fromCamera: false),
                      ),
                    ),
                  ],
                ),
                if (_imageBytes != null) ...[
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: () => _openImagePreview(_imageBytes!),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: AspectRatio(
                        aspectRatio: 16 / 9,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.memory(
                              _imageBytes!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => ColoredBox(
                                color: RC.bg(const Color(0xFFE2E8F0)),
                                child: Center(
                                  child: Text(
                                    tx('نەتوانرا وێنە پیشان بدرێت'),
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: RC.fg(const Color(0xFF64748B)),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              left: 10,
                              bottom: 10,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: RC.bg(Colors.black).withValues(alpha: 0.55),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.open_in_full_rounded, size: 14, color: RC.fg(Colors.white)),
                                    const SizedBox(width: 6),
                                    Text(
                                      tx('کردنەوەی وێنە'),
                                      style: TextStyle(
                                        color: RC.fg(Colors.white),
                                        fontWeight: FontWeight.w700,
                                        fontSize: 12,
                                      ),
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
                ],
                const SizedBox(height: 22),

                // ناردنی داواکاری
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: _submitting ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: RC.bg(const Color(0xFFFAC800)),
                      foregroundColor: RC.fg(Colors.black),
                      disabledBackgroundColor: RC.bg(const Color(0xFFFDE68A)),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    child: _submitting
                        ? SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.4,
                              color: RC.fg(Colors.black),
                            ),
                          )
                        : Text(
                            tx('ناردنی داواکاری'),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                  ),
                ),
                SizedBox(height: bottom + 8),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ImagePickButton extends StatelessWidget {
  const _ImagePickButton({
    required this.label,
    required this.icon,
    required this.onTap,
    required this.busy,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: RC.bg(Colors.white),
      borderRadius: BorderRadius.circular(18),
      elevation: 0,
      shadowColor: Colors.transparent,
      child: InkWell(
        onTap: busy ? null : onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          height: 52,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: RC.bg(Colors.black).withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
            color: RC.bg(Colors.white),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 22, color: RC.fg(Colors.black87)),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      color: RC.fg(const Color(0xFF0F172A)),
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
