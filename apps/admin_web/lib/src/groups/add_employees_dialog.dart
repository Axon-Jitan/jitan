import 'package:flutter/material.dart';
import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:jitan_core/jitan_core.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../common/api_failure_text.dart';
import '../l10n/admin_text_keys.dart';
import 'employee_picker.dart';

/// Opens Add employees for [group]; completes with the group's members as
/// the server stored them, `null` when cancelled.
Future<List<GroupMember>?> showAddEmployeesDialog(
  BuildContext context, {
  required GroupMembersApi membersApi,
  required GroupOverview group,
}) => showJitanModal<List<GroupMember>>(
  context,
  // A click beside the dialog must not throw away what HR entered.
  barrierDismissible: false,
  builder: (_) => AddEmployeesDialog(membersApi: membersApi, group: group),
);

/// Figma `HR / Employee groups — Employee picker` (1349:356): employees from
/// every company, added in one save.
class AddEmployeesDialog extends StatefulWidget {
  const AddEmployeesDialog({super.key, required this.membersApi, required this.group});

  final GroupMembersApi membersApi;
  final GroupOverview group;

  @override
  State<AddEmployeesDialog> createState() => _AddEmployeesDialogState();
}

class _AddEmployeesDialogState extends State<AddEmployeesDialog> {
  Map<int, GroupMember> _selected = const {};
  bool _busy = false;
  ApiClientException? _failure;

  Future<void> _add() async {
    setState(() {
      _busy = true;
      _failure = null;
    });
    try {
      final members = await widget.membersApi.add(widget.group.id, _selected.keys.toList());
      if (mounted) Navigator.of(context).pop(members);
    } on ApiClientException catch (failure) {
      if (mounted) setState(() => _failure = failure);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final failure = _failure;
    return JitanModal(
      width: 640,
      title: context.t(AdminTextKeys.groupsPickerTitle),
      subtitle: context.t(AdminTextKeys.groupsPickerSubtitle, args: {'group': widget.group.name}),
      onClose: _busy ? null : () => Navigator.of(context).pop(),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          EmployeePicker(
            enabled: !_busy,
            load: (search) => widget.membersApi.candidates(widget.group.id, search: search),
            selected: _selected,
            onChanged: (ids) => setState(() => _selected = ids),
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
        JitanSecondaryButton(label: context.t(CommonTextKeys.cancel), onPressed: _busy ? null : () => Navigator.of(context).pop()),
        JitanPrimaryButton(
          label: context.t(AdminTextKeys.groupsPickerAdd, args: {'count': _selected.length}),
          busy: _busy,
          onPressed: _selected.isEmpty ? null : _add,
        ),
      ],
    );
  }
}
