import 'dart:async';

import 'package:flutter/material.dart';
import 'package:jitan_core/jitan_core.dart';
import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../l10n/admin_text_keys.dart';
import 'group_state_text.dart';

/// Search and tick employees to add to a group (Figma `HR / Groups V2`:
/// Create group `1555:2`, Add employees `1555:162`): one calm card, a line
/// per employee with a check, their name and code, and the groups they are
/// already in ("Also in White collar"), so HR sees who will have this as
/// their only group. A ticked employee can carry a small choice on the
/// right ([trailing], e.g. whose hours they work).
class EmployeePicker extends StatefulWidget {
  const EmployeePicker({
    super.key,
    required this.load,
    required this.selected,
    required this.onChanged,
    this.enabled = true,
    this.trailing,
  });

  /// The employees matching a search (`null`: no search).
  final Future<List<GroupMember>> Function(String? search) load;

  /// The ticked employees, by ID.
  final Map<int, GroupMember> selected;
  final ValueChanged<Map<int, GroupMember>> onChanged;
  final bool enabled;

  /// Shown on the right of a ticked employee's line; `null` adds nothing.
  final Widget? Function(GroupMember employee)? trailing;

  @override
  State<EmployeePicker> createState() => _EmployeePickerState();
}

class _EmployeePickerState extends State<EmployeePicker> {
  static const _searchDelay = Duration(milliseconds: 300);

  /// The list area's one height; a long list scrolls inside the card.
  static const _maxListHeight = 280.0;

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

  void _toggle(GroupMember employee) {
    final next = {...widget.selected};
    next.containsKey(employee.id) ? next.remove(employee.id) : next[employee.id] = employee;
    widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    spacing: 12,
    children: [
      JitanSearchField(
        clearTooltip: context.t(CommonTextKeys.searchClear),
        outlined: true,
        hintText: context.t(AdminTextKeys.groupsPickerSearch),
        onChanged: _onSearch,
      ),
      _list(context),
    ],
  );

  Widget _list(BuildContext context) {
    final employees = _employees;
    final Widget? state = _failure != null
        ? GroupStateText(context.t(AdminTextKeys.groupsPickerLoadFailed), onRetry: _load)
        : employees == null
        ? GroupStateText(context.t(AdminTextKeys.groupsPickerLoading))
        : employees.isEmpty
        ? GroupStateText(context.t(AdminTextKeys.groupsPickerEmptyMessage))
        : null;
    // One height whether loading, empty or full, so the pop-up never jumps.
    if (state != null) return SizedBox(height: _maxListHeight, child: Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: state));
    return Container(
      height: _maxListHeight,
      decoration: BoxDecoration(
        color: JitanColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: JitanColors.cardBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: ListView.separated(
        shrinkWrap: true,
        itemCount: employees!.length,
        separatorBuilder: (_, _) => const Divider(height: 1, thickness: 1, color: JitanColors.cardBorder),
        itemBuilder: (context, index) => _row(context, employees[index]),
      ),
    );
  }

  Widget _row(BuildContext context, GroupMember employee) {
    final selected = widget.selected.containsKey(employee.id);
    final trailing = selected ? widget.trailing?.call(employee) : null;
    return InkWell(
      onTap: widget.enabled ? () => _toggle(employee) : null,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
        child: Row(
          spacing: 12,
          children: [
            _Check(selected: selected, label: employee.displayName),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.t(AdminTextKeys.groupsPickerName, args: {'name': employee.displayName, 'code': employee.code}),
                    style: JitanTextStyles.tableCell.copyWith(color: JitanColors.ink, fontWeight: FontWeight.w500),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (employee.groups.isNotEmpty)
                    Text(
                      context.t(AdminTextKeys.groupsPickerAlsoIn, args: {'groups': employee.groups.join(', ')}),
                      style: JitanTextStyles.stateMessage.copyWith(fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            ?trailing,
          ],
        ),
      ),
    );
  }
}

/// A small square check: ink with a white tick when chosen.
class _Check extends StatelessWidget {
  const _Check({required this.selected, required this.label});

  final bool selected;
  final String label;

  @override
  Widget build(BuildContext context) => Semantics(
    checked: selected,
    label: label,
    child: Container(
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        color: selected ? JitanColors.ink : JitanColors.surface,
        borderRadius: BorderRadius.circular(5),
        border: selected ? null : Border.all(color: JitanColors.inputBorder, width: 1.5),
      ),
      child: selected ? const Icon(Icons.check_rounded, size: 13, color: JitanColors.surface) : null,
    ),
  );
}
