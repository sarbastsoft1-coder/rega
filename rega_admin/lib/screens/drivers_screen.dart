import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../core/api/api_client.dart';
import '../core/iraq_phone_formatter.dart';
import '../core/localization/app_strings.dart';
import '../core/services/media_pick_service.dart';
import '../core/services/open_url_io.dart' if (dart.library.html) '../core/services/open_url_web.dart';
import '../map/mapbox_tiles.dart';
import '../widgets/admin_top_header.dart';
import '../widgets/common_widgets.dart';
import '../core/theme/admin_breakpoints.dart';
import '../core/theme/app_theme.dart';

import '../rega_i18n.dart';
import '../rega_colors.dart';
class DriverDocItem {
  final int? id;
  final String docType;
  final String documentNumber;
  final String? fileUrl;
  final String status;

  const DriverDocItem({
    this.id,
    required this.docType,
    this.documentNumber = '',
    this.fileUrl,
    this.status = 'pending',
  });

  DriverDocItem copyWith({
    int? id,
    String? docType,
    String? documentNumber,
    String? fileUrl,
    String? status,
    bool clearFileUrl = false,
  }) {
    return DriverDocItem(
      id: id ?? this.id,
      docType: docType ?? this.docType,
      documentNumber: documentNumber ?? this.documentNumber,
      fileUrl: clearFileUrl ? null : (fileUrl ?? this.fileUrl),
      status: status ?? this.status,
    );
  }
}

class _PendingDocFile {
  final String name;
  final List<int> bytes;
  _PendingDocFile(this.name, this.bytes);
}

/// Representation of a courier matching the exact design in the screenshot
class CourierItem {
  final int id;
  final String name;
  final String phone;
  final String city;
  final String status; // 'active' (چالاک), 'on_the_way' (لە دلیڤەری), 'offline' (ناچالاک)
  final int todayOrders;
  final String avatarUrl;
  final String motorType;
  final String plateNumber;
  final LatLng location;
  final bool isVerified;
  final bool isVehicleVerified;
  final String motorColor;
  final String modelYear;
  final String bloodType;
  final String homePhone;
  final String infoCardNumber;
  final num cashCollected;
  final num walletBalance;
  final String language;
  final bool isAccountActive;
  final List<DriverDocItem> documents;

  CourierItem({
    required this.id,
    required this.name,
    required this.phone,
    required this.city,
    required this.status,
    required this.todayOrders,
    required this.avatarUrl,
    required this.motorType,
    required this.plateNumber,
    required this.location,
    this.isVerified = true,
    this.isVehicleVerified = true,
    this.motorColor = 'ڕەش و سەوز',
    this.modelYear = '2024',
    this.bloodType = '',
    this.homePhone = '',
    this.infoCardNumber = '',
    this.cashCollected = 0,
    this.walletBalance = 0,
    this.language = 'ku',
    this.isAccountActive = true,
    this.documents = const [],
  });

  CourierItem copyWith({
    int? id,
    String? name,
    String? phone,
    String? city,
    String? status,
    int? todayOrders,
    String? avatarUrl,
    String? motorType,
    String? plateNumber,
    LatLng? location,
    bool? isVerified,
    bool? isVehicleVerified,
    String? motorColor,
    String? modelYear,
    String? bloodType,
    String? homePhone,
    String? infoCardNumber,
    num? cashCollected,
    num? walletBalance,
    String? language,
    bool? isAccountActive,
    List<DriverDocItem>? documents,
  }) {
    return CourierItem(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      city: city ?? this.city,
      status: status ?? this.status,
      todayOrders: todayOrders ?? this.todayOrders,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      motorType: motorType ?? this.motorType,
      plateNumber: plateNumber ?? this.plateNumber,
      location: location ?? this.location,
      isVerified: isVerified ?? this.isVerified,
      isVehicleVerified: isVehicleVerified ?? this.isVehicleVerified,
      motorColor: motorColor ?? this.motorColor,
      modelYear: modelYear ?? this.modelYear,
      bloodType: bloodType ?? this.bloodType,
      homePhone: homePhone ?? this.homePhone,
      infoCardNumber: infoCardNumber ?? this.infoCardNumber,
      cashCollected: cashCollected ?? this.cashCollected,
      walletBalance: walletBalance ?? this.walletBalance,
      language: language ?? this.language,
      isAccountActive: isAccountActive ?? this.isAccountActive,
      documents: documents ?? this.documents,
    );
  }
}

class DriversScreen extends StatefulWidget {
  final ApiClient api;
  final String lang;

  const DriversScreen({super.key, required this.api, required this.lang});

  @override
  State<DriversScreen> createState() => _DriversScreenState();
}

class _DriversScreenState extends State<DriversScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  final MapController _mapController = MapController();

  int _currentPage = 1;
  String _selectedCity = 'all';
  String _selectedStatus = 'all';
  String _selectedDate = 'today';
  Timer? _refreshTimer;

  // Live KPI Metrics updated from PostgreSQL database
  String _totalDriversKPI = '٠';
  String _activeDriversKPI = '٠';
  String _inDeliveryKPI = '٠';
  String _pendingApprovalKPI = '٠';

  static String _toDigits(dynamic input) {
    const en = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    const ku = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    String s = input.toString();
    for (int i = 0; i < 10; i++) {
      s = s.replaceAll(en[i], ku[i]);
    }
    return s;
  }

  List<CourierItem> _couriers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFromBackend();
    _refreshTimer = Timer.periodic(const Duration(seconds: 4), (_) => _loadFromBackend(silent: true));
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _searchCtrl.dispose();
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _loadFromBackend({bool silent = false}) async {
    if (!silent && _couriers.isEmpty) {
      setState(() => _isLoading = true);
    }
    try {
      final backendList = await widget.api.getDrivers();
      if (!mounted) return;

      final List<CourierItem> merged = [];

      for (final item in backendList) {
        final m = item as Map<String, dynamic>;
        final u = m['user'] as Map<String, dynamic>? ?? {};
        final isOnline = m['is_online'] == true;
        final isVerified = m['is_verified'] == true;
        final motorType = m['motor_type']?.toString() ?? 'هۆندا';
        final plateNumber = m['plate_number']?.toString() ?? 'KLR-100';

        final rawDocs = m['documents'] as List<dynamic>? ?? [];
        final docs = rawDocs.map((d) {
          final dm = d as Map<String, dynamic>;
          return DriverDocItem(
            id: dm['id'] as int?,
            docType: dm['doc_type']?.toString() ?? '',
            documentNumber: dm['document_number']?.toString() ?? '',
            fileUrl: dm['file_url']?.toString(),
            status: dm['status']?.toString() ?? 'pending',
          );
        }).toList();

        merged.add(
          CourierItem(
            id: m['id'] as int? ?? (100 + merged.length),
            name: u['name']?.toString() ?? 'شۆفێری ڕێگا',
            phone: u['phone']?.toString() ?? '0750 000 0000',
            city: 'کەلار',
            status: isOnline ? 'active' : 'offline',
            todayOrders: (m['total_deliveries'] as num?)?.toInt() ?? 0,
            avatarUrl: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=150',
            motorType: motorType,
            plateNumber: plateNumber,
            location: LatLng(
              (m['current_lat'] as num?)?.toDouble() ?? 34.6295,
              (m['current_lng'] as num?)?.toDouble() ?? 45.3159,
            ),
            isVerified: isVerified,
            isVehicleVerified: m['is_vehicle_verified'] == true,
            motorColor: m['motor_color']?.toString() ?? 'ڕەش و سەوز',
            modelYear: m['model_year']?.toString() ?? '2024',
            bloodType: m['blood_type']?.toString() ?? '',
            homePhone: m['home_phone']?.toString() ?? '',
            infoCardNumber: m['info_card_number']?.toString() ?? '',
            cashCollected: (m['cash_collected_hand'] as num?) ?? 0,
            walletBalance: (m['wallet_balance'] as num?) ?? 0,
            language: u['language']?.toString() ?? 'ku',
            isAccountActive: u['is_active'] != false,
            documents: docs,
          ),
        );
      }

      final totalCount = merged.length;
      final activeCount = merged.where((c) => c.status == 'active').length;
      final inDeliveryCount = merged.where((c) => c.status == 'on_the_way').length;
      final pendingCount = merged.where((c) => !c.isVerified).length;

      setState(() {
        _couriers = merged;
        _totalDriversKPI = _toDigits(totalCount);
        _activeDriversKPI = _toDigits(activeCount);
        _inDeliveryKPI = _toDigits(inDeliveryCount);
        _pendingApprovalKPI = _toDigits(pendingCount);
        _isLoading = false;
      });
    } catch (_) {
      if (mounted && !silent) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showSnack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(tx(msg), style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: error ? RC.bg(Color(0xFFDC2626)) : RC.bg(Color(0xFF113E2E)),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  List<CourierItem> get _filteredCouriers {
    final query = _searchCtrl.text.trim().toLowerCase();
    return _couriers.where((c) {
      if (query.isNotEmpty) {
        final matchName = c.name.toLowerCase().contains(query);
        final matchPhone = c.phone.replaceAll(' ', '').contains(query.replaceAll(' ', ''));
        final matchCity = c.city.toLowerCase().contains(query);
        if (!matchName && !matchPhone && !matchCity) return false;
      }
      if (_selectedCity != 'all' && c.city != _selectedCity) return false;
      if (_selectedStatus == 'active' && c.status != 'active') return false;
      if (_selectedStatus == 'on_the_way' && c.status != 'on_the_way') return false;
      if (_selectedStatus == 'offline' && c.status != 'offline') return false;
      return true;
    }).toList();
  }

  String _docTypeLabel(String docType) {
    switch (docType) {
      case 'info_card':
        return 'کارتی زانیاری';
      case 'national_id':
        return 'کارتی نیشتیمانی';
      case 'driver_license':
        return 'مۆڵەتی شۆفێری ماتۆڕسکیل';
      case 'vehicle_registration':
        return 'بەڵگەی خاوەندارییەتی ماتۆڕ (ساڵانە)';
      default:
        return docType;
    }
  }

  DriverDocItem _findDoc(List<DriverDocItem> docs, String type) {
    return docs.firstWhere(
      (d) => d.docType == type,
      orElse: () => DriverDocItem(docType: type),
    );
  }

  bool _isPdfNameOrUrl(String? value) {
    if (value == null || value.isEmpty) return false;
    final lower = value.toLowerCase();
    return lower.contains('.pdf') || lower.endsWith('pdf');
  }

  bool _isImageNameOrUrl(String? value) {
    if (value == null || value.isEmpty) return false;
    final lower = value.toLowerCase();
    return lower.contains('.jpg') ||
        lower.contains('.jpeg') ||
        lower.contains('.png') ||
        lower.contains('.webp') ||
        lower.contains('.gif');
  }

  String _fileDisplayName(String? pendingName, String? url) {
    if (pendingName != null && pendingName.isNotEmpty) return pendingName;
    if (url == null || url.isEmpty) return 'هیچ فایلێک هەڵنەبژێردراوە';
    final cleaned = url.split('?').first;
    final parts = cleaned.split('/');
    return parts.isNotEmpty ? parts.last : cleaned;
  }

  void _openMediaUrl(String? url) {
    final resolved = widget.api.resolveMediaUrl(url);
    if (resolved.isEmpty) {
      _showSnack('هیچ فایلێک بۆ کردنەوە نییە', error: true);
      return;
    }
    try {
      openExternalUrl(resolved);
    } catch (_) {
      _showSnack('نەتوانرا فایل بکرێتەوە', error: true);
    }
  }

  void _previewDocumentFile({
    required String title,
    String? url,
    List<int>? pendingBytes,
    String? pendingName,
  }) {
    final isPdf = _isPdfNameOrUrl(pendingName) ||
        (_isPdfNameOrUrl(url) && (pendingBytes == null || pendingBytes.isEmpty));
    final hasPendingImage = pendingBytes != null &&
        pendingBytes.isNotEmpty &&
        !_isPdfNameOrUrl(pendingName);
    final resolved = widget.api.resolveMediaUrl(url);

    if (isPdf && !hasPendingImage) {
      if (pendingBytes != null && pendingBytes.isNotEmpty) {
        _showSnack('PDF هەڵبژێردراوە — دوای پاشەکەوتکردن دەتوانیت بیبینیت');
        return;
      }
      _openMediaUrl(resolved);
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: AdminBreakpoints.dialogInset(ctx),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: AdminBreakpoints.dialogWidth(ctx, max: 720),
            maxHeight: AdminBreakpoints.dialogMaxHeight(ctx, fraction: 0.90),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(16, 14, 8, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        tx(title),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                      ),
                    ),
                    if (resolved.isNotEmpty)
                      IconButton(
                        tooltip: tx('کردنەوە لە تابێکی نوێ'),
                        onPressed: () => _openMediaUrl(resolved),
                        icon: const Icon(Icons.open_in_new_rounded),
                      ),
                    IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: hasPendingImage
                        ? InteractiveViewer(
                            child: Image.memory(
                              Uint8List.fromList(pendingBytes),
                              fit: BoxFit.contain,
                            ),
                          )
                        : resolved.isNotEmpty
                            ? InteractiveViewer(
                                child: Image.network(
                                  resolved,
                                  fit: BoxFit.contain,
                                  errorBuilder: (_, __, ___) => Padding(
                                    padding: const EdgeInsets.all(24),
                                    child: Text(tx('نەتوانرا وێنە باربکرێت')),
                                  ),
                                ),
                              )
                            : Padding(
                                padding: const EdgeInsets.all(24),
                                child: Text(tx('هیچ وێنەیەک نییە')),
                              ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<_PendingDocFile?> _pickDriverDocFile() async {
    final picked = await MediaPickService.pickImageOrPdf();
    if (picked == null) return null;
    if (picked.bytes.isEmpty) {
      _showSnack('نەتوانرا فایل بخوێنرێتەوە. تکایە وێنە یان PDF هەڵبژێرە.', error: true);
      return null;
    }
    final name = picked.name.toLowerCase();
    final ok = name.endsWith('.pdf') ||
        name.endsWith('.jpg') ||
        name.endsWith('.jpeg') ||
        name.endsWith('.png') ||
        name.endsWith('.webp') ||
        name.endsWith('.gif');
    if (!ok) {
      _showSnack('تەنها وێنە (JPG/PNG/WEBP) یان PDF ڕێگەپێدراوە', error: true);
      return null;
    }
    return _PendingDocFile(picked.name, picked.bytes);
  }

  Future<void> _showAddCourierDialog({CourierItem? existing}) async {
    final isEdit = existing != null;
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final phoneCtrl = TextEditingController(text: IraqPhoneFormatter.format(existing?.phone ?? ''));
    final homePhoneCtrl = TextEditingController(text: IraqPhoneFormatter.format(existing?.homePhone ?? ''));
    final passwordCtrl = TextEditingController();
    final infoCardCtrl = TextEditingController(text: existing?.infoCardNumber ?? '');
    final cityCtrl = TextEditingController(text: existing?.city ?? 'هەولێر');
    final motorTypeCtrl = TextEditingController(text: existing?.motorType ?? '');
    final plateCtrl = TextEditingController(text: existing?.plateNumber ?? 'KLR-402');
    final colorCtrl = TextEditingController(text: existing?.motorColor ?? 'ڕەش و سەوز');
    final yearCtrl = TextEditingController(text: existing?.modelYear ?? '2024');
    final cashCtrl = TextEditingController(text: (existing?.cashCollected ?? 0).toString());
    String bloodType = (existing?.bloodType.isNotEmpty == true) ? existing!.bloodType : 'O+';
    String status = existing?.status ?? 'active';
    bool isVerified = existing?.isVerified ?? true;
    bool isVehicleVerified = existing?.isVehicleVerified ?? true;
    bool isAccountActive = existing?.isAccountActive ?? true;
    String language = existing?.language ?? 'ku';
    bool obscurePassword = true;

    var existingDocs = List<DriverDocItem>.from(existing?.documents ?? const <DriverDocItem>[]);
    if (isEdit) {
      try {
        final raw = await widget.api.getDriverDocuments(existing.id);
        existingDocs = raw.map((d) {
          final dm = d as Map<String, dynamic>;
          return DriverDocItem(
            id: dm['id'] as int?,
            docType: dm['doc_type']?.toString() ?? '',
            documentNumber: dm['document_number']?.toString() ?? '',
            fileUrl: dm['file_url']?.toString(),
            status: dm['status']?.toString() ?? 'pending',
          );
        }).toList();
      } catch (_) {
        // Keep courier.documents fallback when the documents endpoint is unreachable.
      }
    }

    final infoCard = _findDoc(existingDocs, 'info_card');
    final national = _findDoc(existingDocs, 'national_id');
    final license = _findDoc(existingDocs, 'driver_license');
    final registration = _findDoc(existingDocs, 'vehicle_registration');

    if (infoCardCtrl.text.isEmpty && infoCard.documentNumber.isNotEmpty) {
      infoCardCtrl.text = infoCard.documentNumber;
    }

    final nationalNoCtrl = TextEditingController(text: national.documentNumber);
    final licenseNoCtrl = TextEditingController(text: license.documentNumber);
    final registrationNoCtrl = TextEditingController(text: registration.documentNumber);

    String infoCardStatus = infoCard.status;
    String nationalStatus = national.status;
    String licenseStatus = license.status;
    String registrationStatus = registration.status;
    String? infoCardUrl = infoCard.fileUrl;
    String? nationalUrl = national.fileUrl;
    String? licenseUrl = license.fileUrl;
    String? registrationUrl = registration.fileUrl;
    final originalInfoCardUrl = infoCard.fileUrl;
    final originalNationalUrl = national.fileUrl;
    final originalLicenseUrl = license.fileUrl;
    final originalRegistrationUrl = registration.fileUrl;
    int? infoCardDocId = infoCard.id;
    int? nationalDocId = national.id;
    int? licenseDocId = license.id;
    int? registrationDocId = registration.id;

    _PendingDocFile? infoCardFile;
    _PendingDocFile? nationalFile;
    _PendingDocFile? licenseFile;
    _PendingDocFile? registrationFile;
    bool saving = false;

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final dialogW = AdminBreakpoints.dialogWidth(ctx, max: 560);

          return AlertDialog(
          insetPadding: AdminBreakpoints.dialogInset(ctx),
          contentPadding: AdminBreakpoints.dialogContentPadding(ctx),
          actionsOverflowButtonSpacing: 8,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: RC.bg(Color(0xFF113E2E)).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.two_wheeler_rounded, color: RC.fg(Color(0xFF113E2E)), size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  tx(isEdit ? 'دەستکاریکردنی هەموو بەشەکانی شۆفێر / گەیاندن' : 'زیادکردنی ماتۆرسواری نوێ'),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
          content: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: dialogW,
              maxHeight: AdminBreakpoints.dialogContentMaxHeight(ctx, max: 580),
            ),
            child: SizedBox(
            width: dialogW,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tx('١. زانیاری کەسی شۆفێر'), style: TextStyle(fontWeight: FontWeight.w900, color: RC.fg(Color(0xFF113E2E)))),
                  const SizedBox(height: 10),
                  ResponsiveFormRow(
                    breakpoint: 460,
                    first: TextField(
                      controller: nameCtrl,
                      decoration: InputDecoration(
                        labelText: tx('ناوی تەواوی شۆفێر *'),
                        prefixIcon: const Icon(Icons.person_outline, size: 20),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                    ),
                    second: TextField(
                      controller: phoneCtrl,
                      keyboardType: TextInputType.phone,
                      textDirection: TextDirection.ltr,
                      textAlign: TextAlign.left,
                      inputFormatters: <TextInputFormatter>[IraqPhoneFormatter()],
                      decoration: InputDecoration(
                        labelText: tx('ژمارەی مۆبایل *'),
                        hintText: txn(IraqPhoneFormatter.hint),
                        prefixIcon: const Icon(Icons.phone_android_outlined, size: 20),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ResponsiveFormRow(
                    breakpoint: 460,
                    first: TextField(
                      controller: homePhoneCtrl,
                      keyboardType: TextInputType.phone,
                      textDirection: TextDirection.ltr,
                      textAlign: TextAlign.left,
                      inputFormatters: <TextInputFormatter>[IraqPhoneFormatter()],
                      decoration: InputDecoration(
                        labelText: tx('ژمارەی ماڵەوە'),
                        hintText: txn(IraqPhoneFormatter.hint),
                        prefixIcon: const Icon(Icons.phone_outlined, size: 20),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                    ),
                    second: DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: const ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'].contains(bloodType)
                          ? bloodType
                          : 'O+',
                      decoration: InputDecoration(
                        labelText: tx('جۆری خوێن'),
                        prefixIcon: const Icon(Icons.bloodtype_outlined, size: 20),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                      items: [
                        DropdownMenuItem(value: 'A+', child: Text(tx('A+'), maxLines: 1, overflow: TextOverflow.ellipsis)),
                        DropdownMenuItem(value: 'A-', child: Text(tx('A-'), maxLines: 1, overflow: TextOverflow.ellipsis)),
                        DropdownMenuItem(value: 'B+', child: Text(tx('B+'), maxLines: 1, overflow: TextOverflow.ellipsis)),
                        DropdownMenuItem(value: 'B-', child: Text(tx('B-'), maxLines: 1, overflow: TextOverflow.ellipsis)),
                        DropdownMenuItem(value: 'AB+', child: Text(tx('AB+'), maxLines: 1, overflow: TextOverflow.ellipsis)),
                        DropdownMenuItem(value: 'AB-', child: Text(tx('AB-'), maxLines: 1, overflow: TextOverflow.ellipsis)),
                        DropdownMenuItem(value: 'O+', child: Text(tx('O+'), maxLines: 1, overflow: TextOverflow.ellipsis)),
                        DropdownMenuItem(value: 'O-', child: Text(tx('O-'), maxLines: 1, overflow: TextOverflow.ellipsis)),
                      ],
                      onChanged: (v) => setDialogState(() => bloodType = v ?? 'O+'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: passwordCtrl,
                    obscureText: obscurePassword,
                    decoration: InputDecoration(
                      labelText: tx(isEdit
                          ? AppStrings.tr('password_new_optional', widget.lang)
                          : '${AppStrings.tr('password_label', widget.lang)} *'),
                      hintText: txn(isEdit ? 'بەجێی بهێڵە ئەگەر نەگۆڕیت' : 'کەمترین ٦ پیت'),
                      prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
                      suffixIcon: IconButton(
                        onPressed: () => setDialogState(() => obscurePassword = !obscurePassword),
                        icon: Icon(
                          obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                          size: 20,
                        ),
                      ),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 14),
                  ResponsiveFormRow(
                    breakpoint: 460,
                    first: DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: cityCtrl.text,
                      decoration: InputDecoration(
                        labelText: tx('شار / دەڤەر'),
                        prefixIcon: const Icon(Icons.location_city_outlined, size: 20),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                      items: [
                        DropdownMenuItem(value: 'هەولێر', child: Text(tx('هەولێر'), maxLines: 1, overflow: TextOverflow.ellipsis)),
                        DropdownMenuItem(value: 'سلێمانی', child: Text(tx('سلێمانی'), maxLines: 1, overflow: TextOverflow.ellipsis)),
                        DropdownMenuItem(value: 'دهۆک', child: Text(tx('دهۆک'), maxLines: 1, overflow: TextOverflow.ellipsis)),
                        DropdownMenuItem(value: 'کەلار', child: Text(tx('کەلار'), maxLines: 1, overflow: TextOverflow.ellipsis)),
                      ],
                      onChanged: (v) => setDialogState(() => cityCtrl.text = v ?? 'هەولێر'),
                    ),
                    second: DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: status,
                      decoration: InputDecoration(
                        labelText: tx('دۆخی کارکردنی دلیڤەری'),
                        prefixIcon: const Icon(Icons.toggle_on_outlined, size: 20),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                      items: [
                        DropdownMenuItem(value: 'active', child: Text(tx('🟢 چالاک (بەردەست)'), maxLines: 1, overflow: TextOverflow.ellipsis)),
                        DropdownMenuItem(value: 'on_the_way', child: Text(tx('🟡 لە دلیڤەری (سەرقاڵ)'), maxLines: 1, overflow: TextOverflow.ellipsis)),
                        DropdownMenuItem(value: 'offline', child: Text(tx('⚪ ناچالاک (ئۆفلاین)'), maxLines: 1, overflow: TextOverflow.ellipsis)),
                      ],
                      onChanged: (v) => setDialogState(() => status = v ?? 'active'),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(tx('٢. زانیاری ماتۆڕ (جۆر / تابلۆ / ڕەنگ)'), style: TextStyle(fontWeight: FontWeight.w900, color: RC.fg(Color(0xFF113E2E)))),
                  const SizedBox(height: 10),
                  ResponsiveFormRow(
                    breakpoint: 460,
                    first: TextField(
                      controller: motorTypeCtrl,
                      decoration: InputDecoration(
                        labelText: tx('جۆری ماتۆڕ *'),
                        prefixIcon: const Icon(Icons.two_wheeler_outlined, size: 20),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                    ),
                    second: TextField(
                      controller: plateCtrl,
                      decoration: InputDecoration(
                        labelText: tx('ژمارەی تابلۆی ماتۆڕ *'),
                        prefixIcon: const Icon(Icons.pin_outlined, size: 20),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ResponsiveFormRow(
                    breakpoint: 460,
                    first: TextField(
                      controller: colorCtrl,
                      decoration: InputDecoration(
                        labelText: tx('ڕەنگی ماتۆڕ'),
                        prefixIcon: const Icon(Icons.palette_outlined, size: 20),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                    ),
                    second: TextField(
                      controller: yearCtrl,
                      decoration: InputDecoration(
                        labelText: tx('مۆدێل / ساڵ'),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(tx('٣. دارایی و پشتڕاستکردنەوە (KYC & Finance)'), style: TextStyle(fontWeight: FontWeight.w900, color: RC.fg(Color(0xFF113E2E)))),
                  const SizedBox(height: 10),
                  TextField(
                    controller: cashCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: tx('کاشی کۆکراوە (COD د.ع)'),
                      prefixIcon: const Icon(Icons.payments_outlined, size: 20),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(tx('٤. بەڵگەنامە یاساییەکان (وێنە یان PDF)'), style: TextStyle(fontWeight: FontWeight.w900, color: RC.fg(Color(0xFF113E2E)))),
                  const SizedBox(height: 6),
                  Text(
                    tx('بۆ هەر بەڵگەیەک دەتوانیت وێنە (.jpg/.png) یان فایل PDF بار بکەیت'),
                    style: TextStyle(fontSize: 11, color: RC.fg(Color(0xFF64748B))),
                  ),
                  const SizedBox(height: 10),
                  _buildAdminDocUploadCard(
                    title: _docTypeLabel('info_card'),
                    numberCtrl: infoCardCtrl,
                    status: infoCardStatus,
                    existingUrl: infoCardUrl,
                    pendingName: infoCardFile?.name,
                    pendingBytes: infoCardFile?.bytes,
                    onStatus: (v) => setDialogState(() => infoCardStatus = v),
                    onPick: () async {
                      final f = await _pickDriverDocFile();
                      if (f != null) setDialogState(() => infoCardFile = f);
                    },
                    onClear: () => setDialogState(() {
                      infoCardFile = null;
                      infoCardUrl = null;
                    }),
                    onPreview: () => _previewDocumentFile(
                      title: _docTypeLabel('info_card'),
                      url: infoCardUrl,
                      pendingBytes: infoCardFile?.bytes,
                      pendingName: infoCardFile?.name,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _buildAdminDocUploadCard(
                    title: _docTypeLabel('national_id'),
                    numberCtrl: nationalNoCtrl,
                    status: nationalStatus,
                    existingUrl: nationalUrl,
                    pendingName: nationalFile?.name,
                    pendingBytes: nationalFile?.bytes,
                    onStatus: (v) => setDialogState(() => nationalStatus = v),
                    onPick: () async {
                      final f = await _pickDriverDocFile();
                      if (f != null) setDialogState(() => nationalFile = f);
                    },
                    onClear: () => setDialogState(() {
                      nationalFile = null;
                      nationalUrl = null;
                    }),
                    onPreview: () => _previewDocumentFile(
                      title: _docTypeLabel('national_id'),
                      url: nationalUrl,
                      pendingBytes: nationalFile?.bytes,
                      pendingName: nationalFile?.name,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _buildAdminDocUploadCard(
                    title: _docTypeLabel('driver_license'),
                    numberCtrl: licenseNoCtrl,
                    status: licenseStatus,
                    existingUrl: licenseUrl,
                    pendingName: licenseFile?.name,
                    pendingBytes: licenseFile?.bytes,
                    onStatus: (v) => setDialogState(() => licenseStatus = v),
                    onPick: () async {
                      final f = await _pickDriverDocFile();
                      if (f != null) setDialogState(() => licenseFile = f);
                    },
                    onClear: () => setDialogState(() {
                      licenseFile = null;
                      licenseUrl = null;
                    }),
                    onPreview: () => _previewDocumentFile(
                      title: _docTypeLabel('driver_license'),
                      url: licenseUrl,
                      pendingBytes: licenseFile?.bytes,
                      pendingName: licenseFile?.name,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _buildAdminDocUploadCard(
                    title: _docTypeLabel('vehicle_registration'),
                    numberCtrl: registrationNoCtrl,
                    status: registrationStatus,
                    existingUrl: registrationUrl,
                    pendingName: registrationFile?.name,
                    pendingBytes: registrationFile?.bytes,
                    onStatus: (v) => setDialogState(() => registrationStatus = v),
                    onPick: () async {
                      final f = await _pickDriverDocFile();
                      if (f != null) setDialogState(() => registrationFile = f);
                    },
                    onClear: () => setDialogState(() {
                      registrationFile = null;
                      registrationUrl = null;
                    }),
                    onPreview: () => _previewDocumentFile(
                      title: _docTypeLabel('vehicle_registration'),
                      url: registrationUrl,
                      pendingBytes: registrationFile?.bytes,
                      pendingName: registrationFile?.name,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(tx('٥. زمانەکان'), style: TextStyle(fontWeight: FontWeight.w900, color: RC.fg(Color(0xFF113E2E)))),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AdminSurfaces.of(context).chipFill,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final opt in [
                          ('ku', AppStrings.tr('lang_ku', widget.lang)),
                          ('ar', AppStrings.tr('lang_ar', widget.lang)),
                          ('en', AppStrings.tr('lang_en', widget.lang)),
                        ])
                          ChoiceChip(
                            showCheckmark: false,
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            label: Text(
                              tx(opt.$2),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                            ),
                            selected: language == opt.$1,
                            selectedColor: RC.bg(Colors.white),
                            backgroundColor: Colors.transparent,
                            side: BorderSide(
                              color: language == opt.$1 ? RC.bg(Color(0xFF16A34A)) : Colors.transparent,
                            ),
                            onSelected: (_) => setDialogState(() => language = opt.$1),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(tx('مسدودکردنی هەژمار (Block account)'), style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                    subtitle: Text(
                      tx(isAccountActive
                          ? 'هەژمار چالاکە — دەتوانێت بچێتە ژوورەوە'
                          : 'مسدودە — دەبێت پەیوەندی بە ئادمین بکات (WhatsApp/Telegram)'),
                      style: const TextStyle(fontSize: 11),
                    ),
                    value: !isAccountActive,
                    activeTrackColor: RC.bg(Color(0xFFFECACA)),
                    activeThumbColor: RC.bg(Color(0xFFDC2626)),
                    onChanged: (v) => setDialogState(() => isAccountActive = !v),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(tx('پشتڕاستکردنەوەی شۆفێر (KYC Driver Verified)'), style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                    subtitle: Text(tx('ڕێگەپێدراوە بۆ وەرگرتنی داواکاری لە ئەپی گەیاندن'), style: TextStyle(fontSize: 11)),
                    value: isVerified,
                    activeThumbColor: RC.bg(Color(0xFF113E2E)),
                    onChanged: (v) => setDialogState(() => isVerified = v),
                  ),
                  SwitchListTile(
                    title: Text(tx('پشتڕاستکردنەوەی ماتۆڕ (Vehicle Verified)'), style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                    value: isVehicleVerified,
                    activeThumbColor: RC.bg(Color(0xFF113E2E)),
                    onChanged: (v) => setDialogState(() => isVehicleVerified = v),
                    contentPadding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),
            ),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(ctx),
              child: Text(tx('پاشگەزبوونەوە'), style: TextStyle(color: RC.fg(Colors.grey))),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: RC.bg(Color(0xFF113E2E)),
                foregroundColor: RC.fg(Colors.white),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              onPressed: saving
                  ? null
                  : () async {
                      final name = nameCtrl.text.trim();
                      final phone = phoneCtrl.text.trim();
                      final password = passwordCtrl.text.trim();
                      if (name.isEmpty || phone.isEmpty) {
                        _showSnack('تکایە ناو و ژمارەی مۆبایل بنووسە', error: true);
                        return;
                      }
                      if (!isEdit && password.length < 6) {
                        _showSnack('تکایە وشەی نهێنی بنووسە (کەمترین ٦ پیت)', error: true);
                        return;
                      }
                      if (isEdit && password.isNotEmpty && password.length < 6) {
                        _showSnack('وشەی نهێنی دەبێت لانیکەم ٦ پیت بێت', error: true);
                        return;
                      }
                      setDialogState(() => saving = true);

                      try {
                        // Upload any newly picked files first (image / PDF)
                        Future<String?> uploadMaybe(_PendingDocFile? file, String? currentUrl) async {
                          if (file == null) return currentUrl;
                          final up = await widget.api.uploadMedia(file.bytes, file.name);
                          return up['url']?.toString() ?? currentUrl;
                        }

                        infoCardUrl = await uploadMaybe(infoCardFile, infoCardUrl);
                        nationalUrl = await uploadMaybe(nationalFile, nationalUrl);
                        licenseUrl = await uploadMaybe(licenseFile, licenseUrl);
                        registrationUrl = await uploadMaybe(registrationFile, registrationUrl);

                        final payload = <String, dynamic>{
                          'name': name,
                          'phone': phone,
                          'city': cityCtrl.text,
                          'motor_type': motorTypeCtrl.text.trim(),
                          'plate_number': plateCtrl.text.trim(),
                          'motor_color': colorCtrl.text.trim(),
                          'model_year': yearCtrl.text.trim(),
                          'blood_type': bloodType,
                          'home_phone': homePhoneCtrl.text.trim(),
                          'info_card_number': infoCardCtrl.text.trim(),
                          'is_verified': isVerified,
                          'is_vehicle_verified': isVehicleVerified,
                          'is_online': status == 'active' || status == 'on_the_way',
                          'is_active': isAccountActive,
                          'language': language,
                          'cash_collected_hand': num.tryParse(cashCtrl.text.trim()) ?? 0,
                          'national_id_number': nationalNoCtrl.text.trim(),
                          'license_number': licenseNoCtrl.text.trim(),
                          'registration_number': registrationNoCtrl.text.trim(),
                          'info_card_file_url': infoCardUrl ?? '',
                          'national_id_file_url': nationalUrl ?? '',
                          'license_file_url': licenseUrl ?? '',
                          'registration_file_url': registrationUrl ?? '',
                          'info_card_status': infoCardStatus,
                          'national_id_status': nationalStatus,
                          'license_status': licenseStatus,
                          'registration_status': registrationStatus,
                          if (password.isNotEmpty) 'password': password,
                        };

                        if (isEdit) {
                          await widget.api.updateDriver(existing.id, payload);

                          Future<void> syncDoc({
                            required int? id,
                            required _PendingDocFile? file,
                            required String number,
                            required String st,
                            required String? url,
                            required String? originalUrl,
                          }) async {
                            if (id == null) return;
                            final cleared = (originalUrl != null && originalUrl.isNotEmpty) &&
                                (url == null || url.isEmpty) &&
                                file == null;
                            if (file != null) {
                              await widget.api.uploadDriverDocumentFile(
                                id,
                                file.bytes,
                                file.name,
                                documentNumber: number,
                                status: st,
                              );
                            } else {
                              await widget.api.updateDriverDocument(
                                id,
                                documentNumber: number,
                                status: st,
                                clearFile: cleared,
                              );
                            }
                          }

                          await syncDoc(
                            id: infoCardDocId,
                            file: infoCardFile,
                            number: infoCardCtrl.text.trim(),
                            st: infoCardStatus,
                            url: infoCardUrl,
                            originalUrl: originalInfoCardUrl,
                          );
                          await syncDoc(
                            id: nationalDocId,
                            file: nationalFile,
                            number: nationalNoCtrl.text.trim(),
                            st: nationalStatus,
                            url: nationalUrl,
                            originalUrl: originalNationalUrl,
                          );
                          await syncDoc(
                            id: licenseDocId,
                            file: licenseFile,
                            number: licenseNoCtrl.text.trim(),
                            st: licenseStatus,
                            url: licenseUrl,
                            originalUrl: originalLicenseUrl,
                          );
                          await syncDoc(
                            id: registrationDocId,
                            file: registrationFile,
                            number: registrationNoCtrl.text.trim(),
                            st: registrationStatus,
                            url: registrationUrl,
                            originalUrl: originalRegistrationUrl,
                          );
                        } else {
                          await widget.api.createDriver(payload);
                        }

                        if (ctx.mounted) Navigator.pop(ctx);
                        await _loadFromBackend();
                        _showSnack(isEdit
                            ? 'هەموو بەشەکانی شۆفێر و بەڵگەنامەکان نوێکرانەوە ✅'
                            : 'شۆفێری نوێ بە بەڵگەنامەکان زیادکرا ✅');
                      } catch (e) {
                        setDialogState(() => saving = false);
                        _showSnack(e.toString(), error: true);
                      }
                    },
              child: saving
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: RC.bg(Colors.white)),
                    )
                  : Text(
                      tx(isEdit ? 'پاشەکەوتکردنی هەموو گۆڕانکارییەکان' : 'زیادکردنی شۆفێر'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
            ),
          ],
        );
        },
      ),
    );
  }

  Widget _buildAdminDocUploadCard({
    required String title,
    required TextEditingController numberCtrl,
    required String status,
    required String? existingUrl,
    required String? pendingName,
    List<int>? pendingBytes,
    required ValueChanged<String> onStatus,
    required VoidCallback onPick,
    required VoidCallback onClear,
    required VoidCallback onPreview,
  }) {
    final hasFile = (pendingName != null && pendingName.isNotEmpty) ||
        (existingUrl != null && existingUrl.isNotEmpty);
    final fileLabel = _fileDisplayName(pendingName, existingUrl);
    final isPdf = _isPdfNameOrUrl(pendingName) ||
        (pendingBytes == null && _isPdfNameOrUrl(existingUrl));
    final hasPendingImage = pendingBytes != null &&
        pendingBytes.isNotEmpty &&
        !_isPdfNameOrUrl(pendingName);
    final resolvedUrl = widget.api.resolveMediaUrl(existingUrl);
    final canShowNetworkThumb = !hasPendingImage &&
        resolvedUrl.isNotEmpty &&
        _isImageNameOrUrl(existingUrl);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: RC.bg(Color(0xFFF8FAFC)),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: RC.bg(Color(0xFFE2E8F0))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.badge_outlined, size: 18, color: RC.fg(Color(0xFF113E2E))),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  tx(title),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: status == 'verified'
                      ? RC.bg(Color(0xFFDCFCE7))
                      : status == 'rejected'
                          ? RC.bg(Color(0xFFFEE2E2))
                          : RC.bg(Color(0xFFFEF3C7)),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  tx(status == 'verified'
                      ? 'پشتڕاستکراوە'
                      : status == 'rejected'
                          ? 'ڕەتکراوە'
                          : 'چاوەڕوان'),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: status == 'verified'
                        ? RC.bg(Color(0xFF16A34A))
                        : status == 'rejected'
                            ? RC.bg(Color(0xFFDC2626))
                            : RC.bg(Color(0xFFD97706)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: numberCtrl,
            decoration: InputDecoration(
              labelText: tx('ژمارەی بەڵگەنامە'),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              isDense: true,
            ),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            isExpanded: true,
            initialValue: status,
            decoration: InputDecoration(
              labelText: tx('دۆخی پشتڕاستکردنەوە'),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              isDense: true,
            ),
            items: [
              DropdownMenuItem(value: 'pending', child: Text(tx('چاوەڕوانی پشکنین'), maxLines: 1, overflow: TextOverflow.ellipsis)),
              DropdownMenuItem(value: 'verified', child: Text(tx('پشتڕاستکراوە'), maxLines: 1, overflow: TextOverflow.ellipsis)),
              DropdownMenuItem(value: 'rejected', child: Text(tx('ڕەتکراوە'), maxLines: 1, overflow: TextOverflow.ellipsis)),
            ],
            onChanged: (v) {
              if (v != null) onStatus(v);
            },
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  onPressed: onPick,
                  icon: const Icon(Icons.upload_file_rounded, size: 18),
                  label: Text(
                    tx(hasFile ? 'گۆڕینی وێنە / PDF' : 'بارکردنی وێنە / PDF'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              if (hasFile) ...[
                const SizedBox(width: 8),
                IconButton(
                  tooltip: tx('سڕینەوەی فایل'),
                  onPressed: onClear,
                  icon: Icon(Icons.delete_outline, color: RC.fg(Color(0xFFDC2626))),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          if (hasFile)
            InkWell(
              onTap: onPreview,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AdminSurfaces.of(context).card,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: RC.bg(Color(0xFFE2E8F0))),
                ),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: SizedBox(
                        width: 56,
                        height: 56,
                        child: hasPendingImage
                            ? Image.memory(
                                Uint8List.fromList(pendingBytes),
                                fit: BoxFit.cover,
                              )
                            : canShowNetworkThumb
                                ? Image.network(
                                    resolvedUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => ColoredBox(
                                      color: AdminSurfaces.of(context).chipFill,
                                      child: Icon(
                                        isPdf ? Icons.picture_as_pdf_rounded : Icons.broken_image_outlined,
                                        color: isPdf ? RC.fg(Color(0xFFDC2626)) : RC.bg(Color(0xFF64748B)),
                                      ),
                                    ),
                                  )
                                : ColoredBox(
                                    color: AdminSurfaces.of(context).chipFill,
                                    child: Icon(
                                      isPdf ? Icons.picture_as_pdf_rounded : Icons.image_outlined,
                                      color: isPdf ? RC.fg(Color(0xFFDC2626)) : RC.bg(Color(0xFF64748B)),
                                    ),
                                  ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tx(fileLabel),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            tx(isPdf ? 'PDF — کرتە بکە بۆ کردنەوە' : 'وێنە — کرتە بکە بۆ بینین'),
                            style: TextStyle(fontSize: 11, color: RC.fg(Color(0xFF64748B))),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      isPdf ? Icons.open_in_new_rounded : Icons.visibility_rounded,
                      color: RC.fg(Color(0xFF113E2E)),
                    ),
                  ],
                ),
              ),
            )
          else
            Row(
              children: [
                Icon(Icons.insert_drive_file_outlined, size: 16, color: RC.fg(Color(0xFF64748B))),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    tx('هیچ فایلێک هەڵنەبژێردراوە'),
                    style: TextStyle(fontSize: 11, color: RC.fg(Color(0xFF64748B))),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  void _showCourierDetailsDialog(CourierItem courier) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        insetPadding: AdminBreakpoints.dialogInset(ctx),
        contentPadding: AdminBreakpoints.dialogContentPadding(ctx),
        actionsOverflowButtonSpacing: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundImage: NetworkImage(courier.avatarUrl),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tx(courier.name),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                  ),
                  Directionality(
                    textDirection: TextDirection.ltr,
                    child: Text(
                      tx(courier.phone),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: RC.fg(Color(0xFF64748B))),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            _buildStatusBadge(courier.status),
          ],
        ),
        content: SizedBox(
          width: AdminBreakpoints.dialogWidth(ctx, max: 460),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: AdminBreakpoints.dialogContentMaxHeight(ctx, max: 540),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildDetailRow('شار / دەڤەر', courier.city),
                  const Divider(height: 16),
                  _buildDetailRow('ژمارەی ماڵەوە', courier.homePhone.isEmpty ? '—' : courier.homePhone, ltrValue: courier.homePhone.isNotEmpty),
                  const Divider(height: 16),
                  _buildDetailRow('جۆری خوێن', courier.bloodType.isEmpty ? '—' : courier.bloodType, ltrValue: true),
                  const Divider(height: 16),
                  _buildDetailRow('کارتی زانیاری', courier.infoCardNumber.isEmpty ? '—' : courier.infoCardNumber, ltrValue: courier.infoCardNumber.isNotEmpty),
                  const Divider(height: 16),
                  _buildDetailRow(
                    'کارتی نیشتیمانی',
                    _findDoc(courier.documents, 'national_id').documentNumber.isEmpty
                        ? '—'
                        : _findDoc(courier.documents, 'national_id').documentNumber,
                    ltrValue: _findDoc(courier.documents, 'national_id').documentNumber.isNotEmpty,
                  ),
                  const Divider(height: 16),
                  _buildDetailRow('داواکارییەکانی ئەمڕۆ', '${courier.todayOrders} داواکاری'),
                  const Divider(height: 16),
                  _buildDetailRow('جۆری ماتۆڕ', courier.motorType),
                  const Divider(height: 16),
                  _buildDetailRow('ژمارەی تابلۆی ماتۆڕ', courier.plateNumber, ltrValue: true),
                  const Divider(height: 16),
                  _buildDetailRow('ڕەنگی ماتۆڕ', '${courier.motorColor} • ${courier.modelYear}'),
                  const Divider(height: 16),
                  _buildDetailRow('پارەی کاش لەدەست (COD)', '${courier.cashCollected} د.ع'),
                  const Divider(height: 16),
                  _buildDetailRow('باڵانسی واڵێت', '${courier.walletBalance} د.ع'),
                  const Divider(height: 16),
                  _buildDetailRow(
                    AppStrings.tr('status', widget.lang),
                    courier.isVerified
                        ? AppStrings.statusLabel('approved', widget.lang)
                        : AppStrings.statusLabel('pending', widget.lang),
                  ),
                  const Divider(height: 16),
                  _buildDetailRow(
                    AppStrings.tr('language', widget.lang),
                    AppStrings.tr(
                      courier.language == 'ar'
                          ? 'lang_ar'
                          : courier.language == 'en'
                              ? 'lang_en'
                              : 'lang_ku',
                      widget.lang,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(tx('بەڵگەنامە یاساییەکان'), style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
                  ),
                  const SizedBox(height: 8),
                  ...(['info_card', 'national_id', 'driver_license', 'vehicle_registration'].map((type) {
                    final doc = _findDoc(courier.documents, type);
                    final statusKu = doc.status == 'verified'
                        ? 'پشتڕاستکراوە'
                        : doc.status == 'rejected'
                            ? 'ڕەتکراوە'
                            : 'چاوەڕوان';
                    final hasFile = doc.fileUrl != null && doc.fileUrl!.isNotEmpty;
                    final fileHint = !hasFile
                        ? 'بێ فایل'
                        : (_isPdfNameOrUrl(doc.fileUrl) ? 'PDF' : 'وێنە');
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              tx(_docTypeLabel(type)),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              tx('$statusKu • $fileHint'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: doc.status == 'verified'
                                    ? RC.bg(Color(0xFF16A34A))
                                    : doc.status == 'rejected'
                                        ? RC.bg(Color(0xFFDC2626))
                                        : RC.bg(Color(0xFFD97706)),
                              ),
                            ),
                          ),
                          if (hasFile) ...[
                            const SizedBox(width: 6),
                            IconButton(
                              tooltip: tx('بینین / کردنەوە'),
                              visualDensity: VisualDensity.compact,
                              constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
                              onPressed: () => _previewDocumentFile(
                                title: _docTypeLabel(type),
                                url: doc.fileUrl,
                              ),
                              icon: Icon(
                                _isPdfNameOrUrl(doc.fileUrl)
                                    ? Icons.picture_as_pdf_rounded
                                    : Icons.visibility_rounded,
                                size: 18,
                                color: RC.fg(Color(0xFF113E2E)),
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  })),
                ],
              ),
            ),
          ),
        ),
        actions: [
          OutlinedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              _showAddCourierDialog(existing: courier);
            },
            icon: const Icon(Icons.edit_rounded, size: 16),
            label: Text(tx('دەستکاریکردنی هەموو بەشەکان')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: RC.bg(const Color(0xFFDC2626)),
              foregroundColor: RC.fg(Colors.white),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            onPressed: () => Navigator.pop(ctx),
            child: Text(tx('داخستن'), style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool ltrValue = false}) {
    return ResponsiveDetailRow(
      label: label,
      value: value,
      ltrValue: ltrValue,
      labelStyle: TextStyle(color: AdminSurfaces.of(context).textSecondary, fontSize: 13, fontWeight: FontWeight.w600),
      valueStyle: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: RC.fg(Color(0xFF0F172A))),
    );
  }

  // ============================================================================
  // BUILD SCREEN
  // ============================================================================
  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: widget.lang == 'en' ? TextDirection.ltr : TextDirection.rtl,
      child: Container(
        color: RC.bg(Color(0xFFF8F9FA)),
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: AdminBreakpoints.pagePadH(context), vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Top Header Area (Title, Subtitle, Search, Bell, Profile)
              _buildTopHeader(),
              const SizedBox(height: 16),

              // 2. Action Button: + زیادکردنی ماتۆرسوار
              Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  Flexible(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: RC.bg(Color(0xFF113E2E)),
                        foregroundColor: RC.fg(Colors.white),
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () => _showAddCourierDialog(),
                      icon: Icon(Icons.add, size: 18, color: RC.fg(Colors.white)),
                      label: Text(
                        AppStrings.tr('add_courier', widget.lang),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 3. Row of 4 KPI Metric Cards (Right to Left)
              _buildKpiSummaryRow(),
              const SizedBox(height: 20),

              // 4. Main Two-Column Content: Left Column Table, Right Column Map
              LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth >= 1120;
                  if (isWide) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Left visually in RTL (Flex 62): Filter Bar & Couriers Table
                        Expanded(
                          flex: 62,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _buildFilterBar(),
                              const SizedBox(height: 14),
                              _buildCouriersTableCard(),
                            ],
                          ),
                        ),
                        const SizedBox(width: 20),
                        // Right visually in RTL (Flex 38): Couriers Map Card
                        Expanded(
                          flex: 38,
                          child: _buildCouriersMapCard(),
                        ),
                      ],
                    );
                  } else {
                    return Column(
                      children: [
                        _buildCouriersMapCard(),
                        const SizedBox(height: 20),
                        _buildFilterBar(),
                        const SizedBox(height: 14),
                        _buildCouriersTableCard(),
                      ],
                    );
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================================
  // 1. Top Header Widget
  // ============================================================================
  Widget _buildTopHeader() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 860;
        final titleWidget = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppStrings.tr('drivers_title', widget.lang),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: constraints.maxWidth < 400 ? 18 : 22,
                fontWeight: FontWeight.w900,
                color: AdminSurfaces.of(context).textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              AppStrings.tr('drivers_subtitle', widget.lang),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12.5,
                color: AdminSurfaces.of(context).textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        );

        final topActions = AdminTopBarRow(
          searchCtrl: _searchCtrl,
          hintText: AppStrings.tr('search_courier', widget.lang),
          onSearchChanged: (_) => setState(() {}),
        );

        if (constraints.maxWidth < AdminBreakpoints.headerCompact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              topActions,
              const SizedBox(height: 12),
              titleWidget,
            ],
          );
        } else if (isNarrow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              titleWidget,
              const SizedBox(height: 12),
              topActions,
            ],
          );
        } else {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: titleWidget),
              const SizedBox(width: 12),
              Flexible(child: topActions),
            ],
          );
        }
      },
    );
  }

  // ============================================================================
  // 2. Top 4 Metric KPI Summary Cards (Matching Screenshot)
  // ============================================================================
  Widget _buildKpiSummaryRow() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final cols = width >= 960 ? 4 : (width >= 560 ? 2 : 1);
        final cardWidth = AdminBreakpoints.cardWidth(width, cols, 16);
        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            // Card 1: کۆی ماتۆرسواران (Rightmost)
            SizedBox(
              width: cardWidth,
              child: _buildMetricCard(
                title: AppStrings.tr('kpi_total_couriers', widget.lang),
                value: _totalDriversKPI,
                icon: Icons.groups_rounded,
                iconBg: RC.bg(Color(0xFFF1F5F9)),
                iconColor: RC.fg(Color(0xFF475569)),
              ),
            ),
            // Card 2: چالاک
            SizedBox(
              width: cardWidth,
              child: _buildMetricCard(
                title: AppStrings.tr('active', widget.lang),
                value: _activeDriversKPI,
                icon: Icons.circle,
                iconBg: RC.bg(Color(0xFFDCFCE7)),
                iconColor: RC.fg(Color(0xFF16A34A)),
              ),
            ),
            // Card 3: لە دلیڤەری
            SizedBox(
              width: cardWidth,
              child: _buildMetricCard(
                title: AppStrings.tr('kpi_in_delivery', widget.lang),
                value: _inDeliveryKPI,
                icon: Icons.two_wheeler_rounded,
                iconBg: RC.bg(Color(0xFFEFF6FF)),
                iconColor: RC.fg(Color(0xFF2563EB)),
              ),
            ),
            // Card 4: چاوەڕوانی پەسەندکردن (Leftmost)
            SizedBox(
              width: cardWidth,
              child: _buildMetricCard(
                title: AppStrings.tr('kpi_pending_approval', widget.lang),
                value: _pendingApprovalKPI,
                icon: Icons.access_time_rounded,
                iconBg: RC.bg(Color(0xFFFEF3C7)),
                iconColor: RC.fg(Color(0xFFD97706)),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AdminSurfaces.of(context).card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AdminSurfaces.of(context).hairline),
        boxShadow: [
          BoxShadow(
            color: RC.bg(Colors.black).withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Icon Box
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: icon == Icons.circle ? 16 : 22),
          ),
          const SizedBox(width: 10),
          // Value and Title
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  tx(title),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AdminSurfaces.of(context).textSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      tx(value),
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: AdminSurfaces.of(context).textPrimary,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================================
  // Filter Bar (Calendar, City, Status)
  // ============================================================================
  Widget _buildFilterBar() {
    return Wrap(
      spacing: 10,
      runSpacing: 8,
      alignment: WrapAlignment.end,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        // Date Dropdown: 'ئەمڕۆ'
        _buildDropdownPill(
          icon: Icons.calendar_today_outlined,
          value: _selectedDate,
          items: [
            'today',
            'yesterday',
            'days7',
            'this_month',
          ],
          labels: [
            AppStrings.tr('today', widget.lang),
            AppStrings.tr('yesterday', widget.lang),
            AppStrings.tr('days_7', widget.lang),
            AppStrings.tr('this_month', widget.lang),
          ],
          onChanged: (v) => setState(() => _selectedDate = v ?? 'today'),
        ),
        _buildDropdownPill(
          icon: Icons.location_on_outlined,
          value: _selectedCity,
          items: ['all', ...AppStrings.knownCitiesKu],
          labels: [
            AppStrings.tr('all_cities', widget.lang),
            for (final c in AppStrings.knownCitiesKu) AppStrings.cityLabel(c, widget.lang),
          ],
          onChanged: (v) => setState(() => _selectedCity = v ?? 'all'),
        ),
        _buildDropdownPill(
          icon: Icons.filter_list_rounded,
          value: _selectedStatus,
          items: const ['all', 'active', 'on_the_way', 'offline'],
          labels: [
            AppStrings.tr('all_statuses', widget.lang),
            AppStrings.tr('active', widget.lang),
            AppStrings.tr('kpi_in_delivery', widget.lang),
            AppStrings.tr('inactive', widget.lang),
          ],
          onChanged: (v) => setState(() => _selectedStatus = v ?? 'all'),
        ),
      ],
    );
  }

  Widget _buildDropdownPill({
    required IconData icon,
    required String value,
    required List<String> items,
    List<String>? labels,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      constraints: const BoxConstraints(minHeight: 38),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: AdminSurfaces.of(context).card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: RC.bg(Color(0xFFE2E8F0))),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isDense: true,
          icon: Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: RC.fg(Color(0xFF64748B))),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AdminSurfaces.of(context).textPrimary,
          ),
          items: [
            for (var i = 0; i < items.length; i++)
              DropdownMenuItem<String>(
                value: items[i],
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 15, color: RC.fg(Color(0xFF64748B))),
                    const SizedBox(width: 6),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 160),
                      child: Text(
                        tx(labels != null && i < labels.length ? labels[i] : items[i]),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }

  // ============================================================================
  // Right Card: شوێنی ماتۆرسواران (Couriers Live Map Card)
  // ============================================================================
  Widget _buildCouriersMapCard() {
    final mapHeight = math.min(380.0, math.max(220.0, MediaQuery.sizeOf(context).height * 0.42));
    return Container(
      decoration: BoxDecoration(
        color: AdminSurfaces.of(context).card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AdminSurfaces.of(context).hairline),
        boxShadow: [
          BoxShadow(
            color: RC.bg(Colors.black).withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header: Location Pin + شوێنی ماتۆرسواران, Expand Icon
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Icon(Icons.location_on_rounded, size: 18, color: AdminSurfaces.of(context).textPrimary),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          AppStrings.tr('couriers_map', widget.lang),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w900,
                            color: AdminSurfaces.of(context).textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: () {
                    _mapController.move(const LatLng(34.6295, 45.3159), 14.2);
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Icons.crop_free_rounded, size: 18, color: RC.fg(Color(0xFF64748B))),
                  ),
                ),
              ],
            ),
          ),

          // Interactive Map Canvas
          SizedBox(
            height: mapHeight,
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: LatLng(34.6295, 45.3159),
                initialZoom: 13.5,
                minZoom: 10.0,
                maxZoom: 18.0,
                backgroundColor: RC.bg(Color(0xFFF1F5F9)),
              ),
              children: [
                MapboxTiles.layer(
                  style: MapboxStyle.streets,
                  userAgentPackageName: 'iq.rega.admin',
                  tileProvider: NetworkTileProvider(),
                ),
                MarkerLayer(
                  markers: [
                    // Center label: کەلار city center (Mapbox: 34.6295, 45.3159)
                    Marker(
                      point: const LatLng(34.6295, 45.3159),
                      width: 70,
                      height: 28,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: RC.bg(Colors.white).withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: RC.bg(Color(0xFFE2E8F0))),
                        ),
                        child: Center(
                          child: Text(
                            tx('کەلار'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: RC.fg(Color(0xFF0F172A))),
                          ),
                        ),
                      ),
                    ),

                    // Online drivers with live GPS only
                    ..._couriers.where((c) => c.status == 'active' || c.status == 'on_the_way').map((c) {
                      final isDelivery = c.status == 'on_the_way';
                      return Marker(
                        point: c.location,
                        width: 32,
                        height: 32,
                        child: Tooltip(
                          message: c.name,
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isDelivery ? RC.bg(Color(0xFFEA580C)) : RC.bg(Color(0xFF16A34A)),
                              border: Border.all(color: RC.bg(Colors.white), width: 2),
                              boxShadow: [
                                BoxShadow(color: RC.bg(Colors.black26), blurRadius: 4, offset: Offset(0, 2)),
                              ],
                            ),
                            child: Center(
                              child: Icon(
                                Icons.two_wheeler_rounded,
                                size: 16,
                                color: AdminSurfaces.of(context).card,
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ],
            ),
          ),

          // Map Legend at bottom
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Wrap(
              alignment: WrapAlignment.spaceEvenly,
              spacing: 12,
              runSpacing: 8,
              children: [
                _LegendItem(
                  color: RC.bg(Color(0xFF16A34A)),
                  text: '${AppStrings.tr('active', widget.lang)} ($_activeDriversKPI)',
                ),
                _LegendItem(
                  color: RC.bg(Color(0xFFEA580C)),
                  text: '${AppStrings.tr('kpi_in_delivery', widget.lang)} ($_inDeliveryKPI)',
                ),
                _LegendItem(
                  color: AdminSurfaces.of(context).textTertiary,
                  text: '${AppStrings.tr('inactive', widget.lang)} (${AppStrings.digits(_couriers.where((c) => c.status == 'offline').length, widget.lang)})',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================================
  // Left Card: Couriers Table Card
  // ============================================================================
  Widget _buildCouriersTableCard() {
    final list = _filteredCouriers;

    return Container(
      decoration: BoxDecoration(
        color: AdminSurfaces.of(context).card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AdminSurfaces.of(context).hairline),
        boxShadow: [
          BoxShadow(
            color: RC.bg(Colors.black).withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < AdminBreakpoints.phone) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (list.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(40),
                    child: Center(
                      child: Text(tx('هیچ ماتۆرسوارێک بەردەست نییە'), style: TextStyle(color: RC.fg(Color(0xFF94A3B8)))),
                    ),
                  )
                else
                  ...list.map(_buildCourierMobileCard),
                _couriersPaginationFooter(list),
              ],
            );
          }
          final tableWidth = constraints.maxWidth < 760 ? 760.0 : constraints.maxWidth;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Scrollbar(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: tableWidth,
                    child: Column(
                      children: [
                        // Table Headers
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                          decoration: BoxDecoration(
                            color: AdminSurfaces.of(context).mutedFill,
                            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                            border: Border(bottom: BorderSide(color: AdminSurfaces.of(context).hairline)),
                          ),
                          child: Row(
                            children: [
                              Expanded(flex: 3, child: Text(tx('ماتۆرسوار'), textAlign: TextAlign.start, style: _headerStyle)),
                              const SizedBox(width: 8),
                              Expanded(flex: 3, child: Text(tx('ژمارەی مۆبایل'), textAlign: TextAlign.start, style: _headerStyle)),
                              const SizedBox(width: 8),
                              Expanded(flex: 2, child: Text(tx('شار'), textAlign: TextAlign.start, style: _headerStyle)),
                              const SizedBox(width: 8),
                              Expanded(flex: 2, child: Text(tx('داواکارییەکانی ئەمڕۆ'), textAlign: TextAlign.center, style: _headerStyle)),
                              const SizedBox(width: 8),
                              Expanded(flex: 2, child: Text(tx('دۆخ'), textAlign: TextAlign.center, style: _headerStyle)),
                              const SizedBox(width: 8),
                              Expanded(flex: 2, child: Text(tx('کردار'), textAlign: TextAlign.end, style: _headerStyle)),
                            ],
                          ),
                        ),

                        // Table Rows
                        if (list.isEmpty)
                          Padding(
                            padding: const EdgeInsets.all(40),
                            child: Center(
                              child: Text(tx('هیچ ماتۆرسوارێک بەردەست نییە'), style: TextStyle(color: RC.fg(Color(0xFF94A3B8)))),
                            ),
                          )
                        else
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: list.length,
                            separatorBuilder: (_, _) => Divider(height: 1, color: AdminSurfaces.of(context).hairline),
                            itemBuilder: (context, index) {
                              final c = list[index];
                              return Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                child: Row(
                                  children: [
                                    // 1. Driver Name + Avatar
                                    Expanded(
                                      flex: 3,
                                      child: Row(
                                        children: [
                                          CircleAvatar(
                                            radius: 14,
                                            backgroundImage: NetworkImage(c.avatarUrl),
                                          ),
                                          const SizedBox(width: 8),
                                          Flexible(
                                            child: Text(
                                              tx(c.name),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontWeight: FontWeight.w800,
                                                fontSize: 12.5,
                                                color: RC.fg(Color(0xFF1E293B)),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),

                                    // 2. Phone
                                    Expanded(
                                      flex: 3,
                                      child: Align(
                                        alignment: AlignmentDirectional.centerStart,
                                        child: Directionality(
                                          textDirection: TextDirection.ltr,
                                          child: Text(
                                            tx(c.phone),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                              color: AdminSurfaces.of(context).textPrimary,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),

                                    // 3. City
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        tx(c.city),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        textAlign: TextAlign.start,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: AdminSurfaces.of(context).textPrimary,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),

                                    // 4. Today Orders
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        tx('${c.todayOrders}'),
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w800,
                                          color: AdminSurfaces.of(context).textPrimary,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),

                                    // 5. Status
                                    Expanded(
                                      flex: 2,
                                      child: Center(child: _buildStatusBadge(c.status)),
                                    ),
                                    const SizedBox(width: 8),

                                    // 6. Action Buttons [✏️] [👁]
                                    Expanded(
                                      flex: 2,
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.end,
                                        children: [
                                          // View details button
                                          InkWell(
                                            onTap: () => _showCourierDetailsDialog(c),
                                            borderRadius: BorderRadius.circular(6),
                                            child: Container(
                                              padding: const EdgeInsets.all(6),
                                              decoration: BoxDecoration(
                                                color: AdminSurfaces.of(context).chipFill,
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Icon(Icons.visibility_outlined, size: 16, color: RC.fg(Color(0xFF475569))),
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          // Edit button
                                          InkWell(
                                            onTap: () => _showAddCourierDialog(existing: c),
                                            borderRadius: BorderRadius.circular(6),
                                            child: Container(
                                              padding: const EdgeInsets.all(6),
                                              decoration: BoxDecoration(
                                                color: AdminSurfaces.of(context).chipFill,
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Icon(Icons.edit_outlined, size: 16, color: RC.fg(Color(0xFF475569))),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                ),
              ),

              _couriersPaginationFooter(list),
            ],
          );
        },
      ),
    );
  }

  Widget _couriersPaginationFooter(List<CourierItem> list) {
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: AdminSurfaces.of(context).hairline)),
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        runSpacing: 10,
        children: [
          Text(
            tx('${_toDigits(list.length)} لە ${_toDigits(_couriers.length)} دانە نمایش دەکرێت'),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AdminSurfaces.of(context).textSecondary,
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildPageNavBtn(
                  icon: isRtl ? Icons.chevron_right_rounded : Icons.chevron_left_rounded,
                  onTap: () {},
                ),
                const SizedBox(width: 4),
                _buildPageNumberBtn(page: 1, active: _currentPage == 1),
                const SizedBox(width: 4),
                _buildPageNumberBtn(page: 2, active: _currentPage == 2),
                const SizedBox(width: 4),
                _buildPageNumberBtn(page: 3, active: _currentPage == 3),
                const SizedBox(width: 4),
                _buildPageNavBtn(
                  icon: isRtl ? Icons.chevron_left_rounded : Icons.chevron_right_rounded,
                  onTap: () {},
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCourierMobileCard(CourierItem c) {
    final surfaces = AdminSurfaces.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: surfaces.hairline)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(radius: 18, backgroundImage: NetworkImage(c.avatarUrl)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(tx(c.name), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
              ),
              const SizedBox(width: 8),
              _buildStatusBadge(c.status),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 2,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                tx('${c.city} •'),
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: surfaces.textSecondary),
              ),
              Directionality(
                textDirection: TextDirection.ltr,
                child: Text(
                  tx(c.phone),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: surfaces.textSecondary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            tx('ئەمڕۆ: ${c.todayOrders} داواکاری'),
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: RC.fg(Color(0xFFEA580C))),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              InkWell(
                onTap: () => _showCourierDetailsDialog(c),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(color: surfaces.chipFill, borderRadius: BorderRadius.circular(8)),
                  child: Icon(Icons.visibility_outlined, size: 17, color: RC.fg(Color(0xFF475569))),
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: () => _showAddCourierDialog(existing: c),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(color: surfaces.chipFill, borderRadius: BorderRadius.circular(8)),
                  child: Icon(Icons.edit_outlined, size: 17, color: RC.fg(Color(0xFF475569))),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    String label;
    Color bg;
    Color text;

    switch (status) {
      case 'on_the_way':
        label = AppStrings.tr('kpi_in_delivery', widget.lang);
        bg = RC.bg(Color(0xFFFFEDD5));
        text = RC.bg(Color(0xFFEA580C));
        break;
      case 'offline':
        label = AppStrings.tr('inactive', widget.lang);
        bg = RC.bg(Color(0xFFF1F5F9));
        text = RC.bg(Color(0xFF64748B));
        break;
      case 'active':
      default:
        label = AppStrings.tr('active', widget.lang);
        bg = RC.bg(Color(0xFFDCFCE7));
        text = RC.bg(Color(0xFF16A34A));
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        tx(label),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
          color: text,
        ),
      ),
    );
  }

  Widget _buildPageNumberBtn({required int page, required bool active}) {
    return InkWell(
      onTap: () => setState(() => _currentPage = page),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: active ? RC.bg(Color(0xFF113E2E)) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            tx('$page'),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: active ? RC.bg(Colors.white) : RC.bg(Color(0xFF64748B)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPageNavBtn({required IconData icon, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Icon(icon, size: 18, color: RC.fg(Color(0xFF94A3B8))),
        ),
      ),
    );
  }

  TextStyle get _headerStyle => TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w800,
    color: AdminSurfaces.of(context).textSecondary,
  );
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String text;

  const _LegendItem({required this.color, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          tx(text),
          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: RC.fg(Color(0xFF64748B))),
        ),
      ],
    );
  }
}
