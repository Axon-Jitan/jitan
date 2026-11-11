import 'package:flutter/widgets.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../l10n/admin_text_keys.dart';

/// Where a member's work hours come from, as the group page shows it
/// (Figma `1554:101`, "Work hours" column). The server tells the group
/// ([GroupMember.hoursFromGroupId]); this only names the case.
enum GroupMemberHours {
  /// This group's hours.
  thisGroup,

  /// Another of the employee's groups ("White collar").
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

/// A member's [GroupMemberHours] as plain text: "This group" in ink, the
/// other group muted, "Needs a choice" in amber (Figma `1556:761`).
class GroupMemberHoursText extends StatelessWidget {
  const GroupMemberHoursText({super.key, required this.member, required this.hours});

  final GroupMember member;
  final GroupMemberHours hours;

  @override
  Widget build(BuildContext context) {
    final (text, color) = switch (hours) {
      GroupMemberHours.thisGroup => (context.t(AdminTextKeys.groupDetailHoursThisGroup), JitanColors.ink),
      GroupMemberHours.otherGroup => (member.hoursFromGroup ?? '', JitanColors.inkMuted),
      GroupMemberHours.needsChoice => (context.t(AdminTextKeys.groupDetailHoursNeedsChoice), JitanColors.warning),
      GroupMemberHours.none => (context.t(AdminTextKeys.groupDetailHoursNone), JitanColors.inkMuted),
    };
    return Text(text, overflow: TextOverflow.ellipsis, style: JitanTextStyles.tableCell.copyWith(color: color));
  }
}
