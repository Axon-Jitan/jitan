import 'package:flutter/widgets.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../l10n/admin_text_keys.dart';

/// Where a member's work hours come from, as the group page shows it
/// (Figma `1455:2`, "Work hours" column). The server tells the group
/// ([GroupMember.hoursFromGroupId]); this only names the case.
enum GroupMemberHours {
  /// This group's hours.
  thisGroup,

  /// Another of the employee's groups ("Keeps Blue collar").
  otherGroup,

  /// No hours, in several groups, while this group has hours: HR chooses.
  needsChoice,

  /// No hours, and nothing to choose here.
  none;

  static GroupMemberHours of(GroupMember member, int groupId, {required bool groupHasHours}) => switch (member.hoursFromGroupId) {
    final id? when id == groupId => thisGroup,
    _? => otherGroup,
    null when groupHasHours && member.groups.length > 1 => needsChoice,
    null => none,
  };
}

/// The badge of a member's [GroupMemberHours].
class GroupMemberHoursBadge extends StatelessWidget {
  const GroupMemberHoursBadge({super.key, required this.member, required this.hours});

  final GroupMember member;
  final GroupMemberHours hours;

  @override
  Widget build(BuildContext context) => switch (hours) {
    GroupMemberHours.thisGroup => JitanBadge(label: context.t(AdminTextKeys.groupDetailHoursThisGroup)),
    GroupMemberHours.otherGroup => JitanBadge.neutral(
      label: context.t(AdminTextKeys.groupDetailHoursKeeps, args: {'group': member.hoursFromGroup ?? ''}),
      dot: true,
    ),
    GroupMemberHours.needsChoice => JitanBadge.warning(label: context.t(AdminTextKeys.groupDetailHoursNeedsChoice)),
    GroupMemberHours.none => JitanBadge.neutral(label: context.t(AdminTextKeys.groupDetailHoursNone), dot: true),
  };
}
