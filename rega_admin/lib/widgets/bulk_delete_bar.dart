import 'package:flutter/material.dart';

import '../core/localization/app_strings.dart';
import '../core/theme/admin_breakpoints.dart';
import '../core/theme/app_theme.dart';

/// Result of a sequential bulk-delete run.
class BulkDeleteResult {
  const BulkDeleteResult({required this.ok, required this.failed});

  final int ok;
  final int failed;

  int get total => ok + failed;
  bool get allOk => failed == 0 && ok > 0;
}

/// Confirm + run helpers shared by every admin list screen.
class BulkDeleteActions {
  BulkDeleteActions._();

  static Future<bool> confirm({
    required BuildContext context,
    required String lang,
    required int count,
    required bool deleteAll,
  }) async {
    if (count <= 0) return false;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        insetPadding: AdminBreakpoints.dialogInset(ctx),
        contentPadding: AdminBreakpoints.dialogContentPadding(ctx),
        actionsOverflowButtonSpacing: 8,
        title: Text(
          AppStrings.tr('delete', lang),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        content: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: AdminBreakpoints.dialogWidth(ctx, max: 440),
            maxHeight: AdminBreakpoints.dialogContentMaxHeight(ctx, max: 280),
          ),
          child: SingleChildScrollView(
            child: Text(
              AppStrings.trParams(
                deleteAll ? 'bulk_confirm_all' : 'bulk_confirm_selected',
                lang,
                {'count': '$count'},
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(AppStrings.tr('cancel', lang)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: RegaColors.crimson,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(AppStrings.tr('delete', lang)),
          ),
        ],
      ),
    );
    return ok == true;
  }

  /// Deletes [ids] one-by-one via [deleteOne]. Continues after individual failures.
  static Future<BulkDeleteResult> run({
    required Iterable<int> ids,
    required Future<void> Function(int id) deleteOne,
  }) async {
    var ok = 0;
    var failed = 0;
    for (final id in ids) {
      try {
        await deleteOne(id);
        ok++;
      } catch (_) {
        failed++;
      }
    }
    return BulkDeleteResult(ok: ok, failed: failed);
  }

  static String resultMessage(String lang, BulkDeleteResult result) {
    if (result.allOk) {
      return AppStrings.trParams('bulk_deleted_ok', lang, {'count': '${result.ok}'});
    }
    return AppStrings.trParams('bulk_deleted_partial', lang, {
      'ok': '${result.ok}',
      'fail': '${result.failed}',
    });
  }
}

/// Top-bar actions: Select / Select all / Delete selected / Delete all / Cancel.
class BulkDeleteBar extends StatelessWidget {
  const BulkDeleteBar({
    super.key,
    required this.lang,
    required this.selectionMode,
    required this.selectedCount,
    required this.totalCount,
    required this.onToggleSelectionMode,
    required this.onSelectAll,
    required this.onClearSelection,
    required this.onDeleteSelected,
    required this.onDeleteAll,
    this.busy = false,
    this.extraActions,
  });

  final String lang;
  final bool selectionMode;
  final int selectedCount;
  final int totalCount;
  final VoidCallback onToggleSelectionMode;
  final VoidCallback onSelectAll;
  final VoidCallback onClearSelection;
  final VoidCallback onDeleteSelected;
  final VoidCallback onDeleteAll;
  final bool busy;
  final List<Widget>? extraActions;

  @override
  Widget build(BuildContext context) {
    final empty = totalCount <= 0;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        ...?extraActions,
        if (!selectionMode) ...[
          OutlinedButton.icon(
            onPressed: empty || busy ? null : onToggleSelectionMode,
            icon: const Icon(Icons.checklist_rounded, size: 18),
            label: Text(AppStrings.tr('bulk_select', lang)),
          ),
          ElevatedButton.icon(
            onPressed: empty || busy ? null : onDeleteAll,
            style: ElevatedButton.styleFrom(
              backgroundColor: RegaColors.crimson,
              foregroundColor: Colors.white,
            ),
            icon: busy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.delete_forever_rounded, size: 18),
            label: Text(AppStrings.tr('bulk_delete_all', lang)),
          ),
        ] else ...[
          OutlinedButton.icon(
            onPressed: busy ? null : onSelectAll,
            icon: const Icon(Icons.select_all_rounded, size: 18),
            label: Text(AppStrings.tr('bulk_select_all', lang)),
          ),
          ElevatedButton.icon(
            onPressed: selectedCount <= 0 || busy ? null : onDeleteSelected,
            style: ElevatedButton.styleFrom(
              backgroundColor: RegaColors.crimson,
              foregroundColor: Colors.white,
            ),
            icon: busy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.delete_outline_rounded, size: 18),
            label: Text(
              AppStrings.trParams('bulk_delete_selected', lang, {
                'count': '$selectedCount',
              }),
            ),
          ),
          TextButton(
            onPressed: busy ? null : onClearSelection,
            child: Text(AppStrings.tr('bulk_cancel_select', lang)),
          ),
        ],
      ],
    );
  }
}

/// Checkbox badge for cards / tiles while selection mode is active.
class BulkSelectBadge extends StatelessWidget {
  const BulkSelectBadge({
    super.key,
    required this.selected,
    this.onChanged,
  });

  final bool selected;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onChanged == null ? null : () => onChanged!(!selected),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: selected ? RegaColors.orange : Colors.white.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected ? RegaColors.orange : const Color(0xFFCBD5E1),
              width: 1.5,
            ),
          ),
          child: selected
              ? const Icon(Icons.check_rounded, size: 18, color: Colors.white)
              : null,
        ),
      ),
    );
  }
}
