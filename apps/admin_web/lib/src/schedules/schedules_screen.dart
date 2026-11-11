import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:jitan_core/jitan_core.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../app/admin_routes.dart';
import '../groups/group_state_text.dart';
import '../l10n/admin_text_keys.dart';
import 'schedule_details_dialog.dart';
import 'schedule_dialog.dart';
import 'schedule_rows.dart';
import 'schedules_controller.dart';
import 'schedules_table.dart';

/// HR/Admin "Schedules" (Figma `HR / Schedules V2 — page` `1547:2`; a
/// schedule `1552:386`, remove break `1547:393`, no match `1548:567`,
/// nothing yet `1548:618`): every group's work days, hours and break. A row
/// opens the schedule's pop-up; "Add schedule" opens the wizard.
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

  void _say(String text, {bool failed = false}) => showJitanToast(context, text, failed: failed);

  Future<void> _edit({GroupSchedule? group}) async {
    final saved = await showScheduleDialog(
      context,
      api: widget.api,
      groups: _groups,
      options: _controller.options,
      group: group,
    );
    if (saved == null || !mounted) return;
    _say(context.t(AdminTextKeys.scheduleSaved, args: {'group': saved.group.name}));
    await _controller.load();
  }

  Future<void> _open(ScheduleRow row) async {
    final action = await showScheduleDetailsDialog(context, row: row);
    if (action == null || !mounted) return;
    switch (action) {
      case ScheduleRowAction.openGroup:
        context.go(AdminRoutes.group(row.group.id));
      case ScheduleRowAction.edit:
        await _edit(group: row.schedule);
      case ScheduleRowAction.removeWorkHours:
        await _remove(row, ScheduleKind.workHours, AdminTextKeys.scheduleRemovedHours);
      case ScheduleRowAction.removeBreaks:
        await _remove(row, ScheduleKind.breaks, AdminTextKeys.scheduleRemovedBreak);
    }
  }

  /// Asks first; the toast follows the server's answer, never before it.
  Future<void> _remove(ScheduleRow row, ScheduleKind kind, String doneKey) async {
    final sure = await confirmScheduleRemove(context, row: row, kind: kind);
    if (!sure || !mounted) return;
    final failure = await _controller.deactivate(row, kind);
    if (!mounted) return;
    if (failure == null) {
      _say(context.t(doneKey, args: {'group': row.group.name}));
    } else {
      _say(context.t(AdminTextKeys.scheduleChangeFailed), failed: true);
    }
  }

  bool get _isEmpty => _controller.state is SchedulesLoaded && _controller.allRows.isEmpty;

  @override
  Widget build(BuildContext context) => JitanListPage(
    top: ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final rows = _controller.allRows;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            JitanPageHeader(
              title: context.t(AdminTextKeys.scheduleTitle),
              subtitle: rows.isEmpty
                  ? context.t(AdminTextKeys.scheduleListSubtitle)
                  : context.tPlural(AdminTextKeys.scheduleCount, rows.length),
              action: _isEmpty
                  ? null
                  : JitanPrimaryButton(
                      label: context.t(AdminTextKeys.scheduleAddAction),
                      icon: Icons.add,
                      height: JitanDimensions.controlHeight,
                      onPressed: _controller.state is SchedulesLoaded ? _edit : null,
                    ),
            ),
            const SizedBox(height: JitanDimensions.headerToToolbar),
            if (!_isEmpty) ...[_toolbar(context), const SizedBox(height: JitanDimensions.toolbarToTable)],
          ],
        );
      },
    ),
    list: [ListenableBuilder(listenable: _controller, builder: (context, _) => _content(context))],
  );

  /// A search box and All · Active · Different hours, as on Terminals.
  Widget _toolbar(BuildContext context) {
    final search = JitanSearchField(
      clearTooltip: context.t(CommonTextKeys.searchClear),
      outlined: true,
      hintText: context.t(AdminTextKeys.scheduleSearch),
      onChanged: _controller.updateSearch,
    );
    final status = JitanPillSwitch<ScheduleRowStatus?>(
      options: [
        (null, context.t(AdminTextKeys.scheduleFilterAll)),
        (ScheduleRowStatus.active, context.t(CommonTextKeys.statusActive)),
        (ScheduleRowStatus.employeesDiffer, context.t(AdminTextKeys.scheduleStatusDiffer)),
      ],
      value: _controller.filter.status,
      onChanged: _controller.updateStatus,
    );
    return LayoutBuilder(
      builder: (context, constraints) => constraints.maxWidth < JitanDimensions.phoneBreakpoint
          ? Column(crossAxisAlignment: CrossAxisAlignment.start, spacing: 12, children: [search, status])
          // "Different hours" makes the pills wide: they go under the
          // search when the page is narrow.
          : Wrap(spacing: 12, runSpacing: 12, crossAxisAlignment: WrapCrossAlignment.center, children: [SizedBox(width: 320, child: search), status]),
    );
  }

  Widget _content(BuildContext context) => switch (_controller.state) {
    // One quiet line, as on Terminals (Figma `1553:1218`, `1553:1318`).
    SchedulesLoading() => SliverToBoxAdapter(child: GroupStateText(context.t(AdminTextKeys.scheduleListLoading))),
    SchedulesFailed() => SliverToBoxAdapter(
      child: GroupStateText(context.t(AdminTextKeys.scheduleListLoadFailed), onRetry: _controller.load),
    ),
    SchedulesLoaded() when _isEmpty => SliverToBoxAdapter(
      child: JitanEmptyPage(
        title: context.t(AdminTextKeys.scheduleEmptyTitle),
        message: context.t(AdminTextKeys.scheduleEmptyMessage),
        actionLabel: context.t(AdminTextKeys.scheduleAddAction),
        onAction: _edit,
      ),
    ),
    SchedulesLoaded() => switch (_controller.visibleRows) {
      [] => SliverToBoxAdapter(child: _nothingShown(context)),
      final rows => SchedulesTable(rows: rows, onOpen: _open),
    },
  };

  /// Nothing to show, said for what HR did: a search or a status (`1548:567`).
  Widget _nothingShown(BuildContext context) {
    final filter = _controller.filter;
    final (title, message) = switch ((filter.search, filter.status)) {
      ('', ScheduleRowStatus.employeesDiffer) => (AdminTextKeys.scheduleNoDifferTitle, AdminTextKeys.scheduleNoDifferText),
      ('', ScheduleRowStatus.active) => (AdminTextKeys.scheduleNoActiveTitle, AdminTextKeys.scheduleNoActiveText),
      _ => (AdminTextKeys.scheduleNoMatchTitle, AdminTextKeys.scheduleNoMatchMessage),
    };
    return JitanNoResults(title: context.t(title), message: context.t(message));
  }

}
