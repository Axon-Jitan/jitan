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

/// Figma "Temporary onboarding QR" (`153:1214`, expired `207:123`) and
/// "Temporary password recovery QR" (`207:111`). HR and Admin use the same
/// modal.
///
/// The QR is generated on demand, valid 10 minutes, single use; "Generate
/// new QR" replaces it (the previous one stops working). It is never stored
/// in MySQL and never shown as text. When the countdown ends the code is
/// hidden and the status turns to "EXPIRED".
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
        final expired = _controller.isExpired;
        final expiry = expired
            ? context.t(AdminTextKeys.temporaryQrExpiredShort)
            : context.t(AdminTextKeys.temporaryQrExpiresIn, args: {'time': _clockText(_controller.remaining)});
        final generateLabel = context.t(AdminTextKeys.temporaryQrGenerateNew);
        final onGenerate = _controller.generating ? null : _controller.generate;
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
                  if (expired)
                    _ExpiredCode(size: _recovery ? 270 : 320)
                  else
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
                      label: expired
                          ? context.t(AdminTextKeys.temporaryQrExpiredStatus)
                          : context.t(
                              AdminTextKeys.temporaryQrValidStatus,
                              args: {'minutes': '${(_controller.lifetime ?? Duration.zero).inMinutes.clamp(1, 60)}'},
                            ),
                      warning: expired,
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

/// Where the code was, once it expired: the code itself is no longer drawn.
class _ExpiredCode extends StatelessWidget {
  const _ExpiredCode({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(color: JitanColors.inputFill, borderRadius: BorderRadius.circular(16)),
    alignment: Alignment.center,
    child: Text(
      context.t(AdminTextKeys.temporaryQrExpiredStatus),
      style: JitanTextStyles.stateTitle.copyWith(fontSize: 16, color: JitanColors.warning),
    ),
  );
}
