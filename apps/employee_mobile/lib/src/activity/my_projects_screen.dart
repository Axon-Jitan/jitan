import 'package:flutter/material.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../l10n/employee_text_keys.dart';
import '../today/today_widgets.dart';

/// My projects (Figma `647:2552`, none `647:2662`): current and earlier. The
/// sample numbers of the Figma detail frames aren't calculated, so the list
/// stands on its own.
class MyProjectsScreen extends StatelessWidget {
  const MyProjectsScreen({super.key, required this.projects});

  final List<MyProject> projects;

  Widget _section(BuildContext context, String title, List<MyProject> rows, String status) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      TodayEyebrow(title),
      const SizedBox(height: 8),
      TodayCard(
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            for (final (i, project) in rows.indexed) ...[
              if (i > 0) const Divider(height: 1, color: JitanColors.inputBorder),
              Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(project.name, style: JitanMobileTextStyles.cardTitle),
                      const SizedBox(height: 4),
                      Text('${project.companyName} · $status', style: JitanMobileTextStyles.cardText),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      const SizedBox(height: 22),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final current = projects.where((p) => p.isCurrent).toList();
    final earlier = projects.where((p) => !p.isCurrent).toList();
    return Scaffold(
      backgroundColor: JitanColors.warmWhite,
      appBar: AppBar(backgroundColor: JitanColors.warmWhite, elevation: 0, scrolledUnderElevation: 0),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                header: true,
                child: Text(context.t(EmployeeTextKeys.activityMyProjects), style: JitanMobileTextStyles.title),
              ),
              const SizedBox(height: 6),
              Text(context.t(EmployeeTextKeys.activityMyProjectsText), style: JitanMobileTextStyles.body),
              const SizedBox(height: 28),
              if (projects.isEmpty) Text(context.t(EmployeeTextKeys.activityNoProjects), style: JitanMobileTextStyles.body),
              if (current.isNotEmpty)
                _section(
                  context,
                  context.t(EmployeeTextKeys.activityCurrentProjects),
                  current,
                  context.t(EmployeeTextKeys.activityAssigned),
                ),
              if (earlier.isNotEmpty)
                _section(
                  context,
                  context.t(EmployeeTextKeys.activityEarlierProjects),
                  earlier,
                  context.t(EmployeeTextKeys.activityPreviouslyAssigned),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
