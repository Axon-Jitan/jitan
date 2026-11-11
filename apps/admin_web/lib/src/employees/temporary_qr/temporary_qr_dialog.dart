import 'package:flutter/material.dart';
import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:jitan_core/jitan_core.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../../common/api_failure_text.dart';
import '../../l10n/admin_text_keys.dart';
import 'temporary_qr_controller.dart';

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

  /// The size the code is drawn at (Figma: 232 inside a 28 px padded card).
  static const _qrSize = 232.0;

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

  static String _clockText(Duration d) =>
      '${d.inMinutes.toString().padLeft(2, '0')}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final employee = widget.employee;
    final fullName = [employee.firstName, employee.lastName].whereType<String>().join(' ');
    final callName = employee.firstName ?? (fullName.isEmpty ? employee.code : fullName);
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final qr = _controller.qr;
        final failure = _controller.failure;
        final expired = _controller.isExpired;
        final newQr = context.t(AdminTextKeys.temporaryQrMakeNew);
        final onNewQr = _controller.generating ? null : _controller.generate;
        return JitanModal(
          width: 460,
          title: context.t(_recovery ? AdminTextKeys.temporaryQrRecoveryTitle : AdminTextKeys.temporaryQrOnboardingTitle),
          subtitle: context.t(
            AdminTextKeys.employeeQrSubtitle,
            args: {'name': fullName.isEmpty ? employee.code : fullName, 'company': employee.companyName},
          ),
          body: switch ((qr, failure)) {
            (_, final failure?) => _error(context, failure),
            (final qr?, _) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: JitanColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: JitanColors.cardBorder),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: Center(
                      child: expired
                          // Once expired the code is no longer drawn.
                          ? const SizedBox.square(dimension: _qrSize)
                          : JitanQrCode(
                              data: qr.qrCode,
                              size: _qrSize,
                              framed: false,
                              semanticLabel: context.t(AdminTextKeys.temporaryQrSemantics, args: {'name': fullName}),
                            ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  expired
                      ? context.t(AdminTextKeys.temporaryQrExpired)
                      : context.t(
                          _recovery ? AdminTextKeys.temporaryQrRecoveryInstruction : AdminTextKeys.temporaryQrOnboardingInstruction,
                          args: {'name': callName},
                        ),
                  textAlign: TextAlign.center,
                  style: JitanTextStyles.tableCellStrong.copyWith(fontSize: 15),
                ),
                const SizedBox(height: 6),
                Text(
                  expired
                      ? context.t(AdminTextKeys.temporaryQrExpiredText)
                      : context.t(AdminTextKeys.temporaryQrFacts, args: {'time': _clockText(_controller.remaining)}),
                  textAlign: TextAlign.center,
                  style: JitanTextStyles.tableCell.copyWith(fontSize: 13, color: JitanColors.inkMuted),
                ),
              ],
            ),
            _ => SizedBox(height: 360, child: JitanLoadingState(label: context.t(AdminTextKeys.temporaryQrLoading))),
          },
          leadingActions: [
            if (!expired)
              TextButton(
                onPressed: onNewQr,
                style: TextButton.styleFrom(foregroundColor: JitanColors.ink, padding: const EdgeInsets.symmetric(horizontal: 4)),
                child: Text(newQr, style: JitanTextStyles.tableCellStrong),
              ),
          ],
          actions: [
            if (expired)
              Row(
                mainAxisSize: MainAxisSize.min,
                spacing: 12,
                children: [
                  JitanSecondaryButton(label: context.t(AdminTextKeys.temporaryQrClose), onPressed: () => Navigator.of(context).pop()),
                  JitanPrimaryButton(label: newQr, busy: _controller.generating, onPressed: onNewQr),
                ],
              )
            else
              JitanSecondaryButton(label: context.t(AdminTextKeys.temporaryQrDone), onPressed: () => Navigator.of(context).pop()),
          ],
        );
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
        onRetry: _controller.generate,
      ),
    );
  }
}
