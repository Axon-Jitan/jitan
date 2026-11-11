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
import '../schedules/schedule_summary_text.dart';
import 'add_employees_dialog.dart';
import 'choose_hours_source_dialog.dart';
import 'deactivate_group_dialog.dart';
import 'group_hours_panel.dart';
import 'group_member_hours.dart';
import 'group_members_card.dart';
import 'group_page_controller.dart';
import 'group_state_text.dart';
import 'remove_member_dialog.dart';
import 'rename_group_dialog.dart';

/// One group's page (Figma `HR / Groups V2 — a group` `1554:101`; needs a
/// choice `1556:761`, no hours yet `1556:937`, inactive `1558:409`), opened
/// from its row on the Groups list: the employees from every company with
/// where their work hours come from, and the work hours and break, set with
/// the schedule wizard. Employees in several groups without hours are
/// pointed out, and HR chooses their group here.
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

  void _say(String text, {bool failed = false}) => showJitanToast(context, text, failed: failed);

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
      if (mounted) _say(context.t(failureTextKeysFor(failure).message), failed: true);
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
      hoursOf: (groupId) {
        final loaded = _controller.state;
        if (loaded is! GroupPageLoaded) return null;
        final variant = configuredVariant(loaded.schedules.where((s) => s.group.id == groupId).firstOrNull);
        return variant == null ? null : workHoursDaysSummary(TranslationScope.of(context), variant);
      },
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
          const SizedBox(height: 12),
          switch (_controller.state) {
            GroupPageLoading() => GroupStateText(context.t(AdminTextKeys.groupPageLoading)),
            GroupPageFailed() => GroupStateText(context.t(AdminTextKeys.groupPageLoadFailed), onRetry: _controller.load),
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
    final status = context.t(group.isActive ? CommonTextKeys.statusActive : CommonTextKeys.statusInactive);
    final subtitle = context.t(
      AdminTextKeys.groupDetailStatusLine,
      args: {
        'status': status,
        'people': members.isEmpty
            ? context.t(AdminTextKeys.groupDetailNoEmployees)
            : context.t(
                AdminTextKeys.groupDetailPeople,
                args: {
                  'employees': context.tPlural(AdminTextKeys.groupDetailEmployeeCount, members.length),
                  'companies': context.tPlural(AdminTextKeys.groupDetailCompanyCount, companies.length),
                },
              ),
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
          const SizedBox(height: 22),
          _note(context, context.t(AdminTextKeys.groupDetailInactiveText), warning: false),
        ] else if (needChoice.isNotEmpty) ...[
          const SizedBox(height: 22),
          _note(
            context,
            needChoice.length == 1
                ? context.t(AdminTextKeys.groupDetailNoticeOne, args: {'name': needChoice.single.displayName})
                : context.t(AdminTextKeys.groupDetailNoticeMany, args: {'n': needChoice.length}),
            action: context.t(AdminTextKeys.groupDetailNoticeAction),
            onAction: () => _choose(group, needChoice.first),
          ),
        ],
        const SizedBox(height: 22),
        LayoutBuilder(
          builder: (context, constraints) => constraints.maxWidth >= 1000
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [Expanded(child: membersCard), const SizedBox(width: 20), SizedBox(width: 380, child: hoursPanel)],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [hoursPanel, const SizedBox(height: 20), membersCard],
                ),
        ),
      ],
    );
  }

  /// The name and its status line; Deactivate (quiet, red) and Rename, or
  /// Reactivate for an inactive group.
  Widget _header(BuildContext context, GroupOverview group, String subtitle) {
    final title = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(header: true, child: Text(group.name, style: JitanTextStyles.pageTitle)),
        const SizedBox(height: 6),
        Text(subtitle, style: JitanTextStyles.pageSubtitle),
      ],
    );
    final actions = Wrap(
      spacing: 14,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: group.isActive
          ? [
              TextButton(
                onPressed: () => _deactivate(group),
                style: TextButton.styleFrom(
                  foregroundColor: JitanColors.errorStrong,
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                  minimumSize: Size.zero,
                ),
                child: Text(
                  context.t(AdminTextKeys.groupPageDeactivate),
                  style: JitanTextStyles.tableCellStrong.copyWith(color: JitanColors.errorStrong),
                ),
              ),
              JitanSecondaryButton(label: context.t(AdminTextKeys.groupPageRename), onPressed: () => _rename(group)),
            ]
          : [JitanPrimaryButton(label: context.t(AdminTextKeys.groupPageReactivate), onPressed: () => _reactivate(group))],
    );
    return LayoutBuilder(
      builder: (context, constraints) => constraints.maxWidth >= 640
          ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: title), const SizedBox(width: 16), actions])
          : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [title, const SizedBox(height: 16), actions]),
    );
  }

  /// The soft amber note ("Jonas Claes has no work hours … Choose group →"),
  /// or the grey one of an inactive group.
  Widget _note(BuildContext context, String text, {String? action, VoidCallback? onAction, bool warning = true}) {
    final words = Text(text, style: JitanTextStyles.tableCell.copyWith(color: JitanColors.ink));
    final link = action == null
        ? null
        : TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 4), minimumSize: const Size(0, 28)),
            child: Text('$action →', style: JitanTextStyles.tableCell.copyWith(fontWeight: FontWeight.w500, color: JitanColors.vermilion)),
          );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      decoration: BoxDecoration(
        color: warning ? JitanColors.warningSurface : JitanColors.noteSurface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) => link == null
            ? words
            : constraints.maxWidth >= 560
            ? Row(children: [Expanded(child: words), const SizedBox(width: 12), link])
            : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [words, const SizedBox(height: 4), link]),
      ),
    );
  }
}
