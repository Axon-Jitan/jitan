import 'package:flutter/material.dart';
import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:jitan_core/jitan_core.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../common/api_failure_text.dart';
import '../l10n/admin_text_keys.dart';
import 'group_page_controller.dart';

/// Asks to remove [member] from [group] and does it; `true` once the server
/// confirmed. The link is switched off and kept (soft delete), audited.
Future<bool> showRemoveMemberDialog(
  BuildContext context, {
  required GroupPageController controller,
  required GroupOverview group,
  required GroupMember member,
}) async =>
    await showJitanModal<bool>(
      context,
      builder: (_) => RemoveMemberDialog(controller: controller, group: group, member: member),
    ) ??
    false;

/// Figma `HR / Groups V2 — remove employee?` (`1555:419`): one plain
/// question and a red Remove.
class RemoveMemberDialog extends StatefulWidget {
  const RemoveMemberDialog({super.key, required this.controller, required this.group, required this.member});

  final GroupPageController controller;
  final GroupOverview group;
  final GroupMember member;

  @override
  State<RemoveMemberDialog> createState() => _RemoveMemberDialogState();
}

class _RemoveMemberDialogState extends State<RemoveMemberDialog> {
  bool _busy = false;
  ApiClientException? _failure;

  Future<void> _remove() async {
    setState(() {
      _busy = true;
      _failure = null;
    });
    final failure = await widget.controller.remove(widget.member);
    if (!mounted) return;
    if (failure == null) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _busy = false;
        _failure = failure;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final failure = _failure;
    return JitanModal(
      width: 440,
      title: context.t(AdminTextKeys.groupRemoveTitle, args: {'name': widget.member.displayName, 'group': widget.group.name}),
      subtitle: context.t(AdminTextKeys.groupRemoveText),
      body: failure == null
          ? null
          : Builder(
              builder: (context) {
                final keys = failureTextKeysFor(failure);
                return JitanInlineError(title: context.t(keys.title), message: context.t(keys.message));
              },
            ),
      actions: [
        Wrap(
          alignment: WrapAlignment.end,
          spacing: 12,
          runSpacing: 10,
          children: [
            JitanSecondaryButton(label: context.t(CommonTextKeys.cancel), onPressed: _busy ? null : () => Navigator.of(context).pop(false)),
            JitanPrimaryButton(
              label: context.t(AdminTextKeys.groupRemoveConfirm),
              color: JitanColors.errorStrong,
              busy: _busy,
              onPressed: _busy ? null : _remove,
            ),
          ],
        ),
      ],
    );
  }
}
