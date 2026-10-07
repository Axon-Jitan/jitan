import 'package:flutter/material.dart';
import 'package:jitan_core/jitan_core.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../l10n/employee_text_keys.dart';
import '../widgets/mobile_widgets.dart';
import 'onboarding_controller.dart';

/// The Figma "Onboarding Error / 01 … 07" screens.
///
/// "Sign in" (02, 04) opens the sign-in flow; "Contact HR/Admin" (02) shows
/// the HR/Admin-assisted recovery guidance.
class OnboardingErrorScreen extends StatelessWidget {
  const OnboardingErrorScreen({
    super.key,
    required this.controller,
    required this.onSignIn,
    required this.onContactHr,
  });

  final OnboardingController controller;
  final VoidCallback onSignIn;
  final VoidCallback onContactHr;

  @override
  Widget build(BuildContext context) {
    final problem = controller.problem ?? OnboardingProblem.serverUnavailable;
    StatusAction primary(String key) =>
        StatusAction(label: context.t(key), primary: true, busy: controller.busy, onPressed: controller.retry);
    final back = StatusAction(label: context.t(CommonTextKeys.back), onPressed: controller.busy ? null : controller.back);
    final signIn = StatusAction(label: context.t(EmployeeTextKeys.errorSignIn), primary: true, onPressed: onSignIn);

    final (tone, title, text, helpTitle, help, actions) = switch (problem) {
      OnboardingProblem.invalidQr => (
        StatusTone.error,
        EmployeeTextKeys.errorInvalidQrTitle,
        EmployeeTextKeys.errorInvalidQrText,
        EmployeeTextKeys.errorInvalidQrHelpTitle,
        EmployeeTextKeys.errorInvalidQrHelp,
        [primary(CommonTextKeys.retry), back],
      ),
      OnboardingProblem.alreadyActivated => (
        StatusTone.warning,
        EmployeeTextKeys.errorAlreadyActivatedTitle,
        EmployeeTextKeys.errorAlreadyActivatedText,
        EmployeeTextKeys.errorAlreadyActivatedHelpTitle,
        EmployeeTextKeys.errorAlreadyActivatedHelp,
        [signIn, StatusAction(label: context.t(EmployeeTextKeys.errorContactHr), onPressed: onContactHr)],
      ),
      OnboardingProblem.accountUnavailable => (
        StatusTone.error,
        EmployeeTextKeys.errorUnavailableTitle,
        EmployeeTextKeys.errorUnavailableText,
        EmployeeTextKeys.errorUnavailableHelpTitle,
        EmployeeTextKeys.errorUnavailableHelp,
        [back],
      ),
      OnboardingProblem.activatedElsewhere => (
        StatusTone.warning,
        EmployeeTextKeys.errorActivatedElsewhereTitle,
        EmployeeTextKeys.errorActivatedElsewhereText,
        EmployeeTextKeys.errorActivatedElsewhereHelpTitle,
        EmployeeTextKeys.errorActivatedElsewhereHelp,
        [signIn, back],
      ),
      OnboardingProblem.networkFailure => (
        StatusTone.info,
        EmployeeTextKeys.errorNetworkTitle,
        EmployeeTextKeys.errorNetworkText,
        EmployeeTextKeys.errorNetworkHelpTitle,
        EmployeeTextKeys.errorNetworkHelp,
        [primary(CommonTextKeys.retry), back],
      ),
      OnboardingProblem.serverUnavailable => (
        StatusTone.error,
        EmployeeTextKeys.errorServerTitle,
        EmployeeTextKeys.errorServerText,
        EmployeeTextKeys.errorServerHelpTitle,
        EmployeeTextKeys.errorServerHelp,
        [primary(CommonTextKeys.retry), back],
      ),
      OnboardingProblem.sessionRecovery => (
        StatusTone.info,
        EmployeeTextKeys.errorSessionRecoveryTitle,
        EmployeeTextKeys.errorSessionRecoveryText,
        EmployeeTextKeys.errorSessionRecoveryHelpTitle,
        EmployeeTextKeys.errorSessionRecoveryHelp,
        [primary(EmployeeTextKeys.errorSessionRecoveryAction), back],
      ),
    };
    return StatusPage(
      tone: tone,
      title: context.t(title),
      text: context.t(text),
      helpTitle: context.t(helpTitle),
      help: context.t(help),
      actions: actions,
    );
  }
}
