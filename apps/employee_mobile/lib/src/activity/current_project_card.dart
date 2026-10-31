import 'package:flutter/material.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../l10n/employee_text_keys.dart';
import '../today/today_widgets.dart';
import 'activity_text.dart';

/// Home's "Current project" (Figma `1092:30`). Only what Jitan knows: without
/// a project it says so, and work goes on all the same.
class CurrentProjectCard extends StatelessWidget {
  const CurrentProjectCard({super.key, required this.activity, required this.onSwitch, required this.onProjects});

  final CurrentActivity? activity;
  final VoidCallback onSwitch;
  final VoidCallback onProjects;

  @override
  Widget build(BuildContext context) {
    final current = activity;
    final project = current?.project;
    return TodayCard(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: TodayEyebrow(context.t(EmployeeTextKeys.activityCurrent))),
              if (current != null && project != null)
                Text(ActivityText.kind(context, current.kind), style: JitanMobileTextStyles.cardText),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            project?.name ?? context.t(EmployeeTextKeys.activityNoProject),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: JitanMobileTextStyles.cardTitle.copyWith(fontSize: 18),
          ),
          if (project != null) ...[
            const SizedBox(height: 4),
            Text(ActivityText.project(context, project), style: JitanMobileTextStyles.cardText),
          ],
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: onSwitch,
            icon: const Icon(Icons.swap_horiz, size: 18, color: JitanColors.ink),
            label: Text(
              context.t(EmployeeTextKeys.activitySwitch),
              style: JitanMobileTextStyles.cardTitle.copyWith(fontSize: 15),
            ),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(46),
              side: const BorderSide(color: JitanColors.inputBorder),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
          const SizedBox(height: 4),
          TextButton(
            onPressed: onProjects,
            style: TextButton.styleFrom(foregroundColor: JitanColors.ink, padding: EdgeInsets.zero),
            child: Row(
              children: [
                Expanded(child: Text(context.t(EmployeeTextKeys.activityMyProjects), style: JitanMobileTextStyles.cardText)),
                const Icon(Icons.chevron_right, size: 18, color: JitanColors.inkMuted),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
