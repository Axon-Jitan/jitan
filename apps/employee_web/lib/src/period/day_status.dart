import 'package:flutter/material.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../l10n/employee_web_text_keys.dart';

/// How a day stands, in the words of the Period page.
enum DayStatus {
  complete,
  working,
  finishMissing,
  startMissing,
  noRegistration,
  waiting,
  nonWork;

  static DayStatus of(MyPeriodDay day) => switch (day.day?.status) {
    TimeRecordStatus.missingFinish => finishMissing,
    TimeRecordStatus.missingStart => startMissing,
    // notStarted: only HR's Time records has it.
    TimeRecordStatus.noRegistration || TimeRecordStatus.notStarted || null => noRegistration,
    TimeRecordStatus.pendingReview => waiting,
    TimeRecordStatus.working => working,
    TimeRecordStatus.nonWork => nonWork,
    _ => complete,
  };

  bool get needsAction => this == finishMissing || this == startMissing || this == noRegistration;

  String get textKey => switch (this) {
    complete => EmployeeWebTextKeys.statusComplete,
    working => EmployeeWebTextKeys.statusWorking,
    finishMissing => EmployeeWebTextKeys.statusFinishMissing,
    startMissing => EmployeeWebTextKeys.statusStartMissing,
    noRegistration => EmployeeWebTextKeys.statusNoRegistration,
    waiting => EmployeeWebTextKeys.statusWaiting,
    nonWork => EmployeeWebTextKeys.statusNonWork,
  };
}

/// The status with its dot (Figma `1499:478`).
class DayStatusLabel extends StatelessWidget {
  const DayStatusLabel({super.key, required this.status});

  final DayStatus status;

  @override
  Widget build(BuildContext context) {
    final color = status.needsAction ? JitanColors.warning : JitanColors.success;
    return Row(
      spacing: 8,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: status == DayStatus.nonWork ? JitanColors.inkMuted : color, shape: BoxShape.circle),
        ),
        Flexible(
          child: Text(
            context.t(status.textKey),
            overflow: TextOverflow.ellipsis,
            style: JitanTextStyles.tableCell.copyWith(color: status.needsAction ? JitanColors.warning : JitanColors.ink),
          ),
        ),
      ],
    );
  }
}
