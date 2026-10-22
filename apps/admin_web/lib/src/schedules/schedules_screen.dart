import 'package:flutter/material.dart';
import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:jitan_core/jitan_core.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:jitan_ui/jitan_ui.dart';

import 'package:go_router/go_router.dart';

import '../app/admin_routes.dart';
import '../common/api_failure_text.dart';
import '../l10n/admin_text_keys.dart';
import 'deactivate_schedule_dialog.dart';
import 'manage_schedule_dialog.dart';
import 'schedule_dialog.dart';
import 'schedule_rows.dart';
import 'schedules_controller.dart';
import 'schedules_table.dart';

/// HR/Admin "Schedules" page (Figma `HR / Schedules — One row per group`
/// 1458:2; `Empty list` 1320:173, `Loading list` 1320:300, `List error`
/// 1320:427): the overview of every group's work hours, break and rounding.
/// A row opens the group's page, where its schedule is managed; "···" also
/// offers Edit schedule. There is no "Add schedule": hours are set when a
/// group is created, or on its page (product owner, 2026-10-22).
///
/// Schedules are global, not company-scoped. Status is Active or "Different
/// hours" (a switched-off schedule is no longer listed).
class SchedulesScreen extends StatefulWidget {
  const SchedulesScreen({super.key, required this.api});

  final SchedulesApi api;

  @override
  State<SchedulesScreen> createState() => _SchedulesScreenState();
}

class _SchedulesScreenState extends State<SchedulesScreen> {
  late final SchedulesController _controller = SchedulesController(widget.api)..load();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<GroupSchedule> get _groups => switch (_controller.state) {
    SchedulesLoaded(:final groups) => groups,
    _ => const [],
  };

  Future<void> _open({GroupSchedule? group}) async {
    final saved = await showScheduleDialog(
      context,
      api: widget.api,
      groups: _groups,
      options: _controller.options,
      group: group,
    );
    if (saved == null || !mounted) return;
    await _controller.load();
    if (!mounted) return;
    ScaffoldMessenger.maybeOf(
      context,
    )?.showSnackBar(SnackBar(content: Text(context.t(AdminTextKeys.scheduleSaved, args: {'group': saved.group.name}))));
  }

  void _openGroup(ScheduleRow row) => context.go(AdminRoutes.group(row.group.id));

  /// "···": Manage schedules (Figma 1359:2): the group's page, Edit, or
  /// removing the work hours or the break.
  Future<void> _manage(ScheduleRow row) async {
    final action = await showManageScheduleDialog(context, row: row);
    if (action == null || !mounted) return;
    switch (action) {
      case ScheduleRowAction.openGroup:
        _openGroup(row);
      case ScheduleRowAction.edit:
        await _open(group: row.schedule);
      case ScheduleRowAction.removeWorkHours || ScheduleRowAction.removeBreaks:
        final done = await showDeactivateScheduleDialog(
          context,
          controller: _controller,
          row: row,
          kind: action == ScheduleRowAction.removeWorkHours ? ScheduleKind.workHours : ScheduleKind.breaks,
        );
        if (!done || !mounted) return;
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(content: Text(context.t(AdminTextKeys.scheduleDeactivated, args: {'group': row.group.name}))),
        );
    }
  }

  @override
  Widget build(BuildContext context) => JitanListPage(
    top: ListenableBuilder(
      listenable: _controller,
      builder: (context, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Overview only (product owner, 2026-10-22): hours are set when a
          // group is created and changed on the group's page.
          JitanPageHeader(
            title: context.t(AdminTextKeys.scheduleTitle),
            subtitle: context.t(AdminTextKeys.scheduleListSubtitle),
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
    final filter = _controller.filter;
    void update(ScheduleFilter next) => _controller.updateFilter(next);
    final groups = {for (final g in _groups) g.group.id: g.group.name};
    final search = JitanFieldLabel(
      label: context.t(CommonTextKeys.searchLabel),
      child: JitanSearchField(
        clearTooltip: context.t(CommonTextKeys.searchClear),
        outlined: true,
        hintText: context.t(AdminTextKeys.scheduleSearch),
        onChanged: (text) => update(
          ScheduleFilter(search: text.trim(), groupId: filter.groupId, status: filter.status),
        ),
      ),
    );
    final group = JitanSelectField<int?>(
      label: context.t(AdminTextKeys.scheduleFilterGroup),
      value: filter.groupId,
      options: [
        JitanSelectOption(value: null, label: context.t(AdminTextKeys.scheduleFilterGroupAll)),
        for (final MapEntry(:key, :value) in groups.entries) JitanSelectOption(value: key, label: value),
      ],
      onChanged: (id) =>
          update(ScheduleFilter(search: filter.search, groupId: id, status: filter.status)),
    );
    final status = JitanSelectField<ScheduleRowStatus?>(
      label: context.t(AdminTextKeys.scheduleFilterStatus),
      value: filter.status,
      options: [
        JitanSelectOption(value: null, label: context.t(AdminTextKeys.scheduleFilterStatusAll)),
        JitanSelectOption(value: ScheduleRowStatus.active, label: context.t(CommonTextKeys.statusActive)),
        JitanSelectOption(
          value: ScheduleRowStatus.employeesDiffer,
          label: context.t(AdminTextKeys.scheduleStatusDiffer),
        ),
      ],
      onChanged: (status) =>
          update(ScheduleFilter(search: filter.search, groupId: filter.groupId, status: status)),
    );
    // As Figma 1458:2: Search 420, Group 200, Status 220; on a narrow
    // window they wrap, the search on its own line.
    const widths = (search: JitanDimensions.filterSearchWidth, group: 200.0, status: 220.0);
    const gap = 16.0;
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < widths.search + widths.group + widths.status + 2 * gap) {
          final half = (constraints.maxWidth - 14) / 2;
          return Wrap(
            spacing: 14,
            runSpacing: 14,
            crossAxisAlignment: WrapCrossAlignment.end,
            children: [
              SizedBox(width: constraints.maxWidth, child: search),
              SizedBox(width: half, child: group),
              SizedBox(width: half, child: status),
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            SizedBox(width: widths.search, child: search),
            const SizedBox(width: gap),
            SizedBox(width: widths.group, child: group),
            const SizedBox(width: gap),
            SizedBox(width: widths.status, child: status),
          ],
        );
      },
    );
  }

  Widget _content(BuildContext context) => switch (_controller.state) {
    SchedulesLoading() => _centered(JitanLoadingState(label: context.t(AdminTextKeys.scheduleListLoading))),
    SchedulesFailed(:final failure) => _centered(_error(context, failure)),
    SchedulesLoaded() when _controller.allRows.isEmpty => _centered(
      JitanEmptyState(
        title: context.t(AdminTextKeys.scheduleEmptyTitle),
        message: context.t(AdminTextKeys.scheduleEmptyMessage),
      ),
    ),
    SchedulesLoaded() => switch (_controller.visibleRows) {
      [] => _centered(
        JitanEmptyState(
          title: context.t(AdminTextKeys.scheduleNoMatchTitle),
          message: context.t(AdminTextKeys.scheduleNoMatchMessage),
        ),
      ),
      final rows => SchedulesTable(rows: rows, onManage: _manage, onOpen: _openGroup),
    },
  };

  Widget _error(BuildContext context, ApiClientException failure) {
    final keys = failureTextKeysFor(failure);
    return JitanErrorState(
      title: context.t(keys.title),
      message: context.t(keys.message),
      retryLabel: context.t(CommonTextKeys.retry),
      onRetry: _controller.load,
    );
  }

  static Widget _centered(Widget child) => JitanTableStateSliver(child: child);
}
