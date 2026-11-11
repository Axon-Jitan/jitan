import 'package:flutter/material.dart';
import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:jitan_core/jitan_core.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../../common/api_failure_text.dart';
import '../../l10n/admin_text_keys.dart';
import 'manage_assignments_controller.dart';

/// Asks HR/Admin to confirm removing [option] from [tab] and removes it.
/// Returns `true` once the server confirmed.
Future<bool> showRemoveAssignmentDialog(
  BuildContext context, {
  required ManageAssignmentsController controller,
  required AssignmentTab tab,
  required AssignmentOption option,
  required String name,
}) async =>
    await showJitanModal<bool>(
      context,
      builder: (_) => RemoveAssignmentDialog(controller: controller, tab: tab, option: option, name: name),
    ) ??
    false;

/// Taking an employee out of a company or group, asked first in one plain
/// sentence, like Deactivate (Figma `1534:366`). On the server it is a soft
/// delete (Active = 0, MFD = 1), audited; adding it again brings it back.
class RemoveAssignmentDialog extends StatefulWidget {
  const RemoveAssignmentDialog({super.key, required this.controller, required this.tab, required this.option, required this.name});

  final ManageAssignmentsController controller;
  final AssignmentTab tab;
  final AssignmentOption option;

  /// The employee's first name, for the question.
  final String name;

  @override
  State<RemoveAssignmentDialog> createState() => _RemoveAssignmentDialogState();
}

class _RemoveAssignmentDialogState extends State<RemoveAssignmentDialog> {
  bool _busy = false;
  ApiClientException? _failure;

  bool get _company => widget.tab.kind == AssignmentKind.companies;

  Future<void> _remove() async {
    setState(() {
      _busy = true;
      _failure = null;
    });
    final failure = await widget.controller.remove(widget.tab, widget.option);
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
    final args = {'name': widget.name, 'what': widget.option.name};
    return JitanModal(
      width: 440,
      title: context.t(AdminTextKeys.removeAssignmentTitle, args: args),
      subtitle: context.t(_company ? AdminTextKeys.removeCompanyText : AdminTextKeys.removeGroupText, args: args),
      body: failure == null
          ? null
          : JitanInlineError(
              title: context.t(failureTextKeysFor(failure).title),
              message: context.t(failureTextKeysFor(failure).message),
            ),
      actions: [
        Wrap(
          alignment: WrapAlignment.end,
          spacing: 12,
          runSpacing: 10,
          children: [
            JitanSecondaryButton(
              label: context.t(CommonTextKeys.cancel),
              onPressed: _busy ? null : () => Navigator.of(context).pop(false),
            ),
            JitanPrimaryButton(
              label: context.t(AdminTextKeys.removeAssignmentConfirm),
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
