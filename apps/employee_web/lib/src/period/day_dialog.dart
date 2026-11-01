import 'package:flutter/material.dart';
import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../common/web_text.dart';
import '../l10n/employee_web_text_keys.dart';
import 'add_time_dialog.dart';
import 'day_status.dart';

/// Opens [day]; `true` when something was sent to HR.
Future<bool> showDayDialog(
  BuildContext context, {
  required TimeRegistrationsApi api,
  required MyPeriodDay day,
  DateTime Function()? clock,
}) async {
  final boundary = await showJitanModal<RegistrationBoundary>(context, builder: (_) => _DayDialog(day: day));
  if (boundary == null || !context.mounted) return false;
  return showAddTimeDialog(context, api: api, date: day.date, boundary: boundary, clock: clock);
}

/// A day in one calm window (Figma `1499:595`) with, when something is
/// missing, the one thing to do about it.
class _DayDialog extends StatelessWidget {
  const _DayDialog({required this.day});

  final MyPeriodDay day;

  @override
  Widget build(BuildContext context) {
    final status = DayStatus.of(day);
    final record = day.day;
    final start = record?.start?.roundedLocal ?? record?.start?.actualLocal;
    final finish = record?.finish?.roundedLocal ?? record?.finish?.actualLocal;
    final missing = context.t(EmployeeWebTextKeys.dayMissing);
    final note = switch (status) {
      DayStatus.finishMissing => EmployeeWebTextKeys.dayFinishMissing,
      DayStatus.startMissing => EmployeeWebTextKeys.dayStartMissing,
      DayStatus.noRegistration => EmployeeWebTextKeys.dayNothing,
      DayStatus.waiting => EmployeeWebTextKeys.dayWaiting,
      _ => null,
    };
    final add = switch (status) {
      DayStatus.finishMissing => RegistrationBoundary.finish,
      DayStatus.startMissing || DayStatus.noRegistration => RegistrationBoundary.start,
      _ => null,
    };
    return JitanModal(
      width: 480,
      title: WebText.longDay(context, day.date),
      subtitle: note == null ? context.t(status.textKey) : context.t(note),
      onClose: () => Navigator.of(context).pop(),
      body: WebList(
        color: JitanColors.tableHeader,
        radius: 14,
        rows: [
          WebLabelRow(
            label: context.t(EmployeeWebTextKeys.dayStart),
            value: start ?? missing,
            valueColor: start == null ? JitanColors.warning : null,
          ),
          WebLabelRow(
            label: context.t(EmployeeWebTextKeys.dayFinish),
            value: finish ?? missing,
            valueColor: finish == null ? JitanColors.warning : null,
          ),
          if (day.scheduledStart != null && day.scheduledFinish != null)
            WebLabelRow(
              label: context.t(EmployeeWebTextKeys.dayPlanned),
              value: '${day.scheduledStart} – ${day.scheduledFinish}',
            ),
          if (day.registeredMinutes case final minutes?)
            WebLabelRow(label: context.t(EmployeeWebTextKeys.dayRegistered), value: WebText.duration(context, minutes)),
        ],
      ),
      actions: [
        JitanSecondaryButton(label: context.t(EmployeeWebTextKeys.close), onPressed: () => Navigator.of(context).pop()),
        if (add != null)
          JitanPrimaryButton(
            label: context.t(add == RegistrationBoundary.start ? EmployeeWebTextKeys.addStart : EmployeeWebTextKeys.addFinish),
            onPressed: () => Navigator.of(context).pop(add),
          ),
      ],
    );
  }
}
