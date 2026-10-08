import 'package:flutter/material.dart';
import 'package:jitan_core/jitan_core.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../l10n/employee_text_keys.dart';
import '../widgets/mobile_widgets.dart';
import '../widgets/qr_camera_frame.dart';
import 'onboarding_controller.dart';
import 'qr_scanner_view.dart';

/// Figma "Onboarding / 02B Scan temporary QR" (`211:2`): the camera scanner.
/// A read QR is verified by the server while the frame shows progress; the
/// result is "QR verified" (03B) or an Onboarding Error screen.
class ScanScreen extends StatelessWidget {
  const ScanScreen({super.key, required this.controller, required this.scannerView});

  final OnboardingController controller;
  final QrScannerView scannerView;

  @override
  Widget build(BuildContext context) => BrandedScaffold(
    children: [
      BrandedHeader(title: context.t(EmployeeTextKeys.scanTitle), text: context.t(EmployeeTextKeys.scanText)),
      const SizedBox(height: 56),
      QrCameraFrame(
        scannerView: scannerView,
        onDetected: controller.submitQr,
        busy: controller.busy,
        hint: context.t(EmployeeTextKeys.scanFrameHint),
      ),
      const SizedBox(height: 26),
      NoteBox(
        title: context.t(EmployeeTextKeys.scanGuidanceTitle),
        text: context.t(EmployeeTextKeys.scanGuidanceText),
        background: JitanColors.inputFill,
        foreground: JitanColors.warning,
        textStyle: JitanMobileTextStyles.noteText.copyWith(fontSize: 9),
        minHeight: 94,
      ),
      const SizedBox(height: 32),
      JitanMobileButton(
        label: context.t(CommonTextKeys.back),
        style: JitanMobileButtonStyle.secondary,
        size: JitanMobileButtonSize.compact,
        onPressed: controller.busy ? null : controller.back,
      ),
    ],
  );
}

/// Figma "Onboarding / 03B QR verified and connected" (`212:2`).
class QrVerifiedScreen extends StatelessWidget {
  const QrVerifiedScreen({super.key, required this.controller});

  final OnboardingController controller;

  @override
  Widget build(BuildContext context) => OnboardingPage(
    actions: [
      JitanMobileButton(label: context.t(EmployeeTextKeys.verifiedAction), onPressed: controller.continueToAccount),
    ],
    children: [
      const SizedBox(height: 36),
      Text(
        context.t(EmployeeTextKeys.verifiedEyebrow),
        style: JitanMobileTextStyles.noteTitle.copyWith(color: JitanColors.success, fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 22),
      Semantics(
        header: true,
        child: Text(context.t(EmployeeTextKeys.verifiedTitle), style: JitanMobileTextStyles.display.copyWith(fontSize: 30)),
      ),
      const SizedBox(height: 14),
      Text(context.t(EmployeeTextKeys.verifiedText), style: JitanMobileTextStyles.body.copyWith(fontSize: 13)),
      const SizedBox(height: 50),
      Container(
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: 268),
        decoration: BoxDecoration(color: JitanColors.successSurface, borderRadius: BorderRadius.circular(20)),
        padding: const EdgeInsets.fromLTRB(16, 25, 16, 16),
        child: Column(
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: const BoxDecoration(color: JitanColors.success, shape: BoxShape.circle),
              child: const Icon(Icons.check_rounded, size: 46, color: JitanColors.surface),
            ),
            const SizedBox(height: 27),
            Text(
              context.t(EmployeeTextKeys.verifiedPanelTitle),
              textAlign: TextAlign.center,
              style: JitanMobileTextStyles.formTitle.copyWith(fontSize: 18),
            ),
            const SizedBox(height: 14),
            Text(
              context.t(EmployeeTextKeys.verifiedPanelText),
              textAlign: TextAlign.center,
              style: JitanMobileTextStyles.caption,
            ),
            const SizedBox(height: 22),
            Text(
              context.t(EmployeeTextKeys.verifiedPanelNext),
              textAlign: TextAlign.center,
              style: JitanMobileTextStyles.caption.copyWith(fontSize: 11),
            ),
          ],
        ),
      ),
      const SizedBox(height: 22),
      NoteBox(
        title: context.t(EmployeeTextKeys.verifiedNoteTitle),
        text: context.t(EmployeeTextKeys.verifiedNoteText),
        background: JitanColors.surface,
        border: JitanColors.inputBorder,
        textStyle: JitanMobileTextStyles.noteText.copyWith(fontSize: 10),
        radius: 13,
        minHeight: 75,
      ),
    ],
  );
}
