import 'package:flutter/material.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../l10n/admin_text_keys.dart';

/// Whose hours an employee works when they join [groupName] (Figma
/// `1405:473`, `1390:1106`): an employee already in other groups chooses
/// "Keep {their group} hours" or "Use {groupName} hours"; one in no other
/// group simply "Uses {groupName} hours".
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
    if (others.isEmpty) {
      return Text(
        context.t(AdminTextKeys.groupsHoursUses, args: {'group': groupName}),
        style: JitanTextStyles.tableCell.copyWith(fontSize: 12),
      );
    }
    final keep = others.length == 1
        ? context.t(AdminTextKeys.groupsHoursKeep, args: {'group': others.single})
        : context.t(AdminTextKeys.groupsHoursKeepCurrent);
    return Wrap(
      spacing: 16,
      runSpacing: 4,
      children: [
        _Option(label: keep, chosen: !follows, onTap: onChanged == null ? null : () => onChanged!(false)),
        _Option(
          label: context.t(AdminTextKeys.groupsHoursUse, args: {'group': groupName}),
          chosen: follows,
          onTap: onChanged == null ? null : () => onChanged!(true),
        ),
      ],
    );
  }
}

/// A small radio: a ring, filled when chosen.
class _Option extends StatelessWidget {
  const _Option({required this.label, required this.chosen, required this.onTap});

  final String label;
  final bool chosen;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    inMutuallyExclusiveGroup: true,
    checked: chosen,
    button: true,
    label: label,
    excludeSemantics: true,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 12,
              height: 12,
              alignment: Alignment.center,
              decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: JitanColors.ink, width: 1.2)),
              child: chosen
                  ? Container(width: 6, height: 6, decoration: const BoxDecoration(shape: BoxShape.circle, color: JitanColors.ink))
                  : null,
            ),
            const SizedBox(width: 6),
            Flexible(child: Text(label, style: JitanTextStyles.tableCell.copyWith(fontSize: 12))),
          ],
        ),
      ),
    ),
  );
}
