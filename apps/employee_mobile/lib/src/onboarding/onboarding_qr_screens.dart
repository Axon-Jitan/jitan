import 'package:flutter/material.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../l10n/employee_text_keys.dart';
import '../widgets/qr_camera_frame.dart';
import 'onboarding_controller.dart';
import '../widgets/phone_step_page.dart';
import 'qr_scanner_view.dart';

/// "Scan your setup QR" (Figma `1591:33`): the camera scanner. A read QR is
/// checked by the server while the frame shows progress; the result is
/// "Is this you?" or an error screen.
class ScanScreen extends StatelessWidget {
  const ScanScreen({super.key, required this.controller, required this.scannerView});

  final OnboardingController controller;
  final QrScannerView scannerView;

  @override
  Widget build(BuildContext context) => PhoneStepPage(
    showBack: true,
    onBack: controller.busy ? null : controller.back,
    title: context.t(EmployeeTextKeys.scanTitle),
    subtitle: context.t(EmployeeTextKeys.scanText),
    children: [
      QrCameraFrame(
        scannerView: scannerView,
        onDetected: controller.submitQr,
        busy: controller.busy,
        hint: context.t(EmployeeTextKeys.scanFrameHint),
      ),
      const SizedBox(height: 14),
      Text(
        context.t(EmployeeTextKeys.scanCameraNote),
        textAlign: TextAlign.center,
        style: JitanMobileTextStyles.detail,
      ),
    ],
  );
}
