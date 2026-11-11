import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:jitan_core/jitan_core.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../app/admin_routes.dart';
import '../l10n/admin_text_keys.dart';
import 'create_group_dialog.dart';
import 'group_state_text.dart';
import 'groups_controller.dart';
import 'groups_table.dart';

/// HR/Admin "Groups" (Figma `HR / Groups V2`: page `1554:2`, no match
/// `1558:2`, nothing yet `1558:104`, loading `1558:209`, error `1558:309`).
/// A row opens the group's page, where it is renamed and deactivated.
/// Groups are shared by all companies, so this page is not company-scoped.
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

  void _open(GroupOverview group) => context.go(AdminRoutes.group(group.id));

  Future<void> _create() async {
    final created = await showCreateGroupDialog(
      context,
      groupsApi: widget.groupsApi,
      membersApi: widget.membersApi,
      schedulesApi: widget.schedulesApi,
    );
    if (created == null || !mounted) return;
    // Back on the list with the new group in it (product owner, 2026-10-22);
    // its row opens the group's page.
    showJitanToast(context, context.t(AdminTextKeys.groupsCreated, args: {'group': created.name}));
    await _controller.load();
  }

  bool get _isEmpty => switch (_controller.state) {
    GroupsLoaded(groups: []) => true,
    _ => false,
  };

  @override
  Widget build(BuildContext context) => JitanListPage(
    top: ListenableBuilder(
      listenable: _controller,
      builder: (context, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          JitanPageHeader(
            title: context.t(AdminTextKeys.groupsTitle),
            subtitle: switch (_controller.state) {
              GroupsLoaded(:final groups) when groups.isNotEmpty => context.tPlural(AdminTextKeys.groupsCount, groups.length),
              _ => context.t(AdminTextKeys.groupsSubtitle),
            },
            action: _isEmpty
                ? null
                : JitanPrimaryButton(
                    label: context.t(AdminTextKeys.groupsAdd),
                    icon: Icons.add,
                    height: JitanDimensions.controlHeight,
                    onPressed: _create,
                  ),
          ),
          const SizedBox(height: JitanDimensions.headerToToolbar),
          if (!_isEmpty) ...[_toolbar(context), const SizedBox(height: JitanDimensions.toolbarToTable)],
        ],
      ),
    ),
    list: [ListenableBuilder(listenable: _controller, builder: (context, _) => _content(context))],
  );

  /// A search box and All · Active · Inactive, as on Terminals.
  Widget _toolbar(BuildContext context) {
    final search = JitanSearchField(
      clearTooltip: context.t(CommonTextKeys.searchClear),
      outlined: true,
      hintText: context.t(AdminTextKeys.groupsSearch),
      onChanged: _controller.updateSearch,
    );
    final status = JitanPillSwitch<GroupStatusFilter?>(
      options: [
        (null, context.t(AdminTextKeys.groupsFilterAll)),
        (GroupStatusFilter.active, context.t(CommonTextKeys.statusActive)),
        (GroupStatusFilter.inactive, context.t(CommonTextKeys.statusInactive)),
      ],
      value: _controller.status,
      onChanged: _controller.updateStatus,
    );
    return LayoutBuilder(
      builder: (context, constraints) => constraints.maxWidth < JitanDimensions.phoneBreakpoint
          ? Column(crossAxisAlignment: CrossAxisAlignment.start, spacing: 12, children: [search, status])
          : Row(spacing: 12, children: [SizedBox(width: 320, child: search), status]),
    );
  }

  Widget _content(BuildContext context) => switch (_controller.state) {
    GroupsLoading() => _line(GroupStateText(context.t(AdminTextKeys.groupsLoading))),
    GroupsFailed() => _line(GroupStateText(context.t(AdminTextKeys.groupsLoadFailed), onRetry: _controller.load)),
    GroupsLoaded(groups: []) => SliverToBoxAdapter(
      child: JitanEmptyPage(
        title: context.t(AdminTextKeys.groupsEmptyTitle),
        message: context.t(AdminTextKeys.groupsEmptyMessage),
        actionLabel: context.t(AdminTextKeys.groupsAdd),
        onAction: _create,
      ),
    ),
    GroupsLoaded(:final schedules) => switch (_controller.visibleGroups) {
      [] => SliverToBoxAdapter(child: _nothingShown(context)),
      final groups => GroupsTable(groups: groups, schedules: schedules, onOpen: _open),
    },
  };

  /// Nothing to show, said for what HR did: a search or a status (`1558:2`).
  Widget _nothingShown(BuildContext context) {
    final (title, message) = switch ((_controller.search, _controller.status)) {
      ('', GroupStatusFilter.inactive) => (AdminTextKeys.groupsNoInactiveTitle, AdminTextKeys.groupsNoInactiveText),
      ('', GroupStatusFilter.active) => (AdminTextKeys.groupsNoActiveTitle, AdminTextKeys.groupsNoActiveText),
      _ => (AdminTextKeys.groupsNoMatchTitle, AdminTextKeys.groupsNoMatchMessage),
    };
    return JitanNoResults(title: context.t(title), message: context.t(message));
  }

  static Widget _line(Widget child) => SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.only(top: 4), child: child));
}
