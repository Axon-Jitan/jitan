import 'package:flutter/material.dart';
import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:jitan_core/jitan_core.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../../common/api_failure_text.dart';
import '../../l10n/admin_text_keys.dart';
import 'temporary_qr_controller.dart';

/// Opens the temporary QR modal of [purpose] for [employee] and generates a
/// QR straight away.
Future<void> showTemporaryQrDialog(
  BuildContext context, {
  required EmployeesApi employeesApi,
  required EmployeeDetails employee,
  required TemporaryQrPurpose purpose,
  DateTime Function()? clock,
}) => showDialog<void>(
  context: context,
  builder: (_) => TemporaryQrDialog(employeesApi: employeesApi, employee: employee, purpose: purpose, clock: clock),
);

/// Figma "Temporary onboarding QR" (`153:1214`), "Temporary password
/// recovery QR" (`207:111`) and, once the countdown ends, "Temporary QR
/// expired" (`207:215`). HR and Admin use the same modal.
///
/// The QR is generated on demand, valid 10 minutes, single use; "Generate
/// new QR" replaces it (the previous one stops working). It is never stored
/// in MySQL and never shown as text. When the countdown ends the code is no
/// longer drawn: the modal shows the expired dialog instead.
class TemporaryQrDialog extends StatefulWidget {
  const TemporaryQrDialog({
    super.key,
    required this.employeesApi,
    required this.employee,
    required this.purpose,
    this.clock,
  });

  final EmployeesApi employeesApi;
  final EmployeeDetails employee;
  final TemporaryQrPurpose purpose;
  final DateTime Function()? clock;

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
  );

  bool get _recovery => widget.purpose == TemporaryQrPurpose.recovery;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  static String _clockText(Duration d) =>
      '${d.inMinutes.toString().padLeft(2, '0')}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final employee = widget.employee;
    final fullName = [employee.firstName, employee.lastName].whereType<String>().join(' ');
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final qr = _controller.qr;
        final failure = _controller.failure;
        final expiry = context.t(AdminTextKeys.temporaryQrExpiresIn, args: {'time': _clockText(_controller.remaining)});
        final generateLabel = context.t(AdminTextKeys.temporaryQrGenerateNew);
        final onGenerate = _controller.generating ? null : _controller.generate;
        if (_controller.isExpired) return _expired(context, generateLabel, onGenerate);
        // Figma: red primary in the recovery dialog, warm grey in the onboarding modal.
        final generateNew = _recovery
            ? JitanPrimaryButton(label: generateLabel, busy: _controller.generating, onPressed: onGenerate)
            : JitanSecondaryButton(label: generateLabel, onPressed: onGenerate);
        return JitanModal(
          width: _recovery ? 620 : 560,
          title: context.t(_recovery ? AdminTextKeys.temporaryQrRecoveryTitle : AdminTextKeys.temporaryQrOnboardingTitle),
          subtitle: _recovery
              ? context.t(AdminTextKeys.temporaryQrRecoverySubtitle)
              : context.t(AdminTextKeys.employeeQrSubtitle, args: {'name': fullName, 'company': employee.companyName}),
          body: SizedBox(
            width: double.infinity,
            child: switch ((qr, failure)) {
              (_, final failure?) => _error(context, failure),
              (final qr?, _) => Column(
                children: [
                  JitanQrCode(
                      data: qr.qrCode,
                      size: _recovery ? 270 : 320,
                      semanticLabel: context.t(AdminTextKeys.temporaryQrSemantics, args: {'name': fullName}),
                    ),
                  const SizedBox(height: 18),
                  if (_recovery)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        context.t(AdminTextKeys.temporaryQrRecoveryFacts, args: {'expiry': expiry}),
                        style: JitanTextStyles.tableCellStrong.copyWith(fontSize: 11, color: JitanColors.warning),
                      ),
                    )
                  else ...[
                    JitanStatusPill(
                      label: context.t(
                        AdminTextKeys.temporaryQrValidStatus,
                        args: {'minutes': '${(_controller.lifetime ?? Duration.zero).inMinutes.clamp(1, 60)}'},
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      context.t(AdminTextKeys.temporaryQrOnboardingInstruction),
                      style: JitanTextStyles.inputText.copyWith(fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 18),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        context.t(AdminTextKeys.temporaryQrOnboardingFacts, args: {'expiry': expiry}),
                        style: JitanTextStyles.tableCellStrong.copyWith(fontSize: 10, color: JitanColors.inkMuted),
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  if (_recovery)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        context.t(AdminTextKeys.temporaryQrRecoveryNotTerminal),
                        style: JitanTextStyles.stateMessage.copyWith(fontSize: 10),
                      ),
                    )
                  else ...[
                    const SizedBox(height: 18),
                    generateNew,
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        context.t(AdminTextKeys.temporaryQrReplacementNote),
                        style: JitanTextStyles.stateMessage.copyWith(fontSize: 10),
                      ),
                    ),
                  ],
                ],
              ),
              _ => SizedBox(height: 320, child: JitanLoadingState(label: context.t(AdminTextKeys.temporaryQrLoading))),
            },
          ),
          onClose: _recovery ? null : () => Navigator.of(context).pop(),
          actions: [
            if (_recovery) ...[
              JitanSecondaryButton(label: context.t(AdminTextKeys.temporaryQrClose), onPressed: () => Navigator.of(context).pop()),
              generateNew,
            ],
          ],
        );
      },
    );
  }

  /// Figma "Temporary QR expired" (`207:215`).
  Widget _expired(BuildContext context, String generateLabel, VoidCallback? onGenerate) => JitanModal(
    width: 620,
    title: context.t(AdminTextKeys.temporaryQrExpiredTitle),
    subtitle: context.t(AdminTextKeys.temporaryQrExpiredText),
    body: Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 120),
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
      decoration: BoxDecoration(color: JitanColors.errorSurface, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.t(AdminTextKeys.temporaryQrExpiredStatusTitle),
            style: JitanTextStyles.stateTitle.copyWith(fontSize: 15, color: JitanColors.errorStrong),
          ),
          const SizedBox(height: 16),
          Text(
            context.t(AdminTextKeys.temporaryQrExpiredStatusText),
            style: JitanTextStyles.stateMessage.copyWith(fontSize: 11, color: JitanColors.errorStrong),
          ),
        ],
      ),
    ),
    actions: [
      JitanSecondaryButton(label: context.t(CommonTextKeys.cancel), onPressed: () => Navigator.of(context).pop()),
      JitanPrimaryButton(label: generateLabel, busy: _controller.generating, onPressed: onGenerate),
    ],
  );

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
