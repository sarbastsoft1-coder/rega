import 'package:intl/intl.dart';

import '../api/api_client.dart';
import 'backup_download_io.dart' if (dart.library.html) 'backup_download_web.dart';

/// Downloads full multi-sheet REGA Excel backups from the Laravel API.
class ExcelBackupService {
  ExcelBackupService(this.api);

  final ApiClient api;

  /// Manual full backup from `GET /admin/backup/export`.
  Future<String> downloadFullBackup() async {
    final result = await api.downloadExcelBackupExport();
    triggerBrowserDownload(result.bytes, result.fileName);
    return result.fileName;
  }

  /// Download a previously stored weekly/monthly/manual file.
  Future<String> downloadStoredBackup(String fileName) async {
    final result = await api.downloadStoredExcelBackup(fileName);
    triggerBrowserDownload(result.bytes, result.fileName);
    return result.fileName;
  }

  Future<List<Map<String, dynamic>>> listStoredBackups({int limit = 40}) {
    return api.listExcelBackups(limit: limit);
  }

  static String formatBytes(int size) {
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) {
      return '${(size / 1024).toStringAsFixed(1)} KB';
    }
    return '${(size / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  static String formatModified(String? iso) {
    if (iso == null || iso.isEmpty) return '—';
    final dt = DateTime.tryParse(iso);
    if (dt == null) return iso;
    return DateFormat('yyyy-MM-dd HH:mm').format(dt.toLocal());
  }
}
