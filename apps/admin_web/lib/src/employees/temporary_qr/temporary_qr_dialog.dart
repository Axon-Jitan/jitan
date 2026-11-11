import 'package:flutter/material.dart';
import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../../l10n/admin_text_keys.dart';
import 'temporary_qr_controller.dart';
import 'temporary_qr_panel.dart';

/// Opens the temporary QR modal of [purpose] for [employee] and generates a
/// QR straight away: `true` when it closed because the employee finished
/// with it (they have a password now).
Future<bool> showTemporaryQrDialog(
  BuildContext context, {
  required EmployeesApi employeesApi,
  required EmployeeDetails employee,
  required TemporaryQrPurpose purpose,
  DateTime Function()? clock,
  Duration watchEvery = TemporaryQrController.defaultWatchEvery,
}) async =>
    await showJitanModal<bool>(
      context,
      builder: (_) => TemporaryQrDialog(
        employeesApi: employeesApi,
        employee: employee,
        purpose: purpose,
        clock: clock,
        watchEvery: watchEvery,
      ),
    ) ??
    false;

/// Figma "Onboarding QR" (`1532:181`), "Recovery QR" (`1532:772`) and, once
/// the countdown ends, the same pop-up expired (`1532:1363`). HR and Admin
/// use the same modal.
///
/// The QR is generated on demand, valid 10 minutes, single use; "Make a new
/// QR" replaces it (the previous one stops working). It is never stored in
/// MySQL and never shown as text. Once expired the code is no longer drawn.
/// The modal closes by itself when the employee has finished with it.
class TemporaryQrDialog extends StatefulWidget {
  const TemporaryQrDialog({
    super.key,
    required this.employeesApi,
    required this.employee,
    required this.purpose,
    this.clock,
    this.watchEvery = TemporaryQrController.defaultWatchEvery,
  });

  final EmployeesApi employeesApi;
  final EmployeeDetails employee;
  final TemporaryQrPurpose purpose;
  final DateTime Function()? clock;
  final Duration watchEvery;

  @override
  State<TemporaryQrDialog> createState() => _TemporaryQrDialogState();
}

class _TemporaryQrDialogState extends State<TemporaryQrDialog> {
  late final _controller = TemporaryQrController(
    api: widget.employeesApi,
    companyId: widget.employee.companyId,
    userId: widget.employee.id,
    purpose: widget.purpose,
    clock: widget.clock,
    watchEvery: widget.watchEvery,
  )..addListener(_closeWhenUsed);

  bool get _recovery => widget.purpose == TemporaryQrPurpose.recovery;

  void _closeWhenUsed() {
    if (_controller.used && mounted) Navigator.of(context).pop(true);
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_closeWhenUsed)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final employee = widget.employee;
    final fullName = [employee.firstName, employee.lastName].whereType<String>().join(' ');
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) => JitanModal(
        width: 460,
        title: context.t(_recovery ? AdminTextKeys.temporaryQrRecoveryTitle : AdminTextKeys.temporaryQrOnboardingTitle),
        subtitle: context.t(
          AdminTextKeys.employeeQrSubtitle,
          args: {'name': fullName.isEmpty ? employee.code : fullName, 'company': employee.companyName},
        ),
        body: TemporaryQrPanel(
          controller: _controller,
          fullName: fullName,
          callName: employee.firstName ?? (fullName.isEmpty ? employee.code : fullName),
        ),
        leadingActions: TemporaryQrPanel.leadingActions(context, _controller),
        actions: TemporaryQrPanel.actions(context, _controller, onDone: () => Navigator.of(context).pop()),
      ),
    );
  }
}
