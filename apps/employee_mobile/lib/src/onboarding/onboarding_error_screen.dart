import 'package:flutter/material.dart';
import 'package:jitan_core/jitan_core.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../l10n/employee_text_keys.dart';
import '../widgets/phone_widgets.dart';
import 'onboarding_controller.dart';
import 'onboarding_step_page.dart';

/// When onboarding can't go on (Figma `1591:294`, `1591:316`, `1591:335`):
/// a small icon, the title, one sentence and a quiet line of help, then what
/// to do. "Sign in" opens sign-in.
class OnboardingErrorScreen extends StatelessWidget {
  const OnboardingErrorScreen({
    super.key,
    required this.controller,
    required this.onSignIn,
  });

  final OnboardingController controller;
  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) {
    final problem = controller.problem ?? OnboardingProblem.serverUnavailable;
    void retry() => controller.retry();
    void back() => controller.back();
    final (tone, title, text, help, actionKey, onAction, withBack) = switch (problem) {
      OnboardingProblem.invalidQr => (
        OnboardingTone.error,
        EmployeeTextKeys.errorInvalidQrTitle,
        EmployeeTextKeys.errorInvalidQrText,
        EmployeeTextKeys.errorInvalidQrHelp,
        EmployeeTextKeys.errorScanAgain,
        retry,
        true,
      ),
      OnboardingProblem.qrExpired => (
        OnboardingTone.error,
        EmployeeTextKeys.errorQrExpiredTitle,
        EmployeeTextKeys.errorQrExpiredText,
        EmployeeTextKeys.errorQrExpiredHelp,
        EmployeeTextKeys.errorScanAgain,
        retry,
        true,
      ),
      OnboardingProblem.wrongQr => (
        OnboardingTone.warning,
        EmployeeTextKeys.errorWrongQrTitle,
        EmployeeTextKeys.errorWrongQrText,
        EmployeeTextKeys.errorWrongQrHelp,
        EmployeeTextKeys.errorScanAgain,
        retry,
        true,
      ),
      OnboardingProblem.alreadyActivated => (
        OnboardingTone.warning,
        EmployeeTextKeys.errorAlreadyActivatedTitle,
        EmployeeTextKeys.errorAlreadyActivatedText,
        EmployeeTextKeys.errorAlreadyActivatedHelp,
        EmployeeTextKeys.errorSignIn,
        onSignIn,
        false,
      ),
      OnboardingProblem.accountUnavailable => (
        OnboardingTone.error,
        EmployeeTextKeys.errorUnavailableTitle,
        EmployeeTextKeys.errorUnavailableText,
        EmployeeTextKeys.errorUnavailableHelp,
        CommonTextKeys.back,
        back,
        false,
      ),
      OnboardingProblem.activatedElsewhere => (
        OnboardingTone.warning,
        EmployeeTextKeys.errorActivatedElsewhereTitle,
        EmployeeTextKeys.errorActivatedElsewhereText,
        EmployeeTextKeys.errorActivatedElsewhereHelp,
        EmployeeTextKeys.errorSignIn,
        onSignIn,
        true,
      ),
      OnboardingProblem.networkFailure => (
        OnboardingTone.retry,
        EmployeeTextKeys.errorNetworkTitle,
        EmployeeTextKeys.errorNetworkText,
        EmployeeTextKeys.errorNetworkHelp,
        CommonTextKeys.retry,
        retry,
        true,
      ),
      OnboardingProblem.serverUnavailable => (
        OnboardingTone.retry,
        EmployeeTextKeys.errorServerTitle,
        EmployeeTextKeys.errorServerText,
        EmployeeTextKeys.errorServerHelp,
        CommonTextKeys.retry,
        retry,
        true,
      ),
      OnboardingProblem.sessionRecovery => (
        OnboardingTone.retry,
        EmployeeTextKeys.errorSessionRecoveryTitle,
        EmployeeTextKeys.errorSessionRecoveryText,
        EmployeeTextKeys.errorSessionRecoveryHelp,
        EmployeeTextKeys.errorSessionRecoveryAction,
        retry,
        true,
      ),
    };
    final busy = controller.busy;
    return OnboardingStepPage(
      showBack: true,
      onBack: busy ? null : back,
      above: Padding(padding: const EdgeInsets.only(top: 14, bottom: 10), child: OnboardingStatusIcon(tone: tone)),
      title: context.t(title),
      subtitle: context.t(text),
      contentGap: 12,
      action: JitanMobileButton(
        label: context.t(actionKey),
        busy: busy,
        onPressed: onAction,
        size: JitanMobileButtonSize.phone,
      ),
      link: withBack ? PhoneQuietLink(label: context.t(CommonTextKeys.back), onPressed: busy ? null : back) : null,
      children: [Text(context.t(help), style: JitanMobileTextStyles.detail)],
    );
  }
}
