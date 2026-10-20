import 'package:flutter/material.dart';
import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:jitan_core/jitan_core.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../common/api_failure_text.dart';
import '../l10n/admin_text_keys.dart';
import 'deactivate_schedule_dialog.dart';
import 'schedule_dialog.dart';
import 'schedule_rows.dart';
import 'schedules_controller.dart';
import 'schedules_table.dart';

/// HR/Admin "Schedules" page (Figma `HR / Schedules — Saved confirmation`
/// 1318:198, `Empty list` 1320:173, `Loading list` 1320:300, `List error`
/// 1320:427).
///
/// Schedules are global, not company-scoped. Differences from Figma, on
/// purpose: there are no "Rounding" or "Short exit" rows (rounding is part
/// of a group's work hours; short exit is not in the ERD), every row names
/// its group (no "All"), and Status is Active or "Different hours" (a
/// switched-off schedule is no longer listed).
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

  Future<void> _open({GroupSchedule? group, ScheduleKind? kind}) async {
    final saved = await showScheduleDialog(context, api: widget.api, groups: _groups, group: group, kind: kind);
    if (saved == null || !mounted) return;
    await _controller.load();
    if (!mounted) return;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(content: Text(context.t(AdminTextKeys.scheduleSaved, args: {'group': saved.group.name}))),
    );
  }

  Future<void> _onAction(ScheduleRow row, ScheduleRowAction action) async {
    switch (action) {
      case ScheduleRowAction.edit:
        await _open(group: row.schedule, kind: row.kind);
      case ScheduleRowAction.deactivate:
        final done = await showDeactivateScheduleDialog(context, controller: _controller, row: row);
        if (!done || !mounted) return;
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(content: Text(context.t(AdminTextKeys.scheduleDeactivated, args: {'group': row.group.name}))),
        );
    }
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsetsDirectional.fromSTEB(
      JitanDimensions.pagePaddingStart,
      JitanDimensions.pagePaddingVertical,
      JitanDimensions.pagePaddingEnd,
      JitanDimensions.pagePaddingVertical,
    ),
    child: ListenableBuilder(
      listenable: _controller,
      builder: (context, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: JitanPageHeader(
                  title: context.t(AdminTextKeys.scheduleTitle),
                  subtitle: context.t(AdminTextKeys.scheduleListSubtitle),
                ),
              ),
              const SizedBox(width: 16),
              JitanPrimaryButton(
                label: context.t(AdminTextKeys.scheduleAddAction),
                icon: Icons.add,
                height: JitanDimensions.controlHeight,
                onPressed: _controller.state is SchedulesLoaded ? _open : null,
              ),
            ],
          ),
          const SizedBox(height: JitanDimensions.headerToToolbar),
          _toolbar(context),
          const SizedBox(height: JitanDimensions.toolbarToTable),
          Text(context.t(AdminTextKeys.scheduleListHeading), style: JitanTextStyles.stateTitle.copyWith(fontSize: 17)),
          const SizedBox(height: JitanDimensions.toolbarToTable),
          JitanSurfaceCard(
            radius: JitanDimensions.tableCardRadius,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: JitanDimensions.tableMinHeight),
              child: _content(context),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _toolbar(BuildContext context) {
    final filter = _controller.filter;
    void update(ScheduleFilter next) => _controller.updateFilter(next);
    final groups = {for (final row in _controller.allRows) row.group.id: row.group.name};
    return Wrap(
      spacing: 14,
      runSpacing: 14,
      crossAxisAlignment: WrapCrossAlignment.end,
      children: [
        SizedBox(
          width: 420,
          child: JitanFieldLabel(
            label: context.t(AdminTextKeys.scheduleSearchLabel),
            child: JitanSearchField(
              hintText: context.t(AdminTextKeys.scheduleSearch),
              onChanged: (text) => update(
                ScheduleFilter(search: text.trim(), kind: filter.kind, groupId: filter.groupId, status: filter.status),
              ),
            ),
          ),
        ),
        SizedBox(
          width: 150,
          child: JitanSelectField<ScheduleKind?>(
            label: context.t(AdminTextKeys.scheduleFilterType),
            value: filter.kind,
            options: [
              JitanSelectOption(value: null, label: context.t(AdminTextKeys.scheduleFilterTypeAll)),
              JitanSelectOption(value: ScheduleKind.workHours, label: context.t(AdminTextKeys.scheduleKindWorkHours)),
              JitanSelectOption(value: ScheduleKind.breaks, label: context.t(AdminTextKeys.scheduleKindBreaks)),
            ],
            onChanged: (kind) => update(
              ScheduleFilter(search: filter.search, kind: kind, groupId: filter.groupId, status: filter.status),
            ),
          ),
        ),
        SizedBox(
          width: 150,
          child: JitanSelectField<int?>(
            label: context.t(AdminTextKeys.scheduleFilterGroup),
            value: filter.groupId,
            options: [
              JitanSelectOption(value: null, label: context.t(AdminTextKeys.scheduleFilterGroupAll)),
              for (final MapEntry(:key, :value) in groups.entries) JitanSelectOption(value: key, label: value),
            ],
            onChanged: (id) => update(
              ScheduleFilter(search: filter.search, kind: filter.kind, groupId: id, status: filter.status),
            ),
          ),
        ),
        SizedBox(
          width: 250,
          child: JitanSelectField<ScheduleRowStatus?>(
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
            onChanged: (status) => update(
              ScheduleFilter(search: filter.search, kind: filter.kind, groupId: filter.groupId, status: status),
            ),
          ),
        ),
      ],
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
      final rows => SchedulesTable(rows: rows, onAction: _onAction),
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

  static Widget _centered(Widget child) => SizedBox(height: JitanDimensions.tableMinHeight, child: child);
}
