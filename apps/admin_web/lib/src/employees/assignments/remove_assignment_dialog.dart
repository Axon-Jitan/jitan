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
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (_) => RemoveAssignmentDialog(controller: controller, tab: tab, option: option),
    ) ??
    false;

/// Figma "Remove Company confirmation" (`207:329`) and "Remove Group
/// confirmation" (`207:441`): removal is a soft delete (Active = false,
/// MFD = true), recorded in `tblEventLog`.
class RemoveAssignmentDialog extends StatefulWidget {
  const RemoveAssignmentDialog({super.key, required this.controller, required this.tab, required this.option});

  final ManageAssignmentsController controller;
  final AssignmentTab tab;
  final AssignmentOption option;

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
    return JitanModal(
      width: 620,
      title: context.t(_company ? AdminTextKeys.removeCompanyTitle : AdminTextKeys.removeGroupTitle),
      subtitle: context.t(AdminTextKeys.removeAssignmentSubtitle),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
            decoration: BoxDecoration(color: JitanColors.inputFill, borderRadius: BorderRadius.circular(14)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(context.t(AdminTextKeys.removeAssignmentWhatHappens), style: JitanTextStyles.stateTitle.copyWith(fontSize: 16)),
                const SizedBox(height: 14),
                Text(
                  context.t(_company ? AdminTextKeys.removeCompanySoftDelete : AdminTextKeys.removeGroupSoftDelete),
                  style: JitanTextStyles.stateMessage.copyWith(fontSize: 15),
                ),
                const SizedBox(height: 10),
                Text(context.t(AdminTextKeys.removeAssignmentAudit), style: JitanTextStyles.stateMessage.copyWith(fontSize: 15)),
              ],
            ),
          ),
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
        JitanSecondaryButton(
          label: context.t(CommonTextKeys.cancel),
          onPressed: _busy ? null : () => Navigator.of(context).pop(false),
        ),
        JitanPrimaryButton(label: context.t(AdminTextKeys.removeAssignmentConfirm), busy: _busy, onPressed: _busy ? null : _remove),
      ],
    );
  }
}
