import 'package:flutter/material.dart';
import 'package:jitan_core/jitan_core.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../l10n/employee_text_keys.dart';
import 'onboarding_controller.dart';
import 'widgets/onboarding_widgets.dart';

/// The Figma "Onboarding Error / 01 … 07" screens.
///
/// "Sign in" (02, 04) and "Contact HR/Admin" (02) are not shown yet: sign-in
/// with employee code + password is AUTH-01, and the ERD holds no HR contact
/// details. "Back" returns to scanning.
class OnboardingErrorScreen extends StatelessWidget {
  const OnboardingErrorScreen({super.key, required this.controller});

  final OnboardingController controller;

  @override
  Widget build(BuildContext context) {
    final problem = controller.problem ?? OnboardingProblem.serverUnavailable;
    final content = _contentFor(problem);
    final (surface, strong, icon) = switch (content.tone) {
      _Tone.error => (JitanColors.errorSurface, JitanColors.errorStrong, Icons.priority_high_rounded),
      _Tone.warning => (JitanColors.warningSurface, JitanColors.warning, Icons.priority_high_rounded),
      _Tone.info => (JitanColors.infoSurface, JitanColors.info, Icons.refresh_rounded),
    };
    return Scaffold(
      backgroundColor: JitanColors.warmWhite,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(OnboardingPage.margin, 14, OnboardingPage.margin, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(header: true, child: Text(context.t(content.title), style: JitanMobileTextStyles.errorTitle)),
              const SizedBox(height: 10),
              Text(context.t(content.text), style: JitanMobileTextStyles.caption),
              const SizedBox(height: 92),
              Center(child: StatusCircle(background: surface, foreground: strong, icon: icon)),
              const SizedBox(height: 28),
              Semantics(
                liveRegion: true,
                child: NoteBox(
                  title: context.t(content.helpTitle),
                  text: context.t(content.help),
                  background: surface,
                  foreground: strong,
                  radius: 18,
                  minHeight: 120,
                ),
              ),
              const SizedBox(height: 34),
              if (content.retry != null) ...[
                JitanMobileButton(
                  label: context.t(content.retry!),
                  style: JitanMobileButtonStyle.brand,
                  size: JitanMobileButtonSize.compact,
                  busy: controller.busy,
                  onPressed: controller.retry,
                ),
                const SizedBox(height: 12),
              ],
              JitanMobileButton(
                label: context.t(CommonTextKeys.back),
                style: JitanMobileButtonStyle.secondary,
                size: JitanMobileButtonSize.compact,
                onPressed: controller.busy ? null : controller.back,
              ),
            ],
          ),
        ),
      ),
    );
  }

  static _ErrorContent _contentFor(OnboardingProblem problem) => switch (problem) {
    OnboardingProblem.invalidQr => const _ErrorContent(
      _Tone.error,
      EmployeeTextKeys.errorInvalidQrTitle,
      EmployeeTextKeys.errorInvalidQrText,
      EmployeeTextKeys.errorInvalidQrHelpTitle,
      EmployeeTextKeys.errorInvalidQrHelp,
      retry: CommonTextKeys.retry,
    ),
    OnboardingProblem.alreadyActivated => const _ErrorContent(
      _Tone.warning,
      EmployeeTextKeys.errorAlreadyActivatedTitle,
      EmployeeTextKeys.errorAlreadyActivatedText,
      EmployeeTextKeys.errorAlreadyActivatedHelpTitle,
      EmployeeTextKeys.errorAlreadyActivatedHelp,
    ),
    OnboardingProblem.accountUnavailable => const _ErrorContent(
      _Tone.error,
      EmployeeTextKeys.errorUnavailableTitle,
      EmployeeTextKeys.errorUnavailableText,
      EmployeeTextKeys.errorUnavailableHelpTitle,
      EmployeeTextKeys.errorUnavailableHelp,
    ),
    OnboardingProblem.activatedElsewhere => const _ErrorContent(
      _Tone.warning,
      EmployeeTextKeys.errorActivatedElsewhereTitle,
      EmployeeTextKeys.errorActivatedElsewhereText,
      EmployeeTextKeys.errorActivatedElsewhereHelpTitle,
      EmployeeTextKeys.errorActivatedElsewhereHelp,
    ),
    OnboardingProblem.networkFailure => const _ErrorContent(
      _Tone.info,
      EmployeeTextKeys.errorNetworkTitle,
      EmployeeTextKeys.errorNetworkText,
      EmployeeTextKeys.errorNetworkHelpTitle,
      EmployeeTextKeys.errorNetworkHelp,
      retry: CommonTextKeys.retry,
    ),
    OnboardingProblem.serverUnavailable => const _ErrorContent(
      _Tone.error,
      EmployeeTextKeys.errorServerTitle,
      EmployeeTextKeys.errorServerText,
      EmployeeTextKeys.errorServerHelpTitle,
      EmployeeTextKeys.errorServerHelp,
      retry: CommonTextKeys.retry,
    ),
    OnboardingProblem.sessionRecovery => const _ErrorContent(
      _Tone.info,
      EmployeeTextKeys.errorSessionRecoveryTitle,
      EmployeeTextKeys.errorSessionRecoveryText,
      EmployeeTextKeys.errorSessionRecoveryHelpTitle,
      EmployeeTextKeys.errorSessionRecoveryHelp,
      retry: EmployeeTextKeys.errorSessionRecoveryAction,
    ),
  };
}

enum _Tone { error, warning, info }

class _ErrorContent {
  const _ErrorContent(this.tone, this.title, this.text, this.helpTitle, this.help, {this.retry});

  final _Tone tone;
  final String title;
  final String text;
  final String helpTitle;
  final String help;

  /// Key of the main action's label; `null` = only "Back".
  final String? retry;
}
