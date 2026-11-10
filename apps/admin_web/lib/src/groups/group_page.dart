import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:jitan_core/jitan_core.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../app/admin_routes.dart';
import '../common/api_failure_text.dart';
import '../l10n/admin_text_keys.dart';
import '../schedules/schedule_dialog.dart';
import 'add_employees_dialog.dart';
import 'choose_hours_source_dialog.dart';
import 'deactivate_group_dialog.dart';
import 'group_hours_panel.dart';
import 'group_hours_setup_card.dart';
import 'group_member_hours.dart';
import 'group_members_card.dart';
import 'group_page_controller.dart';
import 'group_summary_cards.dart';
import 'remove_member_dialog.dart';
import 'rename_group_dialog.dart';

/// One group's page (Figma `HR / Employee groups — Group page` 1455:2),
/// opened from its row on the Groups list: summary cards, the employees from
/// every company with where their work hours come from, and the weekly work
/// hours and break, set with the schedule wizard. Employees in several
/// groups without hours are pointed out, and HR chooses their group here.
class GroupPage extends StatefulWidget {
  const GroupPage({
    super.key,
    required this.groupId,
    required this.groupsApi,
    required this.membersApi,
    required this.schedulesApi,
    required this.scheduleSourceApi,
  });

  final int groupId;
  final GroupManagementApi groupsApi;
  final GroupMembersApi membersApi;
  final SchedulesApi schedulesApi;
  final ScheduleSourceApi scheduleSourceApi;

  @override
  State<GroupPage> createState() => _GroupPageState();
}

class _GroupPageState extends State<GroupPage> {
  late final GroupPageController _controller = GroupPageController(
    groupId: widget.groupId,
    groupsApi: widget.groupsApi,
    membersApi: widget.membersApi,
    schedulesApi: widget.schedulesApi,
  )..load();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _say(String text) => ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(text)));

  Future<void> _rename(GroupOverview group) async {
    final renamed = await showRenameGroupDialog(context, groupsApi: widget.groupsApi, group: group);
    if (renamed == null || !mounted) return;
    _say(context.t(AdminTextKeys.groupsRenamed, args: {'group': renamed.name}));
    await _controller.load();
  }

  Future<void> _deactivate(GroupOverview group) async {
    final done = await showDeactivateGroupDialog(context, groupsApi: widget.groupsApi, group: group);
    if (done == null || !mounted) return;
    _say(context.t(AdminTextKeys.groupsDeactivated, args: {'group': done.name}));
    await _controller.load();
  }

  Future<void> _reactivate(GroupOverview group) async {
    try {
      final done = await widget.groupsApi.reactivate(group.id);
      if (!mounted) return;
      _say(context.t(AdminTextKeys.groupsReactivated, args: {'group': done.name}));
      await _controller.load();
    } on ApiClientException catch (failure) {
      if (mounted) _say(context.t(failureTextKeysFor(failure).message));
    }
  }

  Future<void> _addEmployees(GroupOverview group) async {
    final loaded = _controller.state;
    final members = await showAddEmployeesDialog(
      context,
      membersApi: widget.membersApi,
      group: group,
      groupHasHours: loaded is GroupPageLoaded && loaded.schedule?.status == GroupScheduleStatus.configured,
    );
    if (members == null || !mounted) return;
    _say(context.t(AdminTextKeys.groupsMembersAdded, args: {'group': group.name}));
    await _controller.load();
  }

  Future<void> _remove(GroupOverview group, GroupMember member) async {
    final done = await showRemoveMemberDialog(context, controller: _controller, group: group, member: member);
    if (done && mounted) _say(context.t(AdminTextKeys.groupsMemberRemoved, args: {'name': member.displayName, 'group': group.name}));
  }

  Future<void> _setHours(GroupPageLoaded loaded) async {
    final schedule = loaded.schedule;
    final hasOne = schedule != null && schedule.variants.isNotEmpty;
    final saved = await showScheduleDialog(
      context,
      api: widget.schedulesApi,
      groups: loaded.schedules,
      group: hasOne ? schedule : null,
      groupId: hasOne ? null : loaded.group.id,
      fromGroupPage: true,
    );
    if (saved == null || !mounted) return;
    _say(context.t(AdminTextKeys.scheduleSaved, args: {'group': saved.group.name}));
    await _controller.load();
  }

  /// "Needs a choice": which group [member]'s hours come from.
  Future<void> _choose(GroupOverview group, GroupMember member) async {
    final chosen = await showChooseHoursSourceDialog(
      context,
      api: widget.scheduleSourceApi,
      member: member,
      suggestedGroupId: group.id,
    );
    if (chosen == null || !mounted) return;
    _say(context.t(AdminTextKeys.groupDetailChooseSaved, args: {'name': member.displayName, 'group': chosen.name}));
    await _controller.load();
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: JitanDimensions.pagePadding(MediaQuery.sizeOf(context).width),
    child: ListenableBuilder(
      listenable: _controller,
      builder: (context, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(alignment: Alignment.centerLeft, child: _back(context)),
          const SizedBox(height: 14),
          switch (_controller.state) {
            GroupPageLoading() => SizedBox(
              height: JitanDimensions.tableStateHeight,
              child: JitanLoadingState(label: context.t(AdminTextKeys.groupPageLoading)),
            ),
            GroupPageFailed(:final failure) => SizedBox(height: JitanDimensions.tableStateHeight, child: _error(context, failure)),
            final GroupPageLoaded loaded => _page(context, loaded),
          },
        ],
      ),
    ),
  );

  /// "← Groups": back to the list.
  Widget _back(BuildContext context) => TextButton(
    onPressed: () => context.go(AdminRoutes.groups),
    style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 4), minimumSize: const Size(0, 32)),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.arrow_back, size: 16, color: JitanColors.inkMuted),
        const SizedBox(width: 6),
        Text(
          context.t(AdminTextKeys.groupDetailBack),
          style: JitanTextStyles.tableCellStrong.copyWith(fontSize: 13, color: JitanColors.inkMuted),
        ),
      ],
    ),
  );

  Widget _page(BuildContext context, GroupPageLoaded loaded) {
    final group = loaded.group;
    final members = loaded.members;
    final hasHours = configuredVariant(loaded.schedule) != null;
    final needChoice = [
      for (final m in members)
        if (GroupMemberHours.of(m, group.id, groupHasHours: hasHours) == GroupMemberHours.needsChoice) m,
    ];
    final companies = {for (final m in members) ...m.companyIds};
    final subtitle = members.isEmpty
        ? context.t(AdminTextKeys.groupDetailSubtitleEmpty)
        : context.t(
            AdminTextKeys.groupDetailSubtitle,
            args: {
              'employees': context.tPlural(AdminTextKeys.groupDetailEmployeeCount, members.length),
              'companies': context.tPlural(AdminTextKeys.groupDetailCompanyCount, companies.length),
            },
          );
    final membersCard = GroupMembersCard(
      groupId: group.id,
      groupName: group.name,
      members: members,
      groupHasHours: hasHours,
      onAdd: group.isActive ? () => _addEmployees(group) : null,
      onRemove: (member) => _remove(group, member),
      onChoose: (member) => _choose(group, member),
    );
    final hoursPanel = GroupHoursPanel(
      schedule: loaded.schedule,
      hasMembers: members.isNotEmpty,
      onEdit: group.isActive ? () => _setHours(loaded) : null,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _header(context, group, subtitle),
        if (!group.isActive) ...[
          const SizedBox(height: 18),
          _notice(
            context,
            context.t(AdminTextKeys.groupDetailInactiveText),
            null,
            action: context.t(AdminTextKeys.groupPageReactivate),
            onAction: () => _reactivate(group),
            warning: false,
          ),
        ],
        const SizedBox(height: 24),
        // With hours: the summary cards. Without: one calm card that offers
        // to set them, instead of four cards that all say "Not set".
        if (hasHours)
          GroupSummaryCards(memberCount: members.length, needChoice: needChoice.length, schedule: loaded.schedule)
        else
          GroupHoursSetupCard(
            schedule: loaded.schedule,
            hasMembers: members.isNotEmpty,
            onSet: group.isActive ? () => _setHours(loaded) : null,
          ),
        if (needChoice.isNotEmpty && group.isActive) ...[
          const SizedBox(height: 20),
          _notice(
            context,
            needChoice.length == 1
                ? context.t(AdminTextKeys.groupDetailNoticeOne, args: {'name': needChoice.single.displayName})
                : context.t(AdminTextKeys.groupDetailNoticeMany, args: {'n': needChoice.length}),
            context.t(AdminTextKeys.groupDetailNoticeText),
            action: context.t(AdminTextKeys.groupDetailNoticeAction),
            onAction: () => _choose(group, needChoice.first),
          ),
        ],
        const SizedBox(height: 20),
        if (!hasHours)
          membersCard
        else
          LayoutBuilder(
            builder: (context, constraints) => constraints.maxWidth >= 1000
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [Expanded(child: membersCard), const SizedBox(width: 20), SizedBox(width: 340, child: hoursPanel)],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [membersCard, const SizedBox(height: 20), hoursPanel],
                  ),
          ),
      ],
    );
  }

  /// Title with its state, the subtitle, and Rename and "···".
  Widget _header(BuildContext context, GroupOverview group, String subtitle) {
    final title = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 14,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Semantics(header: true, child: Text(group.name, style: JitanTextStyles.pageTitle)),
            if (group.isActive)
              JitanBadge(label: context.t(AdminTextKeys.groupDetailActive))
            else
              JitanBadge.neutral(label: context.t(AdminTextKeys.groupDetailInactive), dot: true),
          ],
        ),
        const SizedBox(height: 8),
        Text(subtitle, style: JitanTextStyles.pageSubtitle),
      ],
    );
    final actions = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        JitanOutlineButton(label: context.t(AdminTextKeys.groupPageRename), onPressed: () => _rename(group)),
        const SizedBox(width: 10),
        PopupMenuButton<bool>(
          tooltip: context.t(AdminTextKeys.groupDetailMore),
          position: PopupMenuPosition.under,
          color: JitanColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          onSelected: (_) => group.isActive ? _deactivate(group) : _reactivate(group),
          itemBuilder: (context) => [
            PopupMenuItem(
              value: true,
              child: Text(
                context.t(group.isActive ? AdminTextKeys.groupPageDeactivate : AdminTextKeys.groupPageReactivate),
                style: JitanTextStyles.tableCellStrong.copyWith(color: group.isActive ? JitanColors.errorStrong : JitanColors.ink),
              ),
            ),
          ],
          child: Container(
            height: JitanDimensions.fieldHeight,
            width: JitanDimensions.fieldHeight,
            decoration: BoxDecoration(
              color: JitanColors.surface,
              borderRadius: BorderRadius.circular(JitanDimensions.inputRadius),
              border: Border.all(color: JitanColors.inputBorder),
            ),
            child: const Icon(Icons.more_horiz, size: 20, color: JitanColors.ink),
          ),
        ),
      ],
    );
    return LayoutBuilder(
      builder: (context, constraints) => constraints.maxWidth >= 640
          ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: title), const SizedBox(width: 16), actions])
          : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [title, const SizedBox(height: 16), actions]),
    );
  }

  /// The orange band ("Hanne Claes has no work hours … Choose group →"), or
  /// the grey one of an inactive group.
  Widget _notice(
    BuildContext context,
    String title,
    String? text, {
    required String action,
    required VoidCallback onAction,
    bool warning = true,
  }) {
    final color = warning ? JitanColors.warning : JitanColors.ink;
    final linkColor = warning ? color : JitanColors.vermilion;
    final link = TextButton(
      onPressed: onAction,
      style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 6), minimumSize: const Size(0, 32)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(child: Text(action, style: JitanTextStyles.tableCellStrong.copyWith(color: linkColor))),
          const SizedBox(width: 6),
          Icon(Icons.arrow_forward, size: 16, color: linkColor),
        ],
      ),
    );
    final words = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: JitanTextStyles.tableCellStrong.copyWith(color: color)),
        if (text != null) ...[
          const SizedBox(height: 2),
          Text(text, style: JitanTextStyles.tableCell.copyWith(fontSize: 13, color: color)),
        ],
      ],
    );
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 14, 12, 14),
      decoration: BoxDecoration(
        color: warning ? JitanColors.warningSurface : JitanColors.noteSurface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) => constraints.maxWidth >= 560
            ? Row(children: [Expanded(child: words), const SizedBox(width: 12), link])
            : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [words, const SizedBox(height: 6), link]),
      ),
    );
  }

  Widget _error(BuildContext context, ApiClientException failure) {
    final keys = failureTextKeysFor(failure);
    return JitanErrorState(
      title: context.t(keys.title),
      message: context.t(keys.message),
      retryLabel: context.t(CommonTextKeys.retry),
      onRetry: _controller.load,
    );
  }
}
