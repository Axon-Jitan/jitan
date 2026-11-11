import 'package:flutter/material.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../l10n/admin_text_keys.dart';

/// Whose hours a ticked employee works when they join [groupName] (Figma
/// `1555:2`, `1555:162`, "Hours: White collar ⌄"): their own group's, or
/// [groupName]'s. Only for an employee already in other groups; the others
/// simply work [groupName]'s.
class GroupHoursChoice extends StatelessWidget {
  const GroupHoursChoice({
    super.key,
    required this.employee,
    required this.groupName,
    required this.follows,
    required this.onChanged,
  });

  final GroupMember employee;
  final String groupName;

  /// Whether the employee uses [groupName]'s hours.
  final bool follows;

  /// `null` disables the choice.
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final others = employee.groups;
    final keep = others.length == 1
        ? context.t(AdminTextKeys.groupsHoursFrom, args: {'group': others.single})
        : context.t(AdminTextKeys.groupsHoursFromOwn);
    return JitanInlineSelect<bool>(
      menuWidth: 220,
      value: follows,
      options: [
        JitanSelectOption(value: false, label: keep),
        JitanSelectOption(value: true, label: context.t(AdminTextKeys.groupsHoursFrom, args: {'group': groupName})),
      ],
      onChanged: onChanged == null ? null : (value) => onChanged!(value ?? false),
    );
  }
}
