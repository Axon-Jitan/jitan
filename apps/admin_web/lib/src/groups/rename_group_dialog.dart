import 'package:flutter/material.dart';
import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:jitan_core/jitan_core.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../common/api_failure_text.dart';
import '../l10n/admin_text_keys.dart';
import 'group_name_error.dart';

/// Opens Rename group; completes with the renamed group, `null` when closed.
Future<GroupOverview?> showRenameGroupDialog(
  BuildContext context, {
  required GroupManagementApi groupsApi,
  required GroupOverview group,
}) => showJitanModal<GroupOverview>(context, builder: (_) => RenameGroupDialog(groupsApi: groupsApi, group: group));

/// Figma `HR / Employee groups — Rename group` (1340:329) and `Group name
/// error` (1340:836).
class RenameGroupDialog extends StatefulWidget {
  const RenameGroupDialog({super.key, required this.groupsApi, required this.group});

  final GroupManagementApi groupsApi;
  final GroupOverview group;

  @override
  State<RenameGroupDialog> createState() => _RenameGroupDialogState();
}

class _RenameGroupDialogState extends State<RenameGroupDialog> {
  late final _name = TextEditingController(text: widget.group.name);
  bool _busy = false;
  String? _nameError;
  ApiClientException? _failure;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final problem = groupNameProblem(_name.text);
    if (problem != null) return setState(() => _nameError = problem);
    setState(() {
      _busy = true;
      _nameError = null;
      _failure = null;
    });
    try {
      final renamed = await widget.groupsApi.rename(widget.group.id, _name.text.trim());
      if (mounted) Navigator.of(context).pop(renamed);
    } on ApiClientException catch (failure) {
      if (!mounted) return;
      setState(() {
        final nameKey = groupNameErrorKey(failure);
        if (nameKey != null) {
          _nameError = nameKey;
        } else {
          _failure = failure;
        }
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => JitanModal(
    width: 560,
    title: context.t(AdminTextKeys.groupsRenameTitle),
    onClose: _busy ? null : () => Navigator.of(context).pop(),
    body: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        JitanFieldLabel(
          label: context.t(AdminTextKeys.groupsFieldName),
          info: context.t(AdminTextKeys.groupsInfoName),
          child: TextField(
            controller: _name,
            autofocus: true,
            enabled: !_busy,
            maxLength: GroupNameRequest.maxNameLength,
            style: JitanTextStyles.inputText,
            onSubmitted: (_) => _save(),
            decoration: jitanFieldDecoration(errorText: _nameError == null ? null : context.t(_nameError!))
                .copyWith(counterText: ''),
          ),
        ),
        const SizedBox(height: 10),
        Text(context.t(AdminTextKeys.groupsFieldNameHelp), style: JitanTextStyles.stateMessage.copyWith(fontSize: 13)),
        if (_failure case final failure?) ...[
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
      JitanPrimaryButton(label: context.t(AdminTextKeys.groupsRenameSave), busy: _busy, onPressed: _save),
    ],
  );
}
