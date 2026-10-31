import 'package:flutter/material.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../l10n/admin_text_keys.dart';

/// What HR picked in "Manage project".
enum ProjectAction { view, edit, assign }

Future<ProjectAction?> showManageProjectDialog(BuildContext context, {required ProjectSummary project}) =>
    showJitanModal<ProjectAction>(context, builder: (_) => _ManageProjectDialog(project: project));

/// Figma `HR / Projects — Manage` (`1069:2`).
class _ManageProjectDialog extends StatelessWidget {
  const _ManageProjectDialog({required this.project});

  final ProjectSummary project;

  @override
  Widget build(BuildContext context) {
    const choices = [
      (ProjectAction.view, Icons.arrow_forward, AdminTextKeys.projectManageView, AdminTextKeys.projectManageViewText),
      (ProjectAction.edit, Icons.edit_outlined, AdminTextKeys.projectManageEdit, AdminTextKeys.projectManageEditText),
      (ProjectAction.assign, Icons.badge_outlined, AdminTextKeys.projectManageAssign, AdminTextKeys.projectManageAssignText),
    ];
    return JitanModal(
      width: 480,
      title: context.t(AdminTextKeys.projectManageTitle),
      subtitle: project.name,
      onClose: () => Navigator.of(context).pop(),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (action, icon, title, text) in choices)
            InkWell(
              onTap: () => Navigator.of(context).pop(action),
              borderRadius: BorderRadius.circular(12),
              hoverColor: JitanColors.warmWhite,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  spacing: 14,
                  children: [
                    Icon(icon, size: 18, color: JitanColors.ink),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(context.t(title), style: JitanTextStyles.tableCellStrong),
                          const SizedBox(height: 2),
                          Text(context.t(text), style: JitanTextStyles.stateMessage.copyWith(fontSize: 13)),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, size: 18, color: JitanColors.inkMuted),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
