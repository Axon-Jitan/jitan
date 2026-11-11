import 'package:flutter/material.dart';
import 'package:jitan_core/jitan_core.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../l10n/admin_text_keys.dart';
import '../schedules/schedule_summary_text.dart';
import 'employee_standing.dart';

/// The employees table (Figma `1531:2`): employee, code, type, schedule and
/// one status (Active, Not set up, Inactive). A row opens the employee
/// (`1531:259`); an inactive one is greyed.
///
/// - **Type** lists every group of the employee; none is singled out.
/// - **Schedule** shows the employee's hours ("Mon–Fri 08:00–16:30"):
///   schedules have no names (ERD_GAPS GAP-14).
/// - **Location** is left out: the ERD has no employee location (GAP-11).
class EmployeesTable extends StatelessWidget {
  const EmployeesTable({super.key, required this.employees, required this.onOpen});

  final List<EmployeeSummary> employees;
  final ValueChanged<EmployeeSummary> onOpen;

  /// Column widths proportional to Figma (300/140/200/240/200).
  static const _flexName = 300;
  static const _flexCode = 140;
  static const _flexType = 200;
  static const _flexSchedule = 240;
  static const _flexStatus = 200;

  @override
  Widget build(BuildContext context) {
    final t = TranslationScope.of(context);
    return JitanSliverTable(
      onRowTap: (i) => onOpen(employees[i]),
      hoverChevron: true,
      columns: [
        JitanTableColumn(label: t.t(AdminTextKeys.employeeColumnName), flex: _flexName),
        JitanTableColumn(label: t.t(AdminTextKeys.employeeColumnCode), flex: _flexCode),
        JitanTableColumn(label: t.t(AdminTextKeys.employeeColumnType), flex: _flexType),
        JitanTableColumn(label: t.t(AdminTextKeys.employeeColumnSchedule), flex: _flexSchedule),
        JitanTableColumn(label: t.t(AdminTextKeys.employeeColumnStatus), flex: _flexStatus),
      ],
      rowCount: employees.length,
      cells: (i) => _cells(context, t, employees[i]),
    );
  }

  List<Widget> _cells(BuildContext context, Translations t, EmployeeSummary employee) {
    final unavailable = t.t(CommonTextKeys.valueUnavailable);
    final standing = EmployeeStanding.ofSummary(employee);
    final faded = standing == EmployeeStanding.inactive;
    final ink = faded ? JitanColors.disabledText : JitanColors.ink;
    return [
      Text(
        _displayName(employee) ?? unavailable,
        style: JitanTextStyles.tableCellStrong.copyWith(color: ink),
        overflow: TextOverflow.ellipsis,
      ),
      Text(employee.code, style: JitanTextStyles.tableCell.copyWith(color: ink), overflow: TextOverflow.ellipsis),
      Text(
        employee.groups.isEmpty ? unavailable : employee.groups.join(', '),
        style: JitanTextStyles.tableCell.copyWith(color: ink),
        overflow: TextOverflow.ellipsis,
      ),
      Text(
        switch (employee.schedule) {
          final schedule? when schedule.workDays.isNotEmpty => workHoursDaysSummary(t, schedule),
          _ => unavailable,
        },
        style: JitanTextStyles.tableCell.copyWith(color: ink),
        overflow: TextOverflow.ellipsis,
      ),
      JitanStatusLabel(label: standing.label(context), isPositive: false, color: standing.color),
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
