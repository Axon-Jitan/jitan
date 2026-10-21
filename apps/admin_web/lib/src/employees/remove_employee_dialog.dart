import 'package:flutter/material.dart';
import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:jitan_core/jitan_core.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../common/api_failure_text.dart';
import '../l10n/admin_text_keys.dart';

/// Asks HR/Admin to confirm "Remove employee" for [employee] (in
/// [companyId]) and runs it. Returns `true` once the server confirmed.
Future<bool> showRemoveEmployeeDialog(
  BuildContext context, {
  required EmployeesApi employeesApi,
  required EmployeeSummary employee,
  required int companyId,
}) async =>
    await showJitanModal<bool>(
      context,
      builder: (_) => RemoveEmployeeDialog(employeesApi: employeesApi, employee: employee, companyId: companyId),
    ) ??
    false;

/// Figma `HR / Employees — Remove employee` (238:3853): the employee is
/// hidden from the interface and kept in the database (`userMFD = 1`).
/// Nothing is shown as removed before the server confirms.
class RemoveEmployeeDialog extends StatefulWidget {
  const RemoveEmployeeDialog({super.key, required this.employeesApi, required this.employee, required this.companyId});

  final EmployeesApi employeesApi;
  final EmployeeSummary employee;
  final int companyId;

  @override
  State<RemoveEmployeeDialog> createState() => _RemoveEmployeeDialogState();
}

class _RemoveEmployeeDialogState extends State<RemoveEmployeeDialog> {
  bool _busy = false;
  ApiClientException? _failure;

  Future<void> _remove() async {
    setState(() {
      _busy = true;
      _failure = null;
    });
    try {
      await widget.employeesApi.remove(widget.companyId, widget.employee.id);
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
    final name = [employee.firstName, employee.lastName].whereType<String>().join(' ');
    final failure = _failure;
    return JitanModal(
      width: 460,
      title: context.t(AdminTextKeys.employeeRemoveTitle),
      onClose: _busy ? null : () => Navigator.of(context).pop(false),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.t(AdminTextKeys.employeeRemoveQuestion, args: {'name': name.isEmpty ? employee.code : name}),
            style: JitanTextStyles.stateMessage.copyWith(fontSize: 14, color: JitanColors.ink),
          ),
          const SizedBox(height: 14),
          Text(context.t(AdminTextKeys.employeeRemoveEffect), style: JitanTextStyles.stateMessage.copyWith(fontSize: 13)),
          if (failure != null) ...[
            const SizedBox(height: 16),
            _failureMessage(context, failure),
          ],
        ],
      ),
      actions: [
        JitanSecondaryButton(
          label: context.t(CommonTextKeys.cancel),
          onPressed: _busy ? null : () => Navigator.of(context).pop(false),
        ),
        JitanPrimaryButton(label: context.t(AdminTextKeys.employeeRemoveConfirm), busy: _busy, onPressed: _remove),
      ],
    );
  }

  Widget _failureMessage(BuildContext context, ApiClientException failure) {
    final keys = failureTextKeysFor(failure);
    return JitanInlineError(title: context.t(keys.title), message: context.t(keys.message));
  }
}
