import 'package:flutter/material.dart';
import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:jitan_core/jitan_core.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:jitan_ui/jitan_ui.dart';

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
/// `Different work hours` 1349:1860, `Work hours configured` 1378:4,
/// `Inactive group` 1378:363): its employees from every company, and its
/// work hours and break, set with the schedule wizard.
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
              if (group.isActive)
                TextButton(
                  onPressed: () => _deactivate(group),
                  child: Text(context.t(AdminTextKeys.groupPageDeactivate), style: _action.copyWith(color: JitanColors.inkMuted)),
                )
              else
                TextButton(
                  onPressed: () => _reactivate(group),
                  child: Text(context.t(AdminTextKeys.groupPageReactivate), style: _action.copyWith(color: JitanColors.vermilion)),
                ),
            ],
          ),
        ),
        if (!group.isActive) ...[
          const SizedBox(height: 10),
          Text(context.t(AdminTextKeys.groupPageInactive), style: JitanTextStyles.stateMessage.copyWith(color: JitanColors.ink)),
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
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerLeft,
              // A button while the group is empty (1349:6), a link under the list (1378:4).
              child: loaded.members.isEmpty
                  ? JitanPrimaryButton(
                      label: context.t(AdminTextKeys.groupPageAddEmployees),
                      height: JitanDimensions.controlHeight,
                      onPressed: () => _addEmployees(group),
                    )
                  : _link(context.t(AdminTextKeys.groupPageAddMoreEmployees), () => _addEmployees(group)),
            ),
          ],
        ),
        const SizedBox(height: 20),
        _Section(number: '02', title: context.t(AdminTextKeys.groupPageHoursTitle), children: _hours(context, loaded)),
      ],
    );
  }

  /// "Fabian Peeters · FPT" and Remove (1349:178).
  Widget _memberRow(BuildContext context, GroupOverview group, GroupMember member, int index) => Container(
    height: 48,
    padding: const EdgeInsets.only(left: 16, right: 8),
    color: index.isOdd ? JitanColors.tableStripe : JitanColors.surface,
    child: Row(
      children: [
        Expanded(
          child: Text('${member.displayName} · ${member.code}', style: JitanTextStyles.tableCell, overflow: TextOverflow.ellipsis),
        ),
        TextButton(
          onPressed: () => _remove(group, member),
          child: Text(context.t(AdminTextKeys.groupPageRemove), style: _action.copyWith(color: JitanColors.vermilion)),
        ),
      ],
    ),
  );

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
      // 1349:6 (no employees yet) and 1349:1688 (only employees in several groups).
      null || GroupSchedule(status: GroupScheduleStatus.noSingleGroupEmployees) => [
        Text(
          context.t(loaded.members.isEmpty ? AdminTextKeys.groupPageHoursNoOwn : AdminTextKeys.groupPageHoursNoSingle),
          style: JitanTextStyles.fieldError,
        ),
      ],
      GroupSchedule(status: GroupScheduleStatus.noSchedule) => [
        Text(context.t(AdminTextKeys.groupPageHoursNone), style: JitanTextStyles.stateMessage),
        const SizedBox(height: 14),
        Align(alignment: Alignment.centerLeft, child: button),
      ],
      GroupSchedule(status: GroupScheduleStatus.employeesDiffer) => [
        Text(context.t(AdminTextKeys.groupPageHoursDiffer), style: JitanTextStyles.fieldError),
        const SizedBox(height: 14),
        Align(alignment: Alignment.centerLeft, child: _link(context.t(AdminTextKeys.groupPageSetHoursLink), () => _setHours(loaded))),
      ],
      // "Mon–Fri 08:00–16:30 · Break 30 min" (1378:4).
      GroupSchedule(:final variants) => [
        Text(
          context.t(
            AdminTextKeys.groupPageHoursSummary,
            args: {
              'hours': workHoursDaysSummary(t, variants.single),
              'minutes': variants.single.breaks.firstOrNull?.lengthMinutes ?? 0,
            },
          ),
          style: JitanTextStyles.stateMessage,
        ),
        const SizedBox(height: 14),
        Align(alignment: Alignment.centerLeft, child: button),
      ],
    };
  }

  /// A red text action with an arrow ("+ Add employees →", "Set work hours →").
  static Widget _link(String label, VoidCallback onPressed) => TextButton(
    onPressed: onPressed,
    style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 32)),
    child: Text(label, style: JitanTextStyles.inputText.copyWith(color: JitanColors.vermilion)),
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
