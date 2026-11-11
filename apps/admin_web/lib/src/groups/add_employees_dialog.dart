import 'package:flutter/material.dart';
import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:jitan_core/jitan_core.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../common/api_failure_text.dart';
import '../l10n/admin_text_keys.dart';
import 'employee_picker.dart';
import 'group_hours_choice.dart';

/// Opens Add employees for [group]; completes with the group's members as
/// the server stored them, `null` when cancelled.
Future<List<GroupMember>?> showAddEmployeesDialog(
  BuildContext context, {
  required GroupMembersApi membersApi,
  required GroupOverview group,
  bool groupHasHours = false,
}) => showJitanModal<List<GroupMember>>(
  context,
  // A click beside the dialog must not throw away what HR entered.
  barrierDismissible: false,
  builder: (_) => AddEmployeesDialog(membersApi: membersApi, group: group, groupHasHours: groupHasHours),
);

/// Figma `HR / Groups V2 — add employees` (`1555:162`): employees from every
/// company, added in one save. When the group has work hours, a ticked
/// employee already in other groups chooses on their line whose hours they
/// work ("Hours: White collar ⌄").
class AddEmployeesDialog extends StatefulWidget {
  const AddEmployeesDialog({super.key, required this.membersApi, required this.group, this.groupHasHours = false});

  final GroupMembersApi membersApi;
  final GroupOverview group;

  /// Whether "Hours: {group}" can be offered.
  final bool groupHasHours;

  @override
  State<AddEmployeesDialog> createState() => _AddEmployeesDialogState();
}

class _AddEmployeesDialogState extends State<AddEmployeesDialog> {
  Map<int, GroupMember> _selected = const {};

  /// Employees in other groups who work this group's hours; the others keep theirs.
  Set<int> _follow = const {};
  bool _busy = false;
  ApiClientException? _failure;

  Future<void> _add() async {
    setState(() {
      _busy = true;
      _failure = null;
    });
    try {
      final members = await widget.membersApi.add(
        widget.group.id,
        _selected.keys.toList(),
        followIds: [for (final id in _follow) if (_selected.containsKey(id)) id],
      );
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
      width: 520,
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
            trailing: !widget.groupHasHours
                ? null
                : (employee) => employee.groups.isEmpty
                      ? null
                      : GroupHoursChoice(
                          employee: employee,
                          groupName: widget.group.name,
                          follows: _follow.contains(employee.id),
                          onChanged: _busy
                              ? null
                              : (follows) => setState(
                                  () => _follow = follows ? {..._follow, employee.id} : ({..._follow}..remove(employee.id)),
                                ),
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
        Wrap(
          alignment: WrapAlignment.end,
          spacing: 10,
          runSpacing: 10,
          children: [
            JitanSecondaryButton(label: context.t(CommonTextKeys.cancel), onPressed: _busy ? null : () => Navigator.of(context).pop()),
            JitanPrimaryButton(
              label: _selected.isEmpty
                  ? context.t(AdminTextKeys.groupsPickerAddNone)
                  : context.tPlural(AdminTextKeys.groupsPickerAdd, _selected.length),
              busy: _busy,
              onPressed: _selected.isEmpty || _busy ? null : _add,
            ),
          ],
        ),
      ],
    );
  }
}
