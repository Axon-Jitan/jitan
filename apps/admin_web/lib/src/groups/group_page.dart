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
import 'deactivate_group_dialog.dart';
import 'group_page_controller.dart';
import 'remove_member_dialog.dart';
import 'rename_group_dialog.dart';

/// One group's page (Figma `HR / Employee groups — New group setup` 1349:6,
/// `New group with employees` 1349:178, `Multiple groups` 1349:1688,
/// `Different work hours` 1349:1860): its employees from every company, and
/// its work hours and break, set with the schedule wizard.
class GroupPage extends StatefulWidget {
  const GroupPage({
    super.key,
    required this.groupId,
    required this.groupsApi,
    required this.membersApi,
    required this.schedulesApi,
  });

  final int groupId;
  final GroupManagementApi groupsApi;
  final GroupMembersApi membersApi;
  final SchedulesApi schedulesApi;

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
    final members = await showAddEmployeesDialog(context, membersApi: widget.membersApi, group: group);
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
    );
    if (saved == null || !mounted) return;
    _say(context.t(AdminTextKeys.scheduleSaved, args: {'group': saved.group.name}));
    await _controller.load();
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: JitanDimensions.pagePadding(MediaQuery.sizeOf(context).width),
    child: ListenableBuilder(
      listenable: _controller,
      builder: (context, _) => switch (_controller.state) {
        GroupPageLoading() => SizedBox(
          height: JitanDimensions.tableStateHeight,
          child: JitanLoadingState(label: context.t(AdminTextKeys.groupPageLoading)),
        ),
        GroupPageFailed(:final failure) => SizedBox(height: JitanDimensions.tableStateHeight, child: _error(context, failure)),
        final GroupPageLoaded loaded => _page(context, loaded),
      },
    ),
  );

  Widget _page(BuildContext context, GroupPageLoaded loaded) {
    final group = loaded.group;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => context.go(AdminRoutes.groups),
            icon: const Icon(Icons.arrow_back, size: 18, color: JitanColors.inkMuted),
            label: Text(context.t(AdminTextKeys.groupPageBack), style: JitanTextStyles.stateMessage),
          ),
        ),
        const SizedBox(height: 8),
        JitanPageHeader(
          title: group.name,
          subtitle: context.t(AdminTextKeys.groupPageSubtitle),
          action: Wrap(
            spacing: 8,
            children: [
              TextButton(
                onPressed: () => _rename(group),
                child: Text(context.t(AdminTextKeys.groupPageRename), style: _action.copyWith(color: JitanColors.vermilion)),
              ),
              TextButton(
                onPressed: () => group.isActive ? _deactivate(group) : _reactivate(group),
                child: Text(
                  context.t(group.isActive ? AdminTextKeys.groupPageDeactivate : AdminTextKeys.groupPageReactivate),
                  style: _action,
                ),
              ),
            ],
          ),
        ),
        if (!group.isActive) ...[
          const SizedBox(height: 16),
          Text(context.t(AdminTextKeys.groupPageInactive), style: JitanTextStyles.fieldError),
        ],
        const SizedBox(height: 28),
        _Section(
          number: '01',
          title: context.t(AdminTextKeys.groupPageEmployeesTitle),
          children: [
            Text(
              context.t(loaded.members.isEmpty ? AdminTextKeys.groupPageEmployeesNone : AdminTextKeys.groupPageEmployeesText),
              style: JitanTextStyles.stateMessage,
            ),
            const SizedBox(height: 14),
            for (final (index, member) in loaded.members.indexed) _memberRow(context, group, member, index),
            if (group.isActive) ...[
              const SizedBox(height: 14),
              Align(
                alignment: Alignment.centerLeft,
                child: JitanPrimaryButton(
                  label: context.t(AdminTextKeys.groupPageAddEmployees),
                  icon: Icons.add,
                  height: JitanDimensions.controlHeight,
                  onPressed: () => _addEmployees(group),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 20),
        _Section(number: '02', title: context.t(AdminTextKeys.groupPageHoursTitle), children: _hours(context, loaded)),
      ],
    );
  }

  Widget _memberRow(BuildContext context, GroupOverview group, GroupMember member, int index) {
    final others = [for (final g in member.groups) if (g != group.name) g];
    final detail = [
      member.companies.join(', '),
      others.isEmpty
          ? context.t(AdminTextKeys.groupsPickerAlsoInNone)
          : context.t(AdminTextKeys.groupsPickerAlsoIn, args: {'groups': others.join(', ')}),
    ].where((s) => s.isNotEmpty).join(' · ');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: index.isOdd ? JitanColors.tableStripe : JitanColors.surface,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${member.displayName} · ${member.code}', style: JitanTextStyles.tableCellStrong, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(detail, style: JitanTextStyles.stateMessage.copyWith(fontSize: 12), overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          TextButton(
            onPressed: () => _remove(group, member),
            child: Text(context.t(AdminTextKeys.groupPageRemove), style: _action.copyWith(color: JitanColors.vermilion)),
          ),
        ],
      ),
    );
  }

  /// Section 02: why there are no hours yet, or the hours and break, with
  /// the button that opens the schedule wizard for this group.
  List<Widget> _hours(BuildContext context, GroupPageLoaded loaded) {
    final t = TranslationScope.of(context);
    final schedule = loaded.schedule;
    final button = JitanPrimaryButton(
      label: context.t(schedule?.variants.isNotEmpty == true ? AdminTextKeys.groupPageEditHours : AdminTextKeys.groupPageSetHours),
      height: JitanDimensions.controlHeight,
      onPressed: () => _setHours(loaded),
    );
    return switch (schedule) {
      null || GroupSchedule(status: GroupScheduleStatus.noSingleGroupEmployees) => [
        Text(context.t(AdminTextKeys.groupPageHoursNoOwn), style: JitanTextStyles.fieldError),
      ],
      GroupSchedule(status: GroupScheduleStatus.noSchedule) => [
        Text(context.t(AdminTextKeys.groupPageHoursNone), style: JitanTextStyles.stateMessage),
        const SizedBox(height: 14),
        Align(alignment: Alignment.centerLeft, child: button),
      ],
      GroupSchedule(status: GroupScheduleStatus.employeesDiffer) => [
        Text(context.t(AdminTextKeys.groupPageHoursDiffer), style: JitanTextStyles.fieldError),
        const SizedBox(height: 14),
        Align(alignment: Alignment.centerLeft, child: button),
      ],
      GroupSchedule(:final variants) => [
        _summaryLine(context.t(AdminTextKeys.groupPageWorkHours), workHoursSummary(t, variants.single)),
        const SizedBox(height: 8),
        _summaryLine(context.t(AdminTextKeys.groupPageBreak), breaksSummary(t, variants.single)),
        const SizedBox(height: 14),
        Align(alignment: Alignment.centerLeft, child: button),
      ],
    };
  }

  static Widget _summaryLine(String label, String value) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SizedBox(width: 120, child: Text(label, style: JitanTextStyles.fieldLabel)),
      Expanded(child: Text(value, style: JitanTextStyles.inputText)),
    ],
  );

  Widget _error(BuildContext context, ApiClientException failure) {
    final keys = failureTextKeysFor(failure);
    return JitanErrorState(
      title: context.t(keys.title),
      message: context.t(keys.message),
      retryLabel: context.t(CommonTextKeys.retry),
      onRetry: _controller.load,
    );
  }

  static final _action = JitanTextStyles.inputText.copyWith(fontWeight: FontWeight.w600);
}

/// A numbered white card of the group page ("01 Employees").
class _Section extends StatelessWidget {
  const _Section({required this.number, required this.title, required this.children});

  final String number;
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => JitanSurfaceCard(
    radius: JitanDimensions.tableCardRadius,
    padding: const EdgeInsets.all(24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('$number   $title', style: JitanTextStyles.stateTitle.copyWith(fontSize: 18)),
        const SizedBox(height: 14),
        ...children,
      ],
    ),
  );
}
