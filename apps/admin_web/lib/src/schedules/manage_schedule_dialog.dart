import 'package:flutter/material.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../l10n/admin_text_keys.dart';
import 'schedule_rows.dart';
import 'schedules_table.dart';

/// Opens "Manage schedules" for [row]; completes with what HR picked, or
/// `null` when closed.
Future<ScheduleRowAction?> showManageScheduleDialog(BuildContext context, {required ScheduleRow row}) =>
    showJitanModal<ScheduleRowAction>(context, builder: (_) => ManageScheduleDialog(row: row));

/// Figma `HR / Schedules — Manage actions` (1359:2): the row's "···" opens
/// this choice. With one row per group (1458:2) it offers the group's page,
/// Edit schedule, and removing the work hours or the break on their own.
class ManageScheduleDialog extends StatelessWidget {
  const ManageScheduleDialog({super.key, required this.row});

  final ScheduleRow row;

  @override
  Widget build(BuildContext context) {
    return JitanModal(
      width: 480,
      title: context.t(AdminTextKeys.scheduleManageTitle),
      subtitle: row.group.name,
      onClose: () => Navigator.of(context).pop(),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Choice(
            title: context.t(AdminTextKeys.scheduleManageOpen),
            text: context.t(AdminTextKeys.scheduleManageOpenText),
            onTap: () => Navigator.of(context).pop(ScheduleRowAction.openGroup),
          ),
          const Divider(height: 1, color: JitanColors.inputBorder),
          _Choice(
            title: context.t(AdminTextKeys.scheduleManageEdit),
            text: context.t(AdminTextKeys.scheduleManageEditWhole),
            onTap: () => Navigator.of(context).pop(ScheduleRowAction.edit),
          ),
          if (row.hasWorkHours) ...[
            const Divider(height: 1, color: JitanColors.inputBorder),
            _Choice(
              title: context.t(AdminTextKeys.scheduleManageRemoveWorkHours),
              text: context.t(AdminTextKeys.scheduleManageRemoveWorkHoursText),
              destructive: true,
              onTap: () => Navigator.of(context).pop(ScheduleRowAction.removeWorkHours),
            ),
          ],
          if (row.hasBreaks) ...[
            const Divider(height: 1, color: JitanColors.inputBorder),
            _Choice(
              title: context.t(AdminTextKeys.scheduleManageRemoveBreak),
              text: context.t(AdminTextKeys.scheduleManageRemoveBreakText),
              destructive: true,
              onTap: () => Navigator.of(context).pop(ScheduleRowAction.removeBreaks),
            ),
          ],
        ],
      ),
    );
  }
}

class _Choice extends StatelessWidget {
  const _Choice({required this.title, required this.text, required this.onTap, this.destructive = false});

  final String title;
  final String text;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(12),
    hoverColor: JitanColors.warmWhite,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: JitanTextStyles.stateTitle.copyWith(color: destructive ? JitanColors.vermilion : JitanColors.ink),
                ),
                const SizedBox(height: 4),
                Text(text, style: JitanTextStyles.stateMessage.copyWith(fontSize: 13)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: JitanColors.inkMuted),
        ],
      ),
    ),
  );
}
