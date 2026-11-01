import 'package:flutter/material.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../common/web_text.dart';
import '../l10n/employee_web_text_keys.dart';

Future<void> showProjectDialog(BuildContext context, {required MyProject project}) => showJitanModal<void>(
  context,
  builder: (dialog) => _ProjectDialog(project: project),
);

/// A project's details (Figma `1501:310`): only what is known about it.
class _ProjectDialog extends StatelessWidget {
  const _ProjectDialog({required this.project});

  final MyProject project;

  String? _dates(BuildContext context) {
    final start = project.startDate, end = project.endDate;
    if (start == null) return null;
    final from = WebText.date(context, start);
    return end == null
        ? context.t(EmployeeWebTextKeys.projectDatesOpen, args: {'start': from})
        : '$from – ${WebText.date(context, end)}';
  }

  @override
  Widget build(BuildContext context) {
    final dates = _dates(context);
    return JitanModal(
      width: 480,
      title: project.name,
      subtitle: WebText.project(context, project),
      onClose: () => Navigator.of(context).pop(),
      body: WebList(
        color: JitanColors.tableHeader,
        radius: 14,
        rows: [
          if (project.reference case final reference?)
            WebLabelRow(label: context.t(EmployeeWebTextKeys.projectReference), value: reference),
          if (project.addressName case final address?)
            WebLabelRow(label: context.t(EmployeeWebTextKeys.projectAddress), value: address),
          if (dates != null) WebLabelRow(label: context.t(EmployeeWebTextKeys.projectDates), value: dates),
        ],
      ),
      actions: [
        JitanSecondaryButton(label: context.t(EmployeeWebTextKeys.close), onPressed: () => Navigator.of(context).pop()),
      ],
    );
  }
}
