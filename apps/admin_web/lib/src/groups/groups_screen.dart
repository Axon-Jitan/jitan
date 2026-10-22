import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:jitan_core/jitan_core.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../app/admin_routes.dart';
import '../common/api_failure_text.dart';
import '../l10n/admin_text_keys.dart';
import 'create_group_dialog.dart';
import 'deactivate_group_dialog.dart';
import 'group_state_text.dart';
import 'groups_controller.dart';
import 'groups_table.dart';
import 'manage_group_dialog.dart';
import 'rename_group_dialog.dart';

/// HR/Admin "Employee groups" page (Figma `HR / Employee groups — Overview`
/// 1340:2, `Empty` 1342:2, `Loading` 1342:162, `Error` 1342:322). Groups are
/// shared by all companies, so this page is not company-scoped.
class GroupsScreen extends StatefulWidget {
  const GroupsScreen({super.key, required this.groupsApi, required this.membersApi, required this.schedulesApi});

  final GroupManagementApi groupsApi;
  final GroupMembersApi membersApi;
  final SchedulesApi schedulesApi;

  @override
  State<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends State<GroupsScreen> {
  late final GroupsController _controller = GroupsController(
    groupsApi: widget.groupsApi,
    schedulesApi: widget.schedulesApi,
  )..load();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _say(String text) => ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(text)));

  void _open(GroupOverview group) => context.go(AdminRoutes.group(group.id));

  Future<void> _create() async {
    final created = await showCreateGroupDialog(
      context,
      groupsApi: widget.groupsApi,
      membersApi: widget.membersApi,
      schedulesApi: widget.schedulesApi,
    );
    if (created == null || !mounted) return;
    _say(context.t(AdminTextKeys.groupsCreated, args: {'group': created.name}));
    _open(created);
  }

  Future<void> _manage(GroupOverview group) async {
    final action = await showManageGroupDialog(context, group: group);
    if (action == null || !mounted) return;
    switch (action) {
      case GroupAction.rename:
        final renamed = await showRenameGroupDialog(context, groupsApi: widget.groupsApi, group: group);
        if (renamed == null || !mounted) return;
        _say(context.t(AdminTextKeys.groupsRenamed, args: {'group': renamed.name}));
        await _controller.load();
      case GroupAction.deactivate:
        final done = await showDeactivateGroupDialog(
          context,
          groupsApi: widget.groupsApi,
          group: group,
          onManageEmployees: () => _open(group),
        );
        if (done == null || !mounted) return;
        _say(context.t(AdminTextKeys.groupsDeactivated, args: {'group': done.name}));
        await _controller.load();
      case GroupAction.reactivate:
        try {
          final done = await widget.groupsApi.reactivate(group.id);
          if (!mounted) return;
          _say(context.t(AdminTextKeys.groupsReactivated, args: {'group': done.name}));
          await _controller.load();
        } on ApiClientException catch (failure) {
          if (mounted) _say(context.t(failureTextKeysFor(failure).message));
        }
    }
  }

  @override
  Widget build(BuildContext context) => JitanListPage(
    top: ListenableBuilder(
      listenable: _controller,
      builder: (context, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          JitanPageHeader(
            title: context.t(AdminTextKeys.groupsTitle),
            subtitle: context.t(AdminTextKeys.groupsSubtitle),
            action: JitanPrimaryButton(
              label: context.t(AdminTextKeys.groupsAdd),
              icon: Icons.add,
              height: JitanDimensions.controlHeight,
              onPressed: _create,
            ),
          ),
          const SizedBox(height: JitanDimensions.headerToToolbar),
          _toolbar(context),
          const SizedBox(height: JitanDimensions.toolbarToTable),
        ],
      ),
    ),
    list: [ListenableBuilder(listenable: _controller, builder: (context, _) => _content(context))],
  );

  Widget _toolbar(BuildContext context) {
    // Labelled like the other list pages (Employees, Schedules, Time records).
    final search = JitanFieldLabel(
      label: context.t(CommonTextKeys.searchLabel),
      child: JitanSearchField(
        clearTooltip: context.t(CommonTextKeys.searchClear),
        outlined: true,
        hintText: context.t(AdminTextKeys.groupsSearch),
        onChanged: _controller.updateSearch,
      ),
    );
    final status = JitanSelectField<GroupStatusFilter?>(
      label: context.t(AdminTextKeys.scheduleFilterStatus),
      value: _controller.status,
      options: [
        JitanSelectOption(value: null, label: context.t(AdminTextKeys.groupsFilterAll)),
        JitanSelectOption(value: GroupStatusFilter.active, label: context.t(CommonTextKeys.statusActive)),
        JitanSelectOption(value: GroupStatusFilter.inactive, label: context.t(CommonTextKeys.statusInactive)),
      ],
      onChanged: _controller.updateStatus,
    );
    return LayoutBuilder(
      builder: (context, constraints) => constraints.maxWidth < JitanDimensions.phoneBreakpoint
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [search, const SizedBox(height: 14), status],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                SizedBox(width: JitanDimensions.filterSearchWidth, child: search),
                const SizedBox(width: 16),
                SizedBox(width: 220, child: status),
              ],
            ),
    );
  }

  /// The table, or the state line Figma draws in its place (1342:2 empty,
  /// 1342:162 loading, 1342:322 error).
  Widget _content(BuildContext context) => switch (_controller.state) {
    GroupsLoading() => _state(GroupStateText(context.t(AdminTextKeys.groupsLoading))),
    GroupsFailed() => _state(GroupStateText(context.t(AdminTextKeys.groupsLoadFailed), onRetry: _controller.load)),
    GroupsLoaded(groups: []) => _state(GroupStateText(context.t(AdminTextKeys.groupsEmptyMessage))),
    GroupsLoaded(:final schedules) => switch (_controller.visibleGroups) {
      [] => _state(GroupStateText(context.t(AdminTextKeys.groupsNoMatchMessage))),
      final groups => GroupsTable(groups: groups, schedules: schedules, onManage: _manage, onOpen: _open),
    },
  };

  static Widget _state(Widget child) => SliverToBoxAdapter(
    child: Padding(padding: const EdgeInsets.only(top: 20), child: child),
  );
}
