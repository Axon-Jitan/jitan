import 'package:flutter/material.dart';
import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:jitan_core/jitan_core.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../common/api_failure_text.dart';
import '../l10n/admin_text_keys.dart';
import '../schedules/schedule_form_fields.dart';
import 'employee_picker.dart';
import 'group_name_error.dart';

/// Opens Create group; completes with the new group once the server created
/// it (with or without employees), `null` when cancelled before that.
Future<GroupOverview?> showCreateGroupDialog(
  BuildContext context, {
  required GroupManagementApi groupsApi,
  required GroupMembersApi membersApi,
}) => showJitanModal<GroupOverview>(
  context,
  builder: (_) => CreateGroupDialog(groupsApi: groupsApi, membersApi: membersApi),
);

/// Figma `HR / Employee groups — Create group — Step 1 Details` (1340:160)
/// and `Step 2 Employees` (1352:2). Step 1 creates the group; step 2 adds
/// employees from every company, or is skipped. The work hours and break
/// (Figma step 3) are set on the group's page, with the schedule wizard, so
/// there is one schedule form and every schedule has a break (2026-10-20).
class CreateGroupDialog extends StatefulWidget {
  const CreateGroupDialog({super.key, required this.groupsApi, required this.membersApi});

  final GroupManagementApi groupsApi;
  final GroupMembersApi membersApi;

  @override
  State<CreateGroupDialog> createState() => _CreateGroupDialogState();
}

class _CreateGroupDialogState extends State<CreateGroupDialog> {
  final _name = TextEditingController();
  GroupOverview? _created;
  Set<int> _selected = {};
  bool _busy = false;
  String? _nameError;
  ApiClientException? _failure;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final problem = groupNameProblem(_name.text);
    if (problem != null) return setState(() => _nameError = problem);
    setState(() {
      _busy = true;
      _nameError = null;
      _failure = null;
    });
    try {
      final created = await widget.groupsApi.create(_name.text.trim());
      if (mounted) setState(() => _created = created);
    } on ApiClientException catch (failure) {
      if (mounted) {
        setState(() {
          final nameKey = groupNameErrorKey(failure);
          if (nameKey != null) {
            _nameError = nameKey;
          } else {
            _failure = failure;
          }
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _addEmployees() async {
    final created = _created!;
    setState(() {
      _busy = true;
      _failure = null;
    });
    try {
      await widget.membersApi.add(created.id, _selected.toList());
      if (mounted) Navigator.of(context).pop(created);
    } on ApiClientException catch (failure) {
      if (mounted) setState(() => _failure = failure);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final created = _created;
    final step = created == null ? 0 : 1;
    return JitanModal(
      width: 640,
      title: context.t(AdminTextKeys.groupsCreateTitle),
      subtitle: context.t(AdminTextKeys.groupsCreateSubtitle),
      onClose: _busy ? null : () => Navigator.of(context).pop(created),
      bandFooter: true,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ScheduleStepper(
            current: step,
            labels: [
              context.t(AdminTextKeys.scheduleStepLabel, args: {'n': 1, 'label': context.t(AdminTextKeys.groupsStepDetails)}),
              context.t(AdminTextKeys.scheduleStepLabel, args: {'n': 2, 'label': context.t(AdminTextKeys.groupsStepEmployees)}),
            ],
          ),
          const SizedBox(height: 28),
          if (created == null) ..._details(context) else ..._employees(context, created),
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
      leadingActions: [
        JitanSecondaryButton(
          label: context.t(created == null ? CommonTextKeys.cancel : AdminTextKeys.groupsSkipForNow),
          onPressed: _busy ? null : () => Navigator.of(context).pop(created),
        ),
      ],
      actions: [
        if (created == null)
          JitanPrimaryButton(label: context.t(AdminTextKeys.groupsCreateSubmit), busy: _busy, onPressed: _create)
        else
          JitanPrimaryButton(
            label: context.t(AdminTextKeys.groupsPickerAdd, args: {'count': _selected.length}),
            busy: _busy,
            onPressed: _selected.isEmpty ? null : _addEmployees,
          ),
      ],
    );
  }

  List<Widget> _details(BuildContext context) => [
    JitanFieldLabel(
      label: context.t(AdminTextKeys.groupsFieldName),
      child: TextField(
        controller: _name,
        autofocus: true,
        enabled: !_busy,
        maxLength: GroupNameRequest.maxNameLength,
        style: JitanTextStyles.inputText,
        onSubmitted: (_) => _create(),
        decoration: jitanFieldDecoration(
          hintText: context.t(AdminTextKeys.groupsFieldNameHint),
          errorText: _nameError == null ? null : context.t(_nameError!),
        ).copyWith(counterText: ''),
      ),
    ),
    const SizedBox(height: 10),
    Text(context.t(AdminTextKeys.groupsFieldNameHelp), style: JitanTextStyles.stateMessage.copyWith(fontSize: 13)),
  ];

  List<Widget> _employees(BuildContext context, GroupOverview created) => [
    EmployeePicker(
      enabled: !_busy,
      noOtherGroupsKey: AdminTextKeys.groupsPickerNoOtherGroups,
      load: (search) => widget.membersApi.candidates(created.id, search: search),
      selected: _selected,
      onChanged: (ids) => setState(() => _selected = ids),
    ),
    const SizedBox(height: 10),
    Text(
      '${context.t(AdminTextKeys.groupsEmployeesSelected, args: {'count': _selected.length})} · '
      '${context.t(AdminTextKeys.groupsEmployeesLater)}',
      style: JitanTextStyles.stateMessage.copyWith(fontSize: 13),
    ),
  ];
}
