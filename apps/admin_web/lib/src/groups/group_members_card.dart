import 'package:flutter/material.dart';
import 'package:jitan_core/jitan_core.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../l10n/admin_text_keys.dart';
import 'group_member_hours.dart';

/// "Employees" on the group page (Figma `HR / Groups V2 — a group`
/// `1554:101`): a count, a search, Add employees, and one calm row per
/// member with their companies, other groups and where their work hours
/// come from; Remove shows while a row is hovered. On a narrow window each
/// member becomes a small block, with Remove always there.
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

  /// `null` while the group is inactive: no Add employees and no Remove.
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

  /// Proportional to Figma (230 / 120 / 120 / 150 / 70).
  static const _flex = [230, 120, 120, 150, 70];

  bool get _active => widget.onAdd != null;

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
            Padding(padding: const EdgeInsets.fromLTRB(20, 18, 20, 16), child: _header(context, wide)),
            if (widget.members.isEmpty)
              _empty(context)
            else ...[
              if (wide) _headingRow(context),
              if (visible.isEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                  child: Text(context.t(AdminTextKeys.groupDetailNoMatch), style: JitanTextStyles.stateMessage),
                ),
              for (final member in visible)
                _MemberRow(
                  wide: wide,
                  onRemove: _active ? () => widget.onRemove(member) : null,
                  removeLabel: context.t(AdminTextKeys.groupDetailRemove),
                  cells: _cells(context, member, wide),
                ),
              const SizedBox(height: 6),
            ],
          ],
        );
      },
    ),
  );

  Widget _header(BuildContext context, bool wide) {
    final title = Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(context.t(AdminTextKeys.groupDetailEmployees), style: JitanTextStyles.stateTitle.copyWith(fontSize: 18)),
        const SizedBox(width: 10),
        Text('${widget.members.length}', style: JitanTextStyles.stateMessage),
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
    final add = _active
        ? JitanSecondaryButton(label: context.t(AdminTextKeys.groupDetailAddEmployees), onPressed: widget.onAdd)
        : null;
    final searchable = widget.members.length > 1;
    if (wide) {
      return Row(
        children: [
          Expanded(child: Align(alignment: Alignment.centerLeft, child: title)),
          if (searchable) search,
          if (searchable && add != null) const SizedBox(width: 10),
          ?add,
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 12,
      children: [
        Align(alignment: Alignment.centerLeft, child: title),
        if (add != null) Align(alignment: Alignment.centerLeft, child: add),
        if (searchable) search,
      ],
    );
  }

  Widget _headingRow(BuildContext context) => Container(
    color: JitanColors.tableHeader,
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
    child: Row(
      children: [
        for (final (i, key) in [
          AdminTextKeys.groupDetailColumnEmployee,
          AdminTextKeys.groupDetailColumnCompanies,
          AdminTextKeys.groupDetailColumnOtherGroups,
          AdminTextKeys.groupDetailColumnHours,
        ].indexed)
          Expanded(flex: _flex[i], child: Text(context.t(key), style: JitanTextStyles.tableHeader)),
        Expanded(flex: _flex[4], child: const SizedBox()),
      ],
    ),
  );

  List<String> _otherGroups(GroupMember member) => [for (final g in member.groups) if (g != widget.groupName) g];

  Widget _hours(GroupMember member) {
    final hours = GroupMemberHours.of(member, widget.groupId, groupHasHours: widget.groupHasHours);
    final text = GroupMemberHoursText(member: member, hours: hours);
    if (hours != GroupMemberHours.needsChoice || !_active) return text;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(onTap: () => widget.onChoose(member), child: text),
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

  /// The row's cells (wide), or its block (narrow), without Remove.
  List<Widget> _cells(BuildContext context, GroupMember member, bool wide) {
    final others = _otherGroups(member);
    if (!wide) {
      final detail = [member.companies.join(', '), if (others.isNotEmpty) others.join(', ')].where((s) => s.isNotEmpty).join(' · ');
      return [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _name(member),
            if (detail.isNotEmpty) ...[const SizedBox(height: 4), Text(detail, style: JitanTextStyles.stateMessage.copyWith(fontSize: 12))],
            const SizedBox(height: 6),
            _hours(member),
          ],
        ),
      ];
    }
    Widget text(String value, {bool muted = false}) => Padding(
      padding: const EdgeInsets.only(right: 12),
      child: Text(
        value,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: JitanTextStyles.tableCell.copyWith(color: muted ? JitanColors.inkMuted : null),
      ),
    );
    return [
      Expanded(flex: _flex[0], child: _name(member)),
      Expanded(flex: _flex[1], child: text(member.companies.join(', '))),
      Expanded(flex: _flex[2], child: text(others.isEmpty ? '—' : others.join(', '), muted: others.isEmpty)),
      Expanded(flex: _flex[3], child: Align(alignment: Alignment.centerLeft, child: _hours(member))),
    ];
  }

  Widget _empty(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
    child: Text(
      context.t(_active ? AdminTextKeys.groupDetailEmployeesNoneText : AdminTextKeys.groupDetailEmployeesNone),
      style: JitanTextStyles.stateMessage.copyWith(fontSize: 14),
    ),
  );
}

/// One member: a soft shade and Remove while hovered (wide), or a block
/// with Remove always there (narrow, where there is no hover).
class _MemberRow extends StatefulWidget {
  const _MemberRow({required this.wide, required this.onRemove, required this.removeLabel, required this.cells});

  final bool wide;
  final VoidCallback? onRemove;
  final String removeLabel;
  final List<Widget> cells;

  @override
  State<_MemberRow> createState() => _MemberRowState();
}

class _MemberRowState extends State<_MemberRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final remove = widget.onRemove;
    final showRemove = remove != null && (!widget.wide || _hovered);
    final link = TextButton(
      onPressed: remove,
      style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 6), minimumSize: const Size(0, 32)),
      child: Text(widget.removeLabel, style: JitanTextStyles.tableCellStrong.copyWith(fontSize: 13, color: JitanColors.errorStrong)),
    );
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Container(
        color: _hovered && widget.wide ? JitanColors.warmWhite : null,
        constraints: const BoxConstraints(minHeight: 58),
        padding: EdgeInsets.fromLTRB(20, 8, widget.wide ? 20 : 12, 8),
        child: Row(
          children: [
            if (widget.wide) ...widget.cells else Expanded(child: widget.cells.single),
            if (widget.wide)
              Expanded(
                flex: _GroupMembersCardState._flex[4],
                // Kept in place while hidden, so rows don't shift on hover.
                child: Align(alignment: Alignment.centerRight, child: Visibility.maintain(visible: showRemove, child: link)),
              )
            else if (showRemove)
              link,
          ],
        ),
      ),
    );
  }
}
