import 'package:flutter/material.dart';
import 'package:jitan_core/jitan_core.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../l10n/admin_text_keys.dart';
import 'schedule_rows.dart';
import 'schedule_summary_text.dart';

/// What HR chose in a schedule's pop-up; the page does it and says so.
enum ScheduleRowAction { edit, openGroup, removeWorkHours, removeBreaks }

/// Opens [row]'s pop-up.
Future<ScheduleRowAction?> showScheduleDetailsDialog(BuildContext context, {required ScheduleRow row}) =>
    showJitanModal<ScheduleRowAction>(context, builder: (_) => _ScheduleDetailsDialog(row: row));

/// Figma `HR / Schedules V3 — a schedule` (`1552:386`): the group's days,
/// hours, break, tolerance and rounding in one calm card; Remove hours and
/// Remove break as quiet red links, Open group and Edit as buttons.
class _ScheduleDetailsDialog extends StatelessWidget {
  const _ScheduleDetailsDialog({required this.row});

  final ScheduleRow row;

  String _statusLine(BuildContext context) => context.t(
    AdminTextKeys.scheduleStatusLine,
    args: {
      'status': context.t(row.status == ScheduleRowStatus.active ? CommonTextKeys.statusActive : AdminTextKeys.scheduleStatusDiffer),
      'employees': context.tPlural(AdminTextKeys.scheduleEmployees, row.schedule.singleGroupEmployeeCount),
    },
  );

  Widget _details(BuildContext context) {
    final variant = row.variant;
    if (variant == null) {
      return Text(context.t(AdminTextKeys.scheduleDifferNote), style: JitanTextStyles.tableCell.copyWith(color: JitanColors.inkMuted));
    }
    final t = TranslationScope.of(context);
    final first = variant.workDays.where((d) => d.start != null && d.finish != null).firstOrNull;
    final lengths = {for (final b in variant.breaks) b.lengthMinutes};
    final none = context.t(CommonTextKeys.valueUnavailable);
    return JitanSettingsCard(
      rows: [
        JitanSettingsRow(label: context.t(AdminTextKeys.scheduleRowWorkDays), value: JitanSettingsRow.text(workDaysText(t, variant))),
        JitanSettingsRow(label: context.t(AdminTextKeys.scheduleRowHours), value: JitanSettingsRow.text(workHoursText(t, variant))),
        JitanSettingsRow(
          label: context.t(AdminTextKeys.scheduleRowBreak),
          value: JitanSettingsRow.text(switch (lengths.length) {
            0 => none,
            1 => context.t(AdminTextKeys.scheduleBreakMinutes, args: {'minutes': lengths.single}),
            _ => breaksSummary(t, variant),
          }),
        ),
        if (first != null) ...[
          JitanSettingsRow(
            label: context.t(AdminTextKeys.scheduleRowTolerance),
            value: JitanSettingsRow.text(toleranceText(t, first.start!.toleranceMinutes, first.finish!.toleranceMinutes)),
          ),
          JitanSettingsRow(
            label: context.t(AdminTextKeys.scheduleRowRounding),
            value: JitanSettingsRow.text(roundingShortText(t, first.start!.rounding, first.finish!.rounding)),
          ),
        ],
      ],
    );
  }

  /// Remove hours and Remove break, quiet and red.
  Widget _removals(BuildContext context) {
    Widget link(String key, ScheduleRowAction action) => TextButton(
      onPressed: () => Navigator.of(context).pop(action),
      style: TextButton.styleFrom(
        foregroundColor: JitanColors.errorStrong,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        minimumSize: Size.zero,
      ),
      child: Text(context.t(key), style: JitanTextStyles.tableCellStrong.copyWith(fontSize: 13, color: JitanColors.errorStrong)),
    );
    return Wrap(
      spacing: 14,
      children: [
        if (row.hasWorkHours) link(AdminTextKeys.scheduleRemoveHours, ScheduleRowAction.removeWorkHours),
        if (row.hasBreaks) link(AdminTextKeys.scheduleRemoveBreak, ScheduleRowAction.removeBreaks),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < JitanDimensions.phoneBreakpoint;
    return JitanModal(
      width: 520,
      title: row.group.name,
      subtitle: _statusLine(context),
      onClose: () => Navigator.of(context).pop(),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 16,
        children: [
          _details(context),
          // On a phone they get a line of their own, under the details.
          if (narrow) Align(alignment: Alignment.centerLeft, child: _removals(context)),
        ],
      ),
      leadingActions: narrow ? const [] : [_removals(context)],
      actions: [
        Wrap(
          alignment: WrapAlignment.end,
          spacing: 10,
          runSpacing: 10,
          children: [
            JitanSecondaryButton(
              label: context.t(AdminTextKeys.scheduleOpenGroup),
              onPressed: () => Navigator.of(context).pop(ScheduleRowAction.openGroup),
            ),
            JitanPrimaryButton(
              label: context.t(AdminTextKeys.scheduleEdit),
              color: JitanColors.ink,
              onPressed: () => Navigator.of(context).pop(ScheduleRowAction.edit),
            ),
          ],
        ),
      ],
    );
  }
}

/// Figma "Remove break?" (`1547:393`): one plain question; `true` to go ahead.
Future<bool> confirmScheduleRemove(BuildContext context, {required ScheduleRow row, required ScheduleKind kind}) async =>
    await showJitanModal<bool>(
      context,
      builder: (dialog) {
        final hours = kind == ScheduleKind.workHours;
        return JitanModal(
          width: 440,
          title: dialog.t(
            hours ? AdminTextKeys.scheduleRemoveHoursTitle : AdminTextKeys.scheduleRemoveBreakTitle,
            args: {'group': row.group.name},
          ),
          subtitle: dialog.t(hours ? AdminTextKeys.scheduleRemoveHoursText : AdminTextKeys.scheduleRemoveBreakText),
          actions: [
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 12,
              runSpacing: 10,
              children: [
                JitanSecondaryButton(label: dialog.t(CommonTextKeys.cancel), onPressed: () => Navigator.of(dialog).pop(false)),
                JitanPrimaryButton(
                  label: dialog.t(hours ? AdminTextKeys.scheduleRemoveHours : AdminTextKeys.scheduleRemoveBreak),
                  color: JitanColors.errorStrong,
                  onPressed: () => Navigator.of(dialog).pop(true),
                ),
              ],
            ),
          ],
        );
      },
    ) ??
    false;
