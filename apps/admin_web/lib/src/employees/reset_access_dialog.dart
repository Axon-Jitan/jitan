import 'package:flutter/material.dart';
import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:jitan_core/jitan_core.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../common/api_failure_text.dart';
import '../l10n/admin_text_keys.dart';

/// Asks HR/Admin to confirm "Reset account access" for [employee] and runs
/// it. Returns `true` once the server confirmed the reset.
Future<bool> showResetAccessDialog(
  BuildContext context, {
  required EmployeesApi employeesApi,
  required EmployeeDetails employee,
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (_) => ResetAccessDialog(employeesApi: employeesApi, employee: employee),
    ) ??
    false;

/// Confirmation for "Reset account access" (V1 HR/Admin-assisted recovery).
/// No Figma frame yet; built from the modal pattern (DESIGN-CLARIFY-AUTH).
///
/// The reset clears the employee's password: every device is signed out and
/// their existing Jitan QR sets up a new password. HR/Admin must have
/// verified the employee first; the text says so.
class ResetAccessDialog extends StatefulWidget {
  const ResetAccessDialog({super.key, required this.employeesApi, required this.employee});

  final EmployeesApi employeesApi;
  final EmployeeDetails employee;

  @override
  State<ResetAccessDialog> createState() => _ResetAccessDialogState();
}

class _ResetAccessDialogState extends State<ResetAccessDialog> {
  bool _busy = false;
  ApiClientException? _failure;

  String get _name {
    final name = [widget.employee.firstName, widget.employee.lastName].whereType<String>().join(' ');
    return name.isEmpty ? widget.employee.code : name;
  }

  Future<void> _reset() async {
    setState(() {
      _busy = true;
      _failure = null;
    });
    try {
      await widget.employeesApi.resetAccess(widget.employee.companyId, widget.employee.id);
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
    final failure = _failure;
    return JitanModal(
      title: context.t(AdminTextKeys.employeeResetAccessTitle),
      subtitle: context.t(
        AdminTextKeys.employeeDetailsSubtitle,
        args: {'company': widget.employee.companyName, 'code': widget.employee.code},
      ),
      width: 520,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.t(AdminTextKeys.employeeResetAccessMessage, args: {'name': _name}),
            style: JitanTextStyles.stateMessage.copyWith(fontSize: 12, color: JitanColors.ink),
          ),
          const SizedBox(height: 12),
          Text(
            context.t(AdminTextKeys.employeeResetAccessVerify, args: {'name': _name}),
            style: JitanTextStyles.tableCellStrong.copyWith(color: JitanColors.warning),
          ),
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
        JitanPrimaryButton(
          label: context.t(AdminTextKeys.employeeResetAccessConfirm),
          busy: _busy,
          onPressed: _reset,
        ),
      ],
    );
  }

  Widget _failureMessage(BuildContext context, ApiClientException failure) {
    if (failure.error?.code == ApiErrorCode.accountNotActivated) {
      return JitanInlineError(
        title: context.t(AdminTextKeys.employeeResetAccessTitle),
        message: context.t(AdminTextKeys.employeeResetAccessNotActivated),
      );
    }
    final keys = failureTextKeysFor(failure);
    return JitanInlineError(title: context.t(keys.title), message: context.t(keys.message));
  }
}
