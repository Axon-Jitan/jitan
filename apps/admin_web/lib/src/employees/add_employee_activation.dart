import 'package:flutter/material.dart';
import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../groups/group_state_text.dart';
import '../l10n/admin_text_keys.dart';

/// Add employee step 3, "Activate employee account" (Figma `1233:2`): who
/// the employee is, the three steps they follow, and their temporary
/// onboarding QR; while it is generated, or if that failed, one line takes
/// the card's place (`1399:747`, `1399:1368`). The QR is a credential:
/// shown only as a QR, never as text.
class AddEmployeeActivation extends StatelessWidget {
  const AddEmployeeActivation({
    super.key,
    required this.employee,
    required this.companyName,
    required this.qr,
    required this.failure,
    required this.onRetry,
  });

  final EmployeeSummary employee;
  final String companyName;
  final TemporaryQrResponse? qr;
  final ApiClientException? failure;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final name = [employee.firstName, employee.lastName].whereType<String>().join(' ');
    final details = [companyName, ...employee.groups].join(' · ');
    final info = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(context.t(AdminTextKeys.employeeAddActivationEmployee), style: JitanTextStyles.fieldLabel.copyWith(fontSize: 12)),
        const SizedBox(height: 10),
        Text(name, style: JitanTextStyles.stateTitle.copyWith(fontSize: 18)),
        const SizedBox(height: 4),
        Text(details, style: JitanTextStyles.stateMessage),
        const SizedBox(height: 14),
        const Divider(height: 1, color: JitanColors.inputBorder),
        const SizedBox(height: 20),
        for (final (index, key) in [
          AdminTextKeys.employeeAddActivationStep1,
          AdminTextKeys.employeeAddActivationStep2,
          AdminTextKeys.employeeAddActivationStep3,
        ].indexed) ...[
          Row(
            children: [
              Container(
                width: 22,
                height: 22,
                alignment: Alignment.center,
                decoration: const BoxDecoration(shape: BoxShape.circle, color: JitanColors.inputFill),
                child: Text('${index + 1}', style: JitanTextStyles.tableCell.copyWith(fontSize: 12)),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(context.t(key), style: JitanTextStyles.inputText)),
            ],
          ),
          const SizedBox(height: 16),
        ],
      ],
    );
    Widget card(TemporaryQrResponse qr) => Container(
      width: 276,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: JitanColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: JitanColors.inputBorder),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 160,
            child: JitanQrCode(data: qr.qrCode, size: 150, semanticLabel: context.t(AdminTextKeys.employeeAddActivationScan)),
          ),
          const SizedBox(height: 20),
          Text(context.t(AdminTextKeys.employeeAddActivationScan), style: JitanTextStyles.tableCellStrong),
          const SizedBox(height: 6),
          Text(context.t(AdminTextKeys.employeeAddActivationScanHint), style: JitanTextStyles.stateMessage.copyWith(fontSize: 13)),
        ],
      ),
    );
    // The card while there is a QR; otherwise one line in its place.
    final Widget qrArea = switch ((qr, failure)) {
      (_, final _?) => _line(GroupStateText(context.t(AdminTextKeys.employeeAddActivationFailed), onRetry: onRetry)),
      (final qr?, _) => card(qr),
      _ => _line(GroupStateText(context.t(AdminTextKeys.employeeAddActivationLoading))),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(context.t(AdminTextKeys.employeeAddActivationTitle), style: JitanTextStyles.stateTitle.copyWith(fontSize: 20)),
                  const SizedBox(height: 6),
                  Text(context.t(AdminTextKeys.employeeAddActivationSubtitle), style: JitanTextStyles.stateMessage),
                ],
              ),
            ),
            JitanStatusPill(label: context.t(AdminTextKeys.employeeAddActivationNotActivated), neutral: true),
          ],
        ),
        const SizedBox(height: 28),
        LayoutBuilder(
          builder: (context, constraints) => constraints.maxWidth < 600
              ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [info, const SizedBox(height: 8), Center(child: qrArea)])
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [Expanded(child: info), const SizedBox(width: 40), qrArea],
                ),
        ),
        const SizedBox(height: 16),
        Text(context.t(AdminTextKeys.employeeAddActivationNote), style: JitanTextStyles.stateMessage.copyWith(fontSize: 13)),
      ],
    );
  }

  /// A state line where the card would be, vertically centred like Figma.
  static Widget _line(Widget line) => SizedBox(width: 300, height: 240, child: Align(alignment: Alignment.centerLeft, child: line));
}
