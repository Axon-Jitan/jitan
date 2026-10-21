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
///
/// With [dropdown] (Create group step 2, 1352:2 and 1354:7) the list opens
/// under the "Select employees" field when HR clicks or types in it, and
/// stays open, so the dialog does not jump while HR picks.
class EmployeePicker extends StatefulWidget {
  const EmployeePicker({
    super.key,
    required this.load,
    required this.selected,
    required this.onChanged,
    this.enabled = true,
    this.dropdown = false,
    this.hintKey = AdminTextKeys.groupsPickerSearch,
    this.noOtherGroupsKey = AdminTextKeys.groupsPickerAlsoInNone,
  });

  /// The employees matching a search (`null`: no search).
  final Future<List<GroupMember>> Function(String? search) load;

  /// The ticked employees, by ID.
  final Map<int, GroupMember> selected;
  final ValueChanged<Map<int, GroupMember>> onChanged;
  final bool enabled;
  final bool dropdown;

  /// The search field's placeholder.
  final String hintKey;

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
  bool _open = false;

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

  void _toggle(GroupMember employee) {
    final next = {...widget.selected};
    next.containsKey(employee.id) ? next.remove(employee.id) : next[employee.id] = employee;
    widget.onChanged(next);
  }

  void _openList() {
    if (widget.dropdown && !_open) setState(() => _open = true);
  }

  @override
  Widget build(BuildContext context) {
    // On every press, not on focus: a field that kept focus still opens it.
    final field = Listener(
      onPointerDown: (_) => _openList(),
      child: JitanSearchField(
        outlined: true,
        hintText: context.t(widget.hintKey),
        onChanged: (text) {
          _openList();
          _onSearch(text);
        },
      ),
    );
    if (!widget.dropdown) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [field, const SizedBox(height: 12), SizedBox(height: 280, child: _list(context))],
      );
    }
    return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          field,
          if (_open) ...[
            const SizedBox(height: 6),
            Container(
              height: 214,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: JitanColors.surface,
                borderRadius: BorderRadius.circular(JitanDimensions.inputRadius),
                border: Border.all(color: JitanColors.inputBorder),
              ),
              child: _list(context),
            ),
          ],
        ],
    );
  }

  Widget _list(BuildContext context) {
    if (_failure != null) return GroupStateText(context.t(AdminTextKeys.groupsPickerLoadFailed), onRetry: _load);
    final employees = _employees;
    if (employees == null) return GroupStateText(context.t(AdminTextKeys.groupsPickerLoading));
    if (employees.isEmpty) return GroupStateText(context.t(AdminTextKeys.groupsPickerEmptyMessage));
    return ListView.builder(
      itemCount: employees.length,
      itemBuilder: (context, index) {
        final employee = employees[index];
        final selected = widget.selected.containsKey(employee.id);
        final alsoIn = employee.groups.isEmpty
            ? context.t(widget.noOtherGroupsKey)
            : context.t(AdminTextKeys.groupsPickerAlsoIn, args: {'groups': employee.groups.join(', ')});
        return Material(
          color: index.isOdd ? JitanColors.tableStripe : JitanColors.surface,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: widget.enabled ? () => _toggle(employee) : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
              child: Row(
                children: [
                  Checkbox(
                    value: selected,
                    onChanged: widget.enabled ? (_) => _toggle(employee) : null,
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
