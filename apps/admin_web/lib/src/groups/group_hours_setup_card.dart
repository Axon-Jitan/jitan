import 'package:flutter/material.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../l10n/admin_text_keys.dart';

/// The group page while the group has no work hours of its own (Figma
/// `1462:2`): one calm card that says so and offers "Set work hours", in
/// place of summary cards that would all read "Not set".
class GroupHoursSetupCard extends StatelessWidget {
  const GroupHoursSetupCard({super.key, required this.schedule, required this.hasMembers, required this.onSet});

  final GroupSchedule? schedule;
  final bool hasMembers;

  /// `null` while the group is inactive.
  final VoidCallback? onSet;

  @override
  Widget build(BuildContext context) {
    final differ = schedule?.status == GroupScheduleStatus.employeesDiffer;
    final text = context.t(switch (schedule?.status) {
      GroupScheduleStatus.employeesDiffer => AdminTextKeys.groupDetailHoursDifferText,
      GroupScheduleStatus.noSingleGroupEmployees when hasMembers => AdminTextKeys.groupDetailHoursNoSingleText,
      _ => AdminTextKeys.groupDetailHoursEmptyText,
    });
    final button = JitanPrimaryButton(
      label: context.t(differ ? AdminTextKeys.groupPageEditHours : AdminTextKeys.groupPageSetHours),
      onPressed: onSet,
    );
    final words = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.t(differ ? AdminTextKeys.groupDetailSetupDiffer : AdminTextKeys.groupDetailSetupTitle),
          style: JitanTextStyles.stateTitle.copyWith(fontSize: 18),
        ),
        const SizedBox(height: 6),
        Text(text, style: JitanTextStyles.stateMessage),
      ],
    );
    const icon = DecoratedBox(
      decoration: BoxDecoration(color: JitanColors.inputFill, shape: BoxShape.circle),
      child: SizedBox.square(dimension: 48, child: Icon(Icons.schedule, size: 22, color: JitanColors.ink)),
    );
    return JitanSurfaceCard(
      radius: JitanDimensions.tableCardRadius,
      padding: const EdgeInsets.all(24),
      child: LayoutBuilder(
        builder: (context, constraints) => constraints.maxWidth >= 640
            ? Row(
                children: [
                  icon,
                  const SizedBox(width: 18),
                  Expanded(child: words),
                  const SizedBox(width: 24),
                  button,
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [icon, const SizedBox(height: 14), words, const SizedBox(height: 18), button],
              ),
      ),
    );
  }
}
