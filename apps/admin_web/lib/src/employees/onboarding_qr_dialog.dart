import 'package:flutter/material.dart';
import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:jitan_core/jitan_core.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../common/api_failure_text.dart';
import '../l10n/admin_text_keys.dart';

/// Opens the Onboarding QR modal for [employee].
Future<void> showOnboardingQrDialog(
  BuildContext context, {
  required EmployeesApi employeesApi,
  required EmployeeDetails employee,
}) => showDialog<void>(
  context: context,
  builder: (_) => OnboardingQrDialog(employeesApi: employeesApi, employee: employee),
);

/// Figma `Admin / Employees — Onboarding QR modal` (`153:445`), EMP-08.
///
/// Shows `tblUser.userQRcode`: the QR the employee scans to onboard, which
/// stays their personal QR for Jitan Terminal afterwards (IT decision,
/// 2026-10-07). The value is only ever drawn as a QR, never shown as text or
/// logged.
class OnboardingQrDialog extends StatefulWidget {
  const OnboardingQrDialog({super.key, required this.employeesApi, required this.employee});

  final EmployeesApi employeesApi;
  final EmployeeDetails employee;

  @override
  State<OnboardingQrDialog> createState() => _OnboardingQrDialogState();
}

class _OnboardingQrDialogState extends State<OnboardingQrDialog> {
  /// Figma frame width of the QR modal.
  static const _modalWidth = 560.0;

  String? _qrCode;
  ApiClientException? _failure;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _qrCode = null;
      _failure = null;
    });
    try {
      final qrCode = await widget.employeesApi.onboardingQr(widget.employee.companyId, widget.employee.id);
      if (mounted) setState(() => _qrCode = qrCode);
    } on ApiClientException catch (failure) {
      if (mounted) setState(() => _failure = failure);
    }
  }

  @override
  Widget build(BuildContext context) {
    final employee = widget.employee;
    final fullName = [employee.firstName, employee.lastName].whereType<String>().join(' ');
    final callName = employee.firstName ?? fullName;
    return JitanModal(
      width: _modalWidth,
      title: context.t(AdminTextKeys.employeeQrTitle),
      subtitle: context.t(AdminTextKeys.employeeQrSubtitle, args: {'name': fullName, 'company': employee.companyName}),
      body: switch ((_qrCode, _failure)) {
        // Full width so the QR block is centred, as in Figma.
        (final qrCode?, _) => SizedBox(
          width: double.infinity,
          child: Column(
            children: [
              JitanQrCode(
                data: qrCode,
                semanticLabel: context.t(AdminTextKeys.employeeQrSemantics, args: {'name': fullName}),
              ),
              const SizedBox(height: 18),
              JitanStatusPill(label: context.t(AdminTextKeys.employeeQrReady)),
              const SizedBox(height: 14),
              Text(
                context.t(AdminTextKeys.employeeQrInstruction, args: {'name': callName}),
                style: JitanTextStyles.inputText.copyWith(fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        (_, final failure?) => _error(context, failure),
        _ => SizedBox(height: 320, child: JitanLoadingState(label: context.t(AdminTextKeys.employeeQrLoading))),
      },
    );
  }

  Widget _error(BuildContext context, ApiClientException failure) {
    final keys = failureTextKeysFor(failure);
    return SizedBox(
      height: 320,
      child: JitanErrorState(
        title: context.t(keys.title),
        message: context.t(keys.message),
        retryLabel: context.t(CommonTextKeys.retry),
        onRetry: _load,
      ),
    );
  }
}
