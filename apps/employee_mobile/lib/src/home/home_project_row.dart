import 'package:flutter/material.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../activity/activity_text.dart';
import '../l10n/employee_text_keys.dart';

/// Home's project (Figma `1585:2`): what they're on, and a small "Switch".
/// Only what Jitan knows: without a project it says so, and work goes on.
class HomeProjectRow extends StatelessWidget {
  const HomeProjectRow({super.key, required this.activity, required this.onSwitch});

  final CurrentActivity? activity;
  final VoidCallback onSwitch;

  @override
  Widget build(BuildContext context) {
    final current = activity;
    final project = current?.project;
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 12, 12, 12),
      decoration: BoxDecoration(color: JitanColors.surface, borderRadius: BorderRadius.circular(18)),
      child: Row(
        spacing: 12,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 2,
              children: [
                Text(
                  project?.name ?? context.t(EmployeeTextKeys.activityNoProject),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: project == null
                      ? JitanMobileTextStyles.rowText.copyWith(color: JitanColors.inkMuted)
                      : JitanMobileTextStyles.rowTitle,
                ),
                if (current != null && project != null) Text(ActivityText.kind(context, current.kind), style: JitanMobileTextStyles.detail),
              ],
            ),
          ),
          FilledButton(
            onPressed: onSwitch,
            style: FilledButton.styleFrom(
              backgroundColor: JitanColors.inputFill,
              foregroundColor: JitanColors.ink,
              minimumSize: const Size(0, 44),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            child: Text(context.t(EmployeeTextKeys.activitySwitchShort), style: JitanMobileTextStyles.rowTitle.copyWith(fontSize: 14)),
          ),
        ],
      ),
    );
  }
}
