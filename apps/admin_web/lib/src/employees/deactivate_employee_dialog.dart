import 'package:flutter/material.dart';
import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:jitan_core/jitan_core.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../common/api_failure_text.dart';
import '../l10n/admin_text_keys.dart';

/// Asks HR/Admin to confirm Deactivate for [employee] (through [companyId])
/// and runs it. Returns `true` once the server confirmed.
Future<bool> showDeactivateEmployeeDialog(
  BuildContext context, {
  required EmployeesApi employeesApi,
  required EmployeeSummary employee,
  required int companyId,
}) async =>
    await showJitanModal<bool>(
      context,
      builder: (_) => DeactivateEmployeeDialog(employeesApi: employeesApi, employee: employee, companyId: companyId),
    ) ??
    false;

/// Figma "Deactivate?" (`1534:366`): the employee can no longer sign in or
/// register time, in any company; time records stay and Reactivate undoes
/// it. Nothing shows as deactivated before the server confirms.
class DeactivateEmployeeDialog extends StatefulWidget {
  const DeactivateEmployeeDialog({super.key, required this.employeesApi, required this.employee, required this.companyId});

  final EmployeesApi employeesApi;
  final EmployeeSummary employee;
  final int companyId;

  @override
  State<DeactivateEmployeeDialog> createState() => _DeactivateEmployeeDialogState();
}

class _DeactivateEmployeeDialogState extends State<DeactivateEmployeeDialog> {
  bool _busy = false;
  ApiClientException? _failure;

  Future<void> _deactivate() async {
    setState(() {
      _busy = true;
      _failure = null;
    });
    try {
      await widget.employeesApi.deactivate(widget.companyId, widget.employee.id);
      if (mounted) Navigator.of(context).pop(true);
    } on ApiClientException catch (failure) {
      if (mounted) {
        setState(() {
          _busy = false;
          _failure = failure;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final employee = widget.employee;
    final fullName = [employee.firstName, employee.lastName].whereType<String>().join(' ');
    final name = employee.firstName ?? (fullName.isEmpty ? employee.code : fullName);
    final failure = _failure;
    return JitanModal(
      width: 440,
      title: context.t(AdminTextKeys.employeeDeactivateTitle, args: {'name': fullName.isEmpty ? employee.code : fullName}),
      subtitle: context.t(AdminTextKeys.employeeDeactivateText, args: {'name': name}),
      body: failure == null
          ? const SizedBox.shrink()
          : JitanInlineError(
              title: context.t(failureTextKeysFor(failure).title),
              message: context.t(failureTextKeysFor(failure).message),
            ),
      actions: [
        // Side by side; stacked when a phone has no room.
        Wrap(
          alignment: WrapAlignment.end,
          spacing: 12,
          runSpacing: 10,
          children: [
            JitanSecondaryButton(
              label: context.t(CommonTextKeys.cancel),
              onPressed: _busy ? null : () => Navigator.of(context).pop(false),
            ),
            JitanPrimaryButton(
              label: context.t(AdminTextKeys.employeeDeactivate),
              color: JitanColors.errorStrong,
              busy: _busy,
              onPressed: _deactivate,
            ),
          ],
        ),
      ],
    );
  }
}
