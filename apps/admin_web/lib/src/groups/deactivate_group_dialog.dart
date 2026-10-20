import 'package:flutter/material.dart';
import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:jitan_core/jitan_core.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../common/api_failure_text.dart';
import '../l10n/admin_text_keys.dart';

/// Asks to deactivate [group], or says why it cannot be (it still has
/// employees). Completes with the deactivated group, `null` otherwise.
Future<GroupOverview?> showDeactivateGroupDialog(
  BuildContext context, {
  required GroupManagementApi groupsApi,
  required GroupOverview group,
}) => showJitanModal<GroupOverview>(context, builder: (_) => DeactivateGroupDialog(groupsApi: groupsApi, group: group));

/// Figma `HR / Employee groups — Deactivate group` (1340:667) and `Cannot
/// deactivate group` (1340:498). The server refuses too (group_in_use) when
/// someone joined in the meantime. Nothing is deleted: the group is switched
/// off and can be reactivated.
class DeactivateGroupDialog extends StatefulWidget {
  const DeactivateGroupDialog({super.key, required this.groupsApi, required this.group});

  final GroupManagementApi groupsApi;
  final GroupOverview group;

  @override
  State<DeactivateGroupDialog> createState() => _DeactivateGroupDialogState();
}

class _DeactivateGroupDialogState extends State<DeactivateGroupDialog> {
  bool _busy = false;
  ApiClientException? _failure;
  late int _employees = widget.group.employeeCount;

  Future<void> _deactivate() async {
    setState(() {
      _busy = true;
      _failure = null;
    });
    try {
      final done = await widget.groupsApi.deactivate(widget.group.id);
      if (mounted) Navigator.of(context).pop(done);
    } on ApiClientException catch (failure) {
      if (!mounted) return;
      setState(() {
        // Someone joined meanwhile: show why, not a general error.
        if (failure.error?.code == ApiErrorCode.groupInUse) {
          _employees = _employees == 0 ? 1 : _employees;
        } else {
          _failure = failure;
        }
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.group.name;
    if (_employees > 0) {
      return JitanModal(
        width: 560,
        title: context.t(AdminTextKeys.groupsCannotDeactivateTitle),
        onClose: () => Navigator.of(context).pop(),
        body: Text(
          context.t(AdminTextKeys.groupsCannotDeactivateText, args: {'count': _employees, 'group': name}),
          style: JitanTextStyles.stateMessage,
        ),
        actions: [
          JitanPrimaryButton(label: context.t(AdminTextKeys.groupsClose), onPressed: () => Navigator.of(context).pop()),
        ],
      );
    }
    final failure = _failure;
    return JitanModal(
      width: 560,
      title: context.t(AdminTextKeys.groupsDeactivateTitle),
      onClose: _busy ? null : () => Navigator.of(context).pop(),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(context.t(AdminTextKeys.groupsDeactivateText, args: {'group': name}), style: JitanTextStyles.stateMessage),
          if (failure != null) ...[
            const SizedBox(height: 16),
            Builder(
              builder: (context) {
                final keys = failureTextKeysFor(failure);
                return JitanInlineError(title: context.t(keys.title), message: context.t(keys.message));
              },
            ),
          ],
        ],
      ),
      actions: [
        JitanSecondaryButton(label: context.t(CommonTextKeys.cancel), onPressed: _busy ? null : () => Navigator.of(context).pop()),
        JitanPrimaryButton(label: context.t(AdminTextKeys.groupsDeactivateConfirm), busy: _busy, onPressed: _deactivate),
      ],
    );
  }
}
