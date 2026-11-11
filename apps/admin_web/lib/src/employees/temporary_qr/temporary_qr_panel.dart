import 'package:flutter/material.dart';
import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:jitan_core/jitan_core.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../../common/api_failure_text.dart';
import '../../l10n/admin_text_keys.dart';
import 'temporary_qr_controller.dart';

/// The QR of a temporary QR (Figma `1532:181`, also Add employee step 3,
/// `1536:569`): the code in a plain card, one instruction, and "Works once ·
/// Expires in 09:57". Expired, the code is no longer drawn. The value is
/// never shown as text.
class TemporaryQrPanel extends StatelessWidget {
  const TemporaryQrPanel({
    super.key,
    required this.controller,
    required this.fullName,
    required this.callName,
    this.size = 232,
  });

  final TemporaryQrController controller;

  /// For screen readers.
  final String fullName;

  /// The name the instruction uses ("Ask Lars to scan it…").
  final String callName;
  final double size;

  bool get _recovery => controller.purpose == TemporaryQrPurpose.recovery;

  static String _clockText(Duration d) =>
      '${d.inMinutes.toString().padLeft(2, '0')}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      final expired = controller.isExpired;
      return switch ((controller.qr, controller.failure)) {
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
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: expired
                      ? SizedBox.square(dimension: size)
                      : JitanQrCode(
                          data: qr.qrCode,
                          size: size,
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
                  : context.t(AdminTextKeys.temporaryQrFacts, args: {'time': _clockText(controller.remaining)}),
              textAlign: TextAlign.center,
              style: JitanTextStyles.tableCell.copyWith(fontSize: 13, color: JitanColors.inkMuted),
            ),
          ],
        ),
        _ => SizedBox(height: size + 128, child: JitanLoadingState(label: context.t(AdminTextKeys.temporaryQrLoading))),
      };
    },
  );

  /// "Make a new QR", quiet on the left while the code is good.
  static List<Widget> leadingActions(BuildContext context, TemporaryQrController controller) => [
    if (!controller.isExpired)
      TextButton(
        onPressed: controller.generating ? null : controller.generate,
        style: TextButton.styleFrom(foregroundColor: JitanColors.ink, padding: const EdgeInsets.symmetric(horizontal: 4)),
        child: Text(context.t(AdminTextKeys.temporaryQrMakeNew), style: JitanTextStyles.tableCellStrong),
      ),
  ];

  /// Done on the right; expired, Close and a primary Make a new QR.
  static List<Widget> actions(BuildContext context, TemporaryQrController controller, {required VoidCallback onDone}) => [
    if (controller.isExpired)
      Wrap(
        alignment: WrapAlignment.end,
        spacing: 12,
        runSpacing: 10,
        children: [
          JitanSecondaryButton(label: context.t(AdminTextKeys.temporaryQrClose), onPressed: onDone),
          JitanPrimaryButton(
            label: context.t(AdminTextKeys.temporaryQrMakeNew),
            busy: controller.generating,
            onPressed: controller.generating ? null : controller.generate,
          ),
        ],
      )
    else
      JitanSecondaryButton(label: context.t(AdminTextKeys.temporaryQrDone), onPressed: onDone),
  ];

  Widget _error(BuildContext context, ApiClientException failure) {
    final keys = failureTextKeysFor(failure);
    return SizedBox(
      height: size + 88,
      child: JitanErrorState(
        title: context.t(keys.title),
        message: context.t(keys.message),
        retryLabel: context.t(CommonTextKeys.retry),
        onRetry: controller.generate,
      ),
    );
  }
}
