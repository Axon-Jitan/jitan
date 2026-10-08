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

/// Figma "Admin / Employees — Reset account access modal" (`196:242`, `207:97`).
///
/// The reset signs the employee out everywhere, clears the password hash,
/// lets them recover with a temporary recovery QR, and keeps their
/// Terminal QR unchanged.
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
    final name = [employee.firstName, employee.lastName].whereType<String>().join(' ');
    final failure = _failure;
    final effectStyle = JitanTextStyles.stateMessage.copyWith(fontSize: 10, color: JitanColors.errorStrong);
    return JitanModal(
      title: context.t(AdminTextKeys.employeeResetAccessTitle),
      subtitle: context.t(AdminTextKeys.employeeResetAccessSubtitle),
      width: 640,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 28),
          // Employee summary
          Container(
            constraints: const BoxConstraints(minHeight: 84),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: JitanColors.inputFill, borderRadius: BorderRadius.circular(14)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name.isEmpty ? employee.code : name, style: JitanTextStyles.stateTitle),
                const SizedBox(height: 8),
                Text(
                  context.t(
                    AdminTextKeys.employeeDetailsSubtitle,
                    args: {'company': employee.companyName, 'code': employee.code},
                  ),
                  style: JitanTextStyles.stateMessage.copyWith(fontSize: 10),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          // Reset effects
          Container(
            constraints: const BoxConstraints(minHeight: 150),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: JitanColors.errorSurface, borderRadius: BorderRadius.circular(14)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.t(AdminTextKeys.employeeResetAccessEffectsTitle),
                  style: JitanTextStyles.stateTitle.copyWith(fontSize: 11, color: JitanColors.errorStrong),
                ),
                const SizedBox(height: 10),
                for (final key in const [
                  AdminTextKeys.employeeResetAccessEffectSessions,
                  AdminTextKeys.employeeResetAccessEffectPassword,
                  AdminTextKeys.employeeResetAccessEffectRecovery,
                  AdminTextKeys.employeeResetAccessEffectQr,
                ])
                  Text(context.t(key), style: effectStyle),
                const SizedBox(height: 14),
                // Figma 207:225: the next step after the reset.
                Text(
                  context.t(AdminTextKeys.employeeResetAccessNextStep),
                  style: JitanTextStyles.tableCellStrong.copyWith(fontSize: 10, color: JitanColors.errorStrong),
                ),
              ],
            ),
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
          color: JitanColors.errorStrong,
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
