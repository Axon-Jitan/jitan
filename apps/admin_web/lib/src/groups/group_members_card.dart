import 'package:flutter/material.dart';
import 'package:jitan_core/jitan_core.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../l10n/admin_text_keys.dart';
import 'group_member_hours.dart';

/// "Employees" on the group page (Figma `1455:2`): a count, a search, Add
/// employees, and one row per member with their companies, other groups,
/// where their work hours come from, and Remove. On a narrow window each
/// member becomes a small block instead of a table row.
class GroupMembersCard extends StatefulWidget {
  const GroupMembersCard({
    super.key,
    required this.groupId,
    required this.groupName,
    required this.members,
    required this.groupHasHours,
    required this.onAdd,
    required this.onRemove,
    required this.onChoose,
  });

  final int groupId;
  final String groupName;
  final List<GroupMember> members;
  final bool groupHasHours;

  /// `null` while the group is inactive.
  final VoidCallback? onAdd;
  final ValueChanged<GroupMember> onRemove;

  /// "Needs a choice": where this member's hours come from.
  final ValueChanged<GroupMember> onChoose;

  @override
  State<GroupMembersCard> createState() => _GroupMembersCardState();
}

class _GroupMembersCardState extends State<GroupMembersCard> {
  final _search = TextEditingController();
  String _term = '';

  /// Proportional to Figma (230 / 150 / 130 / 170 / 80).
  static const _flex = [230, 150, 130, 170, 80];

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<GroupMember> get _visible {
    final term = _term.trim().toLowerCase();
    if (term.isEmpty) return widget.members;
    return [
      for (final m in widget.members)
        if (m.displayName.toLowerCase().contains(term) || m.code.toLowerCase().contains(term)) m,
    ];
  }

  @override
  Widget build(BuildContext context) => JitanSurfaceCard(
    radius: JitanDimensions.tableCardRadius,
    child: LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 640;
        final visible = _visible;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(padding: const EdgeInsets.fromLTRB(24, 20, 24, 16), child: _header(context, wide)),
            if (widget.members.isEmpty)
              _empty(context)
            else ...[
              if (wide) _headingRow(context),
              if (visible.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(context.t(AdminTextKeys.groupDetailNoMatch), style: JitanTextStyles.stateMessage),
                ),
              for (final (i, member) in visible.indexed)
                ColoredBox(
                  color: i.isOdd ? JitanColors.tableStripe : JitanColors.surface,
                  child: wide ? _row(context, member) : _block(context, member),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 14, 24, 16),
                child: Text(context.tPlural(AdminTextKeys.groupDetailCount, widget.members.length), style: JitanTextStyles.stateMessage.copyWith(fontSize: 13)),
              ),
            ],
          ],
        );
      },
    ),
  );

  Widget _header(BuildContext context, bool wide) {
    final title = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(context.t(AdminTextKeys.groupDetailEmployees), style: JitanTextStyles.stateTitle.copyWith(fontSize: 18)),
        const SizedBox(width: 10),
        JitanBadge.neutral(label: '${widget.members.length}'),
      ],
    );
    final search = SizedBox(
      width: wide ? 220 : double.infinity,
      child: JitanSearchField(
        controller: _search,
        outlined: true,
        hintText: context.t(AdminTextKeys.groupDetailSearch),
        clearTooltip: context.t(CommonTextKeys.searchClear),
        onChanged: (text) => setState(() => _term = text),
      ),
    );
    final add = JitanOutlineButton(label: context.t(AdminTextKeys.groupDetailAddEmployees), onPressed: widget.onAdd);
    if (wide) {
      return Row(
        children: [
          Expanded(child: Align(alignment: Alignment.centerLeft, child: title)),
          if (widget.members.length > 1) ...[search, const SizedBox(width: 12)],
          add,
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(alignment: Alignment.centerLeft, child: title),
        const SizedBox(height: 14),
        Align(alignment: Alignment.centerLeft, child: add),
        if (widget.members.length > 1) ...[const SizedBox(height: 12), search],
      ],
    );
  }

  Widget _headingRow(BuildContext context) => Container(
    color: JitanColors.tableHeader,
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
    child: Row(
      children: [
        for (final (i, key) in [
          AdminTextKeys.groupDetailColumnEmployee,
          AdminTextKeys.groupDetailColumnCompanies,
          AdminTextKeys.groupDetailColumnOtherGroups,
          AdminTextKeys.groupDetailColumnHours,
        ].indexed)
          Expanded(flex: _flex[i], child: Text(context.t(key).toUpperCase(), style: JitanTextStyles.tableHeader.copyWith(fontSize: 11, letterSpacing: 0.4))),
        Expanded(flex: _flex[4], child: const SizedBox()),
      ],
    ),
  );

  List<String> _otherGroups(GroupMember member) => [for (final g in member.groups) if (g != widget.groupName) g];

  GroupMemberHours _hours(GroupMember member) =>
      GroupMemberHours.of(member, widget.groupId, groupHasHours: widget.groupHasHours);

  Widget _hoursBadge(GroupMember member) {
    final hours = _hours(member);
    final badge = GroupMemberHoursBadge(member: member, hours: hours);
    if (hours != GroupMemberHours.needsChoice) return badge;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(onTap: () => widget.onChoose(member), child: badge),
    );
  }

  Widget _name(GroupMember member) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(member.displayName.isEmpty ? member.code : member.displayName, style: JitanTextStyles.tableCellStrong, overflow: TextOverflow.ellipsis),
      const SizedBox(height: 2),
      Text(member.code, style: JitanTextStyles.stateMessage.copyWith(fontSize: 12)),
    ],
  );

  Widget _remove(BuildContext context, GroupMember member) => TextButton(
    onPressed: () => widget.onRemove(member),
    style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 6), minimumSize: const Size(0, 32)),
    child: Text(context.t(AdminTextKeys.groupDetailRemove), style: JitanTextStyles.tableCellStrong.copyWith(fontSize: 13, color: JitanColors.inkMuted)),
  );

  Widget _row(BuildContext context, GroupMember member) {
    final others = _otherGroups(member);
    return Container(
      constraints: const BoxConstraints(minHeight: 64),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      child: Row(
        children: [
          Expanded(flex: _flex[0], child: _name(member)),
          Expanded(
            flex: _flex[1],
            child: Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Text(member.companies.join(', '), maxLines: 1, style: JitanTextStyles.tableCell, overflow: TextOverflow.ellipsis),
            ),
          ),
          Expanded(
            flex: _flex[2],
            child: Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Text(
                others.isEmpty ? '—' : others.join(', '),
                maxLines: 1,
                style: JitanTextStyles.tableCell.copyWith(color: others.isEmpty ? JitanColors.inkMuted : null),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          Expanded(flex: _flex[3], child: Align(alignment: Alignment.centerLeft, child: _hoursBadge(member))),
          Expanded(flex: _flex[4], child: Align(alignment: Alignment.centerRight, child: _remove(context, member))),
        ],
      ),
    );
  }

  Widget _block(BuildContext context, GroupMember member) {
    final others = _otherGroups(member);
    final detail = [member.companies.join(', '), if (others.isNotEmpty) others.join(', ')].where((s) => s.isNotEmpty).join(' · ');
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 12, 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _name(member),
                if (detail.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(detail, style: JitanTextStyles.stateMessage.copyWith(fontSize: 12)),
                ],
                const SizedBox(height: 8),
                _hoursBadge(member),
              ],
            ),
          ),
          _remove(context, member),
        ],
      ),
    );
  }

  Widget _empty(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(context.t(AdminTextKeys.groupDetailEmployeesNone), style: JitanTextStyles.stateTitle),
        const SizedBox(height: 6),
        Text(context.t(AdminTextKeys.groupDetailEmployeesNoneText), style: JitanTextStyles.stateMessage),
      ],
    ),
  );
}
