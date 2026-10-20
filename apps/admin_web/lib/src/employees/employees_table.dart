import 'package:flutter/material.dart';
import 'package:jitan_core/jitan_core.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../l10n/admin_text_keys.dart';

/// The employees table from Figma `Admin / Employees` (`153:165`).
///
/// Differences from Figma, on purpose:
/// - **Policy** is omitted (PRODUCT-CLARIFY-EMPLOYEE-POLICY).
/// - **Location** (ERD GAP-11) has no data source yet and shows a placeholder.
/// - **Onboarding** has two states, Activated / Not activated
///   (`userPassword IS NOT NULL`). Figma's "QR generated" is not tracked.
/// - **Type** lists every group of the employee; none is singled out.
class EmployeesTable extends StatelessWidget {
  const EmployeesTable({super.key, required this.employees, this.onOpen});

  final List<EmployeeSummary> employees;

  /// Opens an employee's details (row click).
  final ValueChanged<EmployeeSummary>? onOpen;

  /// Column widths proportional to the Figma table without its Policy column.
  static const _flexName = 260;
  static const _flexCode = 110;
  static const _flexType = 145;
  static const _flexLocation = 145;
  static const _flexOnboarding = 180;
  static const _flexStatus = 120;

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
        JitanTableColumn(label: t.t(AdminTextKeys.employeeColumnOnboarding), flex: _flexOnboarding),
        JitanTableColumn(label: t.t(AdminTextKeys.employeeColumnStatus), flex: _flexStatus),
      ],
      rows: [for (final employee in employees) _cells(t, employee)],
      onRowTap: onOpen == null ? null : (index) => onOpen!(employees[index]),
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
