import 'dart:async';

import 'package:flutter/material.dart';
import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../l10n/admin_text_keys.dart';
import 'group_state_text.dart';

/// Search and tick employees to add to a group (Figma `HR / Employee groups
/// — Employee picker` 1349:356 and its loading, no-results and error
/// states). Each row shows the groups the employee is already in ("Also in:
/// White collar"), so HR sees who will have this as their only group.
class EmployeePicker extends StatefulWidget {
  const EmployeePicker({
    super.key,
    required this.load,
    required this.selected,
    required this.onChanged,
    this.enabled = true,
    this.noOtherGroupsKey = AdminTextKeys.groupsPickerAlsoInNone,
  });

  /// The employees matching a search (`null`: no search).
  final Future<List<GroupMember>> Function(String? search) load;
  final Set<int> selected;
  final ValueChanged<Set<int>> onChanged;
  final bool enabled;

  /// The text for an employee in no other group: "Also in: None" in Add
  /// employees (1349:356), "No other groups" in Create group (1354:7).
  final String noOtherGroupsKey;

  @override
  State<EmployeePicker> createState() => _EmployeePickerState();
}

class _EmployeePickerState extends State<EmployeePicker> {
  static const _searchDelay = Duration(milliseconds: 300);

  List<GroupMember>? _employees;
  ApiClientException? _failure;
  String? _search;
  Timer? _timer;
  int _latest = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final request = ++_latest;
    setState(() {
      _employees = null;
      _failure = null;
    });
    try {
      final employees = await widget.load(_search);
      if (mounted && request == _latest) setState(() => _employees = employees);
    } on ApiClientException catch (failure) {
      if (mounted && request == _latest) setState(() => _failure = failure);
    }
  }

  void _onSearch(String text) {
    _timer?.cancel();
    _timer = Timer(_searchDelay, () {
      _search = text.trim().isEmpty ? null : text.trim();
      _load();
    });
  }

  void _toggle(int id) {
    final next = {...widget.selected};
    next.contains(id) ? next.remove(id) : next.add(id);
    widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      JitanSearchField(outlined: true, hintText: context.t(AdminTextKeys.groupsPickerSearch), onChanged: _onSearch),
      const SizedBox(height: 12),
      SizedBox(height: 280, child: _list(context)),
    ],
  );

  Widget _list(BuildContext context) {
    if (_failure != null) return GroupStateText(context.t(AdminTextKeys.groupsPickerLoadFailed), onRetry: _load);
    final employees = _employees;
    if (employees == null) return GroupStateText(context.t(AdminTextKeys.groupsPickerLoading));
    if (employees.isEmpty) return GroupStateText(context.t(AdminTextKeys.groupsPickerEmptyMessage));
    return ListView.builder(
      itemCount: employees.length,
      itemBuilder: (context, index) {
        final employee = employees[index];
        final selected = widget.selected.contains(employee.id);
        final alsoIn = employee.groups.isEmpty
            ? context.t(widget.noOtherGroupsKey)
            : context.t(AdminTextKeys.groupsPickerAlsoIn, args: {'groups': employee.groups.join(', ')});
        return Material(
          color: index.isOdd ? JitanColors.tableStripe : JitanColors.surface,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: widget.enabled ? () => _toggle(employee.id) : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
              child: Row(
                children: [
                  Checkbox(
                    value: selected,
                    onChanged: widget.enabled ? (_) => _toggle(employee.id) : null,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${employee.displayName} · ${employee.code}',
                          style: JitanTextStyles.tableCellStrong,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          alsoIn,
                          style: JitanTextStyles.stateMessage.copyWith(fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
