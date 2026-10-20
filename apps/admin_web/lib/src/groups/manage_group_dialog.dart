import 'package:flutter/material.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../l10n/admin_text_keys.dart';

/// What HR picked in "Manage group".
enum GroupAction { open, rename, deactivate, reactivate }

Future<GroupAction?> showManageGroupDialog(BuildContext context, {required GroupOverview group}) =>
    showJitanModal<GroupAction>(context, builder: (_) => ManageGroupDialog(group: group));

/// The row's "⋯" (table design specification §7): open, rename, and
/// deactivate or reactivate; it never acts on its own.
class ManageGroupDialog extends StatelessWidget {
  const ManageGroupDialog({super.key, required this.group});

  final GroupOverview group;

  @override
  Widget build(BuildContext context) {
    final choices = [
      (GroupAction.open, AdminTextKeys.groupsManageOpen, AdminTextKeys.groupsManageOpenText, false),
      (GroupAction.rename, AdminTextKeys.groupsManageRename, AdminTextKeys.groupsManageRenameText, false),
      if (group.isActive)
        (GroupAction.deactivate, AdminTextKeys.groupsManageDeactivate, AdminTextKeys.groupsManageDeactivateText, true)
      else
        (GroupAction.reactivate, AdminTextKeys.groupsManageReactivate, AdminTextKeys.groupsManageReactivateText, false),
    ];
    return JitanModal(
      width: 480,
      title: context.t(AdminTextKeys.groupsManageTitle),
      subtitle: group.name,
      onClose: () => Navigator.of(context).pop(),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (index, (action, title, text, destructive)) in choices.indexed) ...[
            if (index > 0) const Divider(height: 1, color: JitanColors.inputBorder),
            InkWell(
              onTap: () => Navigator.of(context).pop(action),
              borderRadius: BorderRadius.circular(12),
              hoverColor: JitanColors.warmWhite,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.t(title),
                            style: JitanTextStyles.stateTitle.copyWith(color: destructive ? JitanColors.vermilion : JitanColors.ink),
                          ),
                          const SizedBox(height: 4),
                          Text(context.t(text), style: JitanTextStyles.stateMessage.copyWith(fontSize: 13)),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: JitanColors.inkMuted),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
