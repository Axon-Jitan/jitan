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
class EmployeesTable extends StatelessWidget {
  const EmployeesTable({super.key, required this.employees, required this.onManage});

  final List<EmployeeSummary> employees;

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

  @override
  Widget build(BuildContext context) {
    final t = TranslationScope.of(context);
    return JitanDataTable(
      maxHeight: JitanDimensions.tableMaxHeight,
      columns: [
        JitanTableColumn(label: t.t(AdminTextKeys.employeeColumnName), flex: _flexName),
        JitanTableColumn(label: t.t(AdminTextKeys.employeeColumnCode), flex: _flexCode),
        JitanTableColumn(label: t.t(AdminTextKeys.employeeColumnType), flex: _flexType),
        JitanTableColumn(label: t.t(AdminTextKeys.employeeColumnLocation), flex: _flexLocation),
        JitanTableColumn(label: t.t(AdminTextKeys.employeeColumnSchedule), flex: _flexSchedule),
        JitanTableColumn(label: t.t(AdminTextKeys.employeeColumnOnboarding), flex: _flexOnboarding),
        JitanTableColumn(label: t.t(AdminTextKeys.employeeColumnStatus), flex: _flexStatus),
        JitanTableColumn(label: t.t(AdminTextKeys.employeeColumnActions), flex: _flexActions, align: JitanColumnAlign.end),
      ],
      rows: [for (final employee in employees) _cells(t, employee)],
    );
  }

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
