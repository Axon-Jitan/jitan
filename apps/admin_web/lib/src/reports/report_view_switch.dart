import 'package:flutter/material.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../l10n/admin_text_keys.dart';

/// Which report the Reports page shows.
enum ReportView { employees, projects }

/// "Employees | Projects" under the page title (Figma `1515:2`).
class ReportViewSwitch extends StatelessWidget {
  const ReportViewSwitch({super.key, required this.value, required this.onChanged});

  final ReportView value;
  final ValueChanged<ReportView> onChanged;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: JitanPillSwitch<ReportView>(
      options: [
        (ReportView.employees, context.t(AdminTextKeys.reportViewEmployees)),
        (ReportView.projects, context.t(AdminTextKeys.reportViewProjects)),
      ],
      value: value,
      onChanged: onChanged,
    ),
  );
}
