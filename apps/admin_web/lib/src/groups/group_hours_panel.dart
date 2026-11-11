import 'package:flutter/material.dart';
import 'package:jitan_core/jitan_core.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../l10n/admin_text_keys.dart';
import '../schedules/schedule_summary_text.dart';

/// The group's one schedule, when its employees agree on one.
ScheduleVariant? configuredVariant(GroupSchedule? schedule) =>
    schedule?.status == GroupScheduleStatus.configured && schedule!.variants.length == 1 ? schedule.variants.single : null;

/// "Work hours & break" on the group page (Figma `HR / Groups V2 — a group`
/// `1554:101`, no hours yet `1556:937`): the grouped card of Schedules with
/// a small Edit, or one sentence and Set work hours while it has none.
class GroupHoursPanel extends StatelessWidget {
  const GroupHoursPanel({super.key, required this.schedule, required this.hasMembers, required this.onEdit});

  final GroupSchedule? schedule;
  final bool hasMembers;

  /// `null` while the group is inactive.
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final t = TranslationScope.of(context);
    final variant = configuredVariant(schedule);
    final differ = schedule?.status == GroupScheduleStatus.employeesDiffer;
    final title = Text(context.t(AdminTextKeys.groupDetailHoursPanel), style: JitanTextStyles.stateTitle.copyWith(fontSize: 18));
    final edit = onEdit;
    return JitanSurfaceCard(
      radius: JitanDimensions.tableCardRadius,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 16,
        children: [
          Row(
            children: [
              Expanded(child: title),
              if (variant != null && edit != null)
                TextButton(
                  onPressed: edit,
                  style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 6), minimumSize: const Size(0, 30)),
                  child: Text(context.t(AdminTextKeys.groupDetailEdit), style: JitanTextStyles.tableCellStrong.copyWith(color: JitanColors.vermilion)),
                ),
            ],
          ),
          if (variant != null) ...[
            _card(context, t, variant),
            Text(context.t(AdminTextKeys.groupDetailHoursAll), style: JitanTextStyles.stateMessage.copyWith(fontSize: 13)),
          ] else ...[
            Text(
              context.t(switch (schedule?.status) {
                GroupScheduleStatus.employeesDiffer => AdminTextKeys.groupDetailHoursDifferText,
                GroupScheduleStatus.noSingleGroupEmployees when hasMembers => AdminTextKeys.groupDetailHoursNoSingleText,
                _ => AdminTextKeys.groupDetailHoursEmptyText,
              }),
              style: JitanTextStyles.stateMessage.copyWith(fontSize: 14),
            ),
            if (edit != null)
              Align(
                alignment: Alignment.centerLeft,
                child: JitanPrimaryButton(
                  label: context.t(differ ? AdminTextKeys.groupPageEditHours : AdminTextKeys.groupPageSetHours),
                  onPressed: edit,
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _card(BuildContext context, Translations t, ScheduleVariant variant) {
    final first = variant.workDays.where((d) => d.start != null && d.finish != null).firstOrNull;
    final lengths = {for (final b in variant.breaks) b.lengthMinutes};
    return JitanSettingsCard(
      rows: [
        JitanSettingsRow(label: context.t(AdminTextKeys.scheduleRowWorkDays), value: JitanSettingsRow.text(workDaysText(t, variant))),
        JitanSettingsRow(label: context.t(AdminTextKeys.scheduleRowHours), value: JitanSettingsRow.text(workHoursText(t, variant))),
        JitanSettingsRow(
          label: context.t(AdminTextKeys.scheduleRowBreak),
          value: JitanSettingsRow.text(switch (lengths.length) {
            0 => context.t(AdminTextKeys.groupDetailNoBreak),
            1 => context.t(AdminTextKeys.scheduleBreakMinutes, args: {'minutes': lengths.single}),
            _ => breaksSummary(t, variant),
          }),
        ),
        if (first != null) ...[
          JitanSettingsRow(
            label: context.t(AdminTextKeys.scheduleRowTolerance),
            value: JitanSettingsRow.text(
              context.t(
                AdminTextKeys.groupDetailToleranceValue,
                args: {'arrival': first.start!.toleranceMinutes, 'leaving': first.finish!.toleranceMinutes},
              ),
            ),
          ),
          JitanSettingsRow(
            label: context.t(AdminTextKeys.scheduleRowRounding),
            value: JitanSettingsRow.text(roundingCompactText(t, first.start!.rounding, first.finish!.rounding)),
          ),
        ],
      ],
    );
  }
}
