import 'package:flutter/material.dart';

import 'onboarding_controller.dart';
import 'onboarding_error_screen.dart';
import 'onboarding_qr_screens.dart';
import 'onboarding_screens.dart';
import 'qr_scanner_view.dart';

/// Shows the screen for the controller's current step. The system back
/// gesture goes to the previous step; on the first screen it leaves the app.
class OnboardingFlow extends StatelessWidget {
  const OnboardingFlow({
    super.key,
    required this.controller,
    required this.qrScannerView,
    required this.onFinished,
    required this.onSignIn,
  });

  final OnboardingController controller;
  /// The embedded camera of 02B.
  final QrScannerView qrScannerView;

  /// Already activated: open sign-in (Welcome link, error screens 02 and 04).
  final VoidCallback onSignIn;

  /// "Start Jitan" on the Ready screen: the device is already signed in.
  final VoidCallback onFinished;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      final atStart = controller.step == OnboardingStep.welcome || controller.step == OnboardingStep.ready;
      return PopScope(
        canPop: atStart,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) controller.back();
        },
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: KeyedSubtree(
            key: ValueKey(controller.step),
            child: switch (controller.step) {
              OnboardingStep.welcome => WelcomeScreen(controller: controller, onSignIn: onSignIn),
              OnboardingStep.join => JoinScreen(controller: controller, onScan: controller.openScanner),
              OnboardingStep.scan => ScanScreen(controller: controller, scannerView: qrScannerView),
              OnboardingStep.verified => QrVerifiedScreen(controller: controller),
              OnboardingStep.confirm => ConfirmScreen(controller: controller),
              OnboardingStep.language => LanguageScreen(controller: controller),
              OnboardingStep.method => MethodScreen(controller: controller),
              OnboardingStep.permissions => PermissionsScreen(controller: controller),
              OnboardingStep.password => PasswordScreen(controller: controller),
              OnboardingStep.ready => ReadyScreen(controller: controller, onStart: onFinished),
              OnboardingStep.error => OnboardingErrorScreen(
                controller: controller,
                onSignIn: onSignIn,
              ),
            },
          ),
        ),
      );
    },
  );
}
