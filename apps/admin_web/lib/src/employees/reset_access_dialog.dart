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
    await showJitanModal<bool>(
      context,
      builder: (_) => ResetAccessDialog(employeesApi: employeesApi, employee: employee),
    ) ??
    false;

/// Figma "Reset access?" (`1534:520`): asked first, in plain words. The
/// reset signs the employee out everywhere and clears the password, so they
/// set a new one with the recovery QR shown next; the Terminal QR stays.
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
    final employee = widget.employee;
    final fullName = [employee.firstName, employee.lastName].whereType<String>().join(' ');
    final name = employee.firstName ?? (fullName.isEmpty ? employee.code : fullName);
    final failure = _failure;
    return JitanModal(
      width: 440,
      title: context.t(AdminTextKeys.employeeResetAccessTitle, args: {'name': name}),
      subtitle: context.t(AdminTextKeys.employeeResetAccessSubtitle, args: {'name': name}),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(color: JitanColors.tableHeader, borderRadius: BorderRadius.circular(14)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 10,
                children: [
                  for (final key in const [
                    AdminTextKeys.employeeResetAccessEffectSessions,
                    AdminTextKeys.employeeResetAccessEffectRecovery,
                    AdminTextKeys.employeeResetAccessEffectQr,
                  ])
                    Text('•  ${context.t(key, args: {'name': name})}', style: JitanTextStyles.tableCell),
                ],
              ),
            ),
          ),
          if (failure != null) ...[
            const SizedBox(height: 16),
            _failureMessage(context, failure),
          ],
        ],
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
              label: context.t(AdminTextKeys.employeeResetAccessConfirm),
              color: JitanColors.errorStrong,
              busy: _busy,
              onPressed: _reset,
            ),
          ],
        ),
      ],
    );
  }

  Widget _failureMessage(BuildContext context, ApiClientException failure) {
    if (failure.error?.code == ApiErrorCode.accountNotActivated) {
      return JitanInlineError(
        title: context.t(AdminTextKeys.employeeResetAccessRefused),
        message: context.t(AdminTextKeys.employeeResetAccessNotActivated),
      );
    }
    final keys = failureTextKeysFor(failure);
    return JitanInlineError(title: context.t(keys.title), message: context.t(keys.message));
  }
}
