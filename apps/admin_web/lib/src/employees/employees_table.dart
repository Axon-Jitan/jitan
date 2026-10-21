import 'package:flutter/material.dart';
import 'package:jitan_core/jitan_core.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../l10n/admin_text_keys.dart';
import '../schedules/schedule_summary_text.dart';

/// The employees table from Figma `HR / Employees — Company switcher open`
/// (`1401:2`): employee, code, type, location, schedule, onboarding, status
/// and "⋯" (Manage employee, `1399:10`).
///
/// Differences from Figma, on purpose:
/// - **Policy** is omitted (PRODUCT-CLARIFY-EMPLOYEE-POLICY).
/// - **Location** (ERD GAP-11) has no data source yet and shows a placeholder.
/// - **Onboarding** has two states, Activated / Not activated
///   (`userPassword IS NOT NULL`). Figma's "QR generated" is not tracked.
/// - **Type** lists every group of the employee; none is singled out.
/// - **Schedule** shows the employee's hours ("Mon–Fri 08:00–16:30"):
///   schedules have no names (ERD_GAPS GAP-14).
///
/// A row click opens nothing in V1 (product owner, 2026-10-21: details from
/// a row come in V2; BACKLOG EMP-DETAILS-V2).
///
/// A sliver: the page scrolls once, the heading row stays in view while its
/// rows pass (pinned), and rows are built only as they come into view. Below
/// [_minWidth] it is one card that scrolls sideways instead. Under it, the
/// results footer (Figma `1399:10`: "4 employees displayed", "Showing 4 of
/// 124").
class EmployeesTable extends StatelessWidget {
  const EmployeesTable({super.key, required this.employees, required this.total, required this.onManage});

  final List<EmployeeSummary> employees;

  /// Employees before the Status filter, for "Showing … of [total]".
  final int total;

  /// The row's "⋯".
  final ValueChanged<EmployeeSummary> onManage;

  /// Column widths proportional to Figma 1401:2 (x = 52/287/397/537/678/812/986/1092).
  static const _flexName = 235;
  static const _flexCode = 110;
  static const _flexType = 140;
  static const _flexLocation = 141;
  static const _flexSchedule = 134;
  static const _flexOnboarding = 174;
  static const _flexStatus = 106;
  static const _flexActions = 80;

  /// Narrower than this, the columns would squash: the table scrolls sideways.
  static const _minWidth = 760.0;
  static const _radius = Radius.circular(JitanDimensions.tableCardRadius);

  @override
  Widget build(BuildContext context) {
    final t = TranslationScope.of(context);
    final columns = _columns(t);
    final footer = _footer(context);
    return SliverLayoutBuilder(
      builder: (context, constraints) {
        if (constraints.crossAxisExtent < _minWidth) {
          return SliverToBoxAdapter(
            child: JitanSurfaceCard(
              radius: JitanDimensions.tableCardRadius,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  JitanDataTable(columns: columns, rows: [for (final employee in employees) _cells(t, employee)]),
                  footer,
                ],
              ),
            ),
          );
        }
        return SliverMainAxisGroup(
          slivers: [
            SliverPersistentHeader(pinned: true, delegate: _PinnedHeading(columns)),
            SliverList.builder(
              itemCount: employees.length,
              itemBuilder: (context, i) => ColoredBox(
                color: i.isOdd ? JitanColors.tableStripe : JitanColors.surface,
                child: JitanTableRow(columns: columns, cells: _cells(t, employees[i])),
              ),
            ),
            SliverToBoxAdapter(
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  color: JitanColors.surface,
                  borderRadius: BorderRadius.only(bottomLeft: _radius, bottomRight: _radius),
                ),
                child: footer,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _footer(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(
      JitanDimensions.tableHorizontalPadding,
      16,
      JitanDimensions.tableHorizontalPadding,
      18,
    ),
    child: Wrap(
      alignment: WrapAlignment.spaceBetween,
      spacing: 16,
      runSpacing: 6,
      children: [
        Text(
          context.tPlural(AdminTextKeys.employeeResultsDisplayed, employees.length),
          style: JitanTextStyles.stateMessage.copyWith(fontSize: 13),
        ),
        Text(
          context.t(AdminTextKeys.employeeResultsShowing, args: {'shown': employees.length, 'total': total}),
          style: JitanTextStyles.stateMessage.copyWith(fontSize: 13),
        ),
      ],
    ),
  );

  List<JitanTableColumn> _columns(Translations t) => [
    JitanTableColumn(label: t.t(AdminTextKeys.employeeColumnName), flex: _flexName),
    JitanTableColumn(label: t.t(AdminTextKeys.employeeColumnCode), flex: _flexCode),
    JitanTableColumn(label: t.t(AdminTextKeys.employeeColumnType), flex: _flexType),
    JitanTableColumn(label: t.t(AdminTextKeys.employeeColumnLocation), flex: _flexLocation),
    JitanTableColumn(label: t.t(AdminTextKeys.employeeColumnSchedule), flex: _flexSchedule),
    JitanTableColumn(label: t.t(AdminTextKeys.employeeColumnOnboarding), flex: _flexOnboarding),
    JitanTableColumn(label: t.t(AdminTextKeys.employeeColumnStatus), flex: _flexStatus),
    JitanTableColumn(label: t.t(AdminTextKeys.employeeColumnActions), flex: _flexActions, align: JitanColumnAlign.end),
  ];

  List<Widget> _cells(Translations t, EmployeeSummary employee) {
    final unavailable = t.t(CommonTextKeys.valueUnavailable);
    return [
      Text(
        _displayName(employee) ?? unavailable,
        style: JitanTextStyles.tableCellStrong,
        overflow: TextOverflow.ellipsis,
      ),
      Text(employee.code, style: JitanTextStyles.tableCell, overflow: TextOverflow.ellipsis),
      Text(
        employee.groups.isEmpty ? unavailable : employee.groups.join(', '),
        style: JitanTextStyles.tableCell,
        overflow: TextOverflow.ellipsis,
      ),
      Tooltip(
        message: t.t(AdminTextKeys.employeeLocationUnavailable),
        child: Text(unavailable, style: JitanTextStyles.tableCell),
      ),
      Text(
        switch (employee.schedule) {
          final schedule? when schedule.workDays.isNotEmpty => workHoursDaysSummary(t, schedule),
          _ => unavailable,
        },
        style: JitanTextStyles.tableCell,
        overflow: TextOverflow.ellipsis,
      ),
      JitanStatusLabel(
        label: t.t(
          employee.isActivated
              ? AdminTextKeys.employeeOnboardingActivated
              : AdminTextKeys.employeeOnboardingNotActivated,
        ),
        isPositive: employee.isActivated,
      ),
      JitanStatusLabel(
        label: t.t(employee.isActive ? CommonTextKeys.statusActive : CommonTextKeys.statusInactive),
        isPositive: employee.isActive,
      ),
      JitanRowActionsButton(tooltip: t.t(AdminTextKeys.employeeActionsMenu), onPressed: () => onManage(employee)),
    ];
  }

  /// "First Last" from whichever parts exist; `null` when neither does.
  static String? _displayName(EmployeeSummary employee) {
    final parts = [
      employee.firstName,
      employee.lastName,
    ].whereType<String>().map((part) => part.trim()).where((part) => part.isNotEmpty);
    return parts.isEmpty ? null : parts.join(' ');
  }
}

/// The table's heading row as a pinned sliver header, drawn as the top of
/// the table card.
class _PinnedHeading extends SliverPersistentHeaderDelegate {
  const _PinnedHeading(this.columns);

  final List<JitanTableColumn> columns;

  @override
  double get minExtent => JitanDimensions.tableHeaderHeight;

  @override
  double get maxExtent => JitanDimensions.tableHeaderHeight;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) => DecoratedBox(
    // A soft shadow while rows pass beneath it.
    decoration: BoxDecoration(
      borderRadius: const BorderRadius.only(topLeft: EmployeesTable._radius, topRight: EmployeesTable._radius),
      boxShadow: [
        if (overlapsContent || shrinkOffset > 0)
          BoxShadow(color: JitanColors.ink.withValues(alpha: 0.08), blurRadius: 10, offset: const Offset(0, 3)),
      ],
    ),
    child: ClipRRect(
      borderRadius: const BorderRadius.only(topLeft: EmployeesTable._radius, topRight: EmployeesTable._radius),
      child: JitanTableHeaderRow(columns: columns),
    ),
  );

  @override
  bool shouldRebuild(_PinnedHeading old) =>
      old.columns.map((c) => c.label).join() != columns.map((c) => c.label).join();
}
