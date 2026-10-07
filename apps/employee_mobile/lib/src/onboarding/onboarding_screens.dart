import 'package:flutter/material.dart';
import 'package:jitan_core/jitan_core.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../device/device_settings.dart';
import '../l10n/employee_text_keys.dart';
import 'onboarding_controller.dart';
import 'widgets/onboarding_widgets.dart';

// Vertical spacing below is measured from the 390 × 844 Figma frames
// ("Onboarding / 01 … 08").

/// 01 Welcome.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key, required this.controller});

  final OnboardingController controller;

  @override
  Widget build(BuildContext context) => OnboardingPage(
    logoStyle: JitanMobileTextStyles.logo.copyWith(fontSize: 24),
    actions: [JitanMobileButton(label: context.t(EmployeeTextKeys.welcomeAction), onPressed: controller.getStarted)],
    children: [
      const SizedBox(height: 105),
      Text(context.t(EmployeeTextKeys.welcomeEyebrow), style: JitanMobileTextStyles.eyebrow),
      const SizedBox(height: 20),
      Semantics(header: true, child: Text(context.t(EmployeeTextKeys.welcomeTitle), style: JitanMobileTextStyles.display)),
      const SizedBox(height: 47),
      Text(context.t(EmployeeTextKeys.welcomeText), style: JitanMobileTextStyles.body),
      const SizedBox(height: 50),
      const OnboardingIllustration(
        asset: 'assets/illustrations/welcome.png',
        widthFactor: 1.0633,
        heightFactor: 1.1061,
        left: -0.0348,
        top: -0.0478,
      ),
    ],
  );
}

/// 02 Join workplace: opens the scanner.
class JoinScreen extends StatelessWidget {
  const JoinScreen({super.key, required this.controller, required this.onScan});

  final OnboardingController controller;

  /// Opens the camera; the scanned value goes to [OnboardingController.submitQr].
  final VoidCallback onScan;

  @override
  Widget build(BuildContext context) => OnboardingPage(
    actions: [
      JitanMobileButton(
        label: context.t(EmployeeTextKeys.joinAction),
        busy: controller.busy,
        onPressed: onScan,
      ),
    ],
    children: [
      const SizedBox(height: 65),
      Semantics(header: true, child: Text(context.t(EmployeeTextKeys.joinTitle), style: JitanMobileTextStyles.display)),
      const SizedBox(height: 17),
      Text(context.t(EmployeeTextKeys.joinText), style: JitanMobileTextStyles.body),
      const SizedBox(height: 44),
      const OnboardingIllustration(
        asset: 'assets/illustrations/join_workplace.png',
        widthFactor: 1.0469,
        heightFactor: 1.0837,
        left: -0.0266,
        top: -0.0359,
      ),
      const SizedBox(height: 24),
      SizedBox(
        width: double.infinity,
        child: Text(
          context.t(EmployeeTextKeys.joinHint),
          style: JitanMobileTextStyles.caption,
          textAlign: TextAlign.center,
        ),
      ),
    ],
  );
}

/// 04 Account found: "Is this you?"
class ConfirmScreen extends StatelessWidget {
  const ConfirmScreen({super.key, required this.controller});

  final OnboardingController controller;

  @override
  Widget build(BuildContext context) {
    final account = controller.account;
    final name = [account?.firstName, account?.lastName].whereType<String>().where((n) => n.isNotEmpty).join(' ');
    final displayName = name.isEmpty ? (account?.code ?? '') : name;
    final details = [...?account?.companies, ?account?.code].join('  ·  ');
    return OnboardingPage(
      actions: [
        JitanMobileButton(label: context.t(EmployeeTextKeys.confirmAction), onPressed: controller.confirmAccount),
        const SizedBox(height: 4),
        Center(
          child: TextButton(
            onPressed: controller.rejectAccount,
            style: TextButton.styleFrom(foregroundColor: JitanColors.inkMuted),
            child: Text(
              '${context.t(EmployeeTextKeys.confirmNotYou)}  ${context.t(EmployeeTextKeys.confirmGoBack)}',
              style: JitanMobileTextStyles.link,
            ),
          ),
        ),
      ],
      children: [
        const SizedBox(height: 45),
        Semantics(header: true, child: Text(context.t(EmployeeTextKeys.confirmTitle), style: JitanMobileTextStyles.title)),
        const SizedBox(height: 43),
        Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 174),
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          decoration: BoxDecoration(color: JitanColors.surface, borderRadius: BorderRadius.circular(22)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 32,
                    backgroundColor: JitanColors.ink,
                    child: Text(
                      displayName.isEmpty ? '' : displayName.characters.first.toUpperCase(),
                      style: JitanMobileTextStyles.identityName.copyWith(fontSize: 24, color: JitanColors.warmWhite),
                    ),
                  ),
                  const SizedBox(width: 18),
                  Expanded(child: Text(displayName, style: JitanMobileTextStyles.identityName)),
                ],
              ),
              const SizedBox(height: 32),
              Text(details, style: JitanMobileTextStyles.identityDetail),
            ],
          ),
        ),
      ],
    );
  }
}

/// Language choice. No Figma frame yet: built like "05 Registration method"
/// (DESIGN-CLARIFY-ONBOARDING-LANGUAGE).
class LanguageScreen extends StatelessWidget {
  const LanguageScreen({super.key, required this.controller});

  final OnboardingController controller;

  @override
  Widget build(BuildContext context) => OnboardingPage(
    actions: [
      JitanMobileButton(label: context.t(CommonTextKeys.continueAction), onPressed: controller.confirmLanguage),
    ],
    children: [
      const SizedBox(height: 45),
      Semantics(header: true, child: Text(context.t(EmployeeTextKeys.languageTitle), style: JitanMobileTextStyles.title)),
      const SizedBox(height: 11),
      Text(context.t(EmployeeTextKeys.languageText), style: JitanMobileTextStyles.body),
      const SizedBox(height: 32),
      for (final language in controller.languages) ...[
        ChoiceCard(
          title: language.code == englishLanguageCode ? context.t(EmployeeTextKeys.languageEnglish) : language.name,
          selected: controller.languageCode == language.code,
          minHeight: 58,
          onTap: () => controller.chooseLanguage(language.code),
        ),
        const SizedBox(height: 12),
      ],
      if (controller.languagesFailed || controller.languageInvalid) ...[
        const SizedBox(height: 12),
        NoteBox(
          text: context.t(
            controller.languageInvalid ? EmployeeTextKeys.languageInvalid : EmployeeTextKeys.languageLoadFailed,
          ),
          background: JitanColors.brandTint,
          textStyle: JitanMobileTextStyles.cardText,
          padding: const EdgeInsets.all(16),
        ),
      ],
    ],
  );
}

/// 05 Registration method.
class MethodScreen extends StatelessWidget {
  const MethodScreen({super.key, required this.controller});

  final OnboardingController controller;

  @override
  Widget build(BuildContext context) => OnboardingPage(
    actions: [JitanMobileButton(label: context.t(CommonTextKeys.continueAction), onPressed: controller.confirmMethod)],
    children: [
      const SizedBox(height: 45),
      Semantics(header: true, child: Text(context.t(EmployeeTextKeys.methodTitle), style: JitanMobileTextStyles.title)),
      const SizedBox(height: 11),
      Text(context.t(EmployeeTextKeys.methodText), style: JitanMobileTextStyles.body),
      const SizedBox(height: 38),
      ChoiceCard(
        title: context.t(EmployeeTextKeys.methodAutomaticTitle),
        text: context.t(EmployeeTextKeys.methodAutomaticText),
        selected: controller.method == RegistrationMethod.automatic,
        onTap: () => controller.chooseMethod(RegistrationMethod.automatic),
      ),
      const SizedBox(height: 16),
      ChoiceCard(
        title: context.t(EmployeeTextKeys.methodManualTitle),
        text: context.t(EmployeeTextKeys.methodManualText),
        selected: controller.method == RegistrationMethod.manual,
        onTap: () => controller.chooseMethod(RegistrationMethod.manual),
      ),
      const SizedBox(height: 24),
      NoteBox(
        text: context.t(EmployeeTextKeys.methodNote),
        background: JitanColors.brandTint,
        textStyle: JitanMobileTextStyles.cardText,
        minHeight: 70,
        padding: const EdgeInsets.fromLTRB(16, 17, 26, 17),
      ),
    ],
  );
}

/// 06 Permissions: "Continue" shows the system prompts.
class PermissionsScreen extends StatelessWidget {
  const PermissionsScreen({super.key, required this.controller});

  final OnboardingController controller;

  @override
  Widget build(BuildContext context) => OnboardingPage(
    actions: [
      JitanMobileButton(
        label: context.t(CommonTextKeys.continueAction),
        busy: controller.busy,
        onPressed: controller.requestPermissions,
      ),
    ],
    children: [
      const SizedBox(height: 45),
      Semantics(header: true, child: Text(context.t(EmployeeTextKeys.permissionsTitle), style: JitanMobileTextStyles.title)),
      const SizedBox(height: 12),
      Text(context.t(EmployeeTextKeys.permissionsText), style: JitanMobileTextStyles.bodyLarge),
      const SizedBox(height: 29),
      if (controller.method == RegistrationMethod.automatic) ...[
        _PermissionCard(
          title: context.t(EmployeeTextKeys.permissionsLocationTitle),
          text: context.t(EmployeeTextKeys.permissionsLocationText),
        ),
        const SizedBox(height: 16),
      ],
      _PermissionCard(
        title: context.t(EmployeeTextKeys.permissionsNotificationsTitle),
        text: context.t(EmployeeTextKeys.permissionsNotificationsText),
      ),
      const SizedBox(height: 32),
      NoteBox(
        title: context.t(EmployeeTextKeys.permissionsPrivacyTitle),
        text: context.t(EmployeeTextKeys.permissionsPrivacyText),
        background: JitanColors.noteSurface,
        titleStyle: JitanMobileTextStyles.noteTitleLarge,
        textStyle: JitanMobileTextStyles.cardText,
        radius: 18,
        minHeight: 104,
        padding: const EdgeInsets.fromLTRB(16, 16, 21, 16),
      ),
    ],
  );
}

class _PermissionCard extends StatelessWidget {
  const _PermissionCard({required this.title, required this.text});

  final String title;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    constraints: const BoxConstraints(minHeight: 100),
    padding: const EdgeInsets.fromLTRB(18, 17, 54, 17),
    decoration: BoxDecoration(color: JitanColors.surface, borderRadius: BorderRadius.circular(18)),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: JitanMobileTextStyles.cardTitleSmall),
        const SizedBox(height: 11),
        Text(text, style: JitanMobileTextStyles.cardText),
      ],
    ),
  );
}

/// 07 Set password. Mandatory: there is no "Set this later" (decision
/// 2026-10-07, ONB-01). Continue completes onboarding and signs in.
class PasswordScreen extends StatefulWidget {
  const PasswordScreen({super.key, required this.controller});

  final OnboardingController controller;

  /// Position of this screen in the flow, for the "n of total" counter.
  static const stepNumber = 8;
  static const stepCount = 9;

  @override
  State<PasswordScreen> createState() => _PasswordScreenState();
}

class _PasswordScreenState extends State<PasswordScreen> {
  final _password = TextEditingController();
  final _confirmation = TextEditingController();

  @override
  void dispose() {
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  void _submit() => widget.controller.submitPassword(_password.text, _confirmation.text);

  @override
  Widget build(BuildContext context) {
    final problem = widget.controller.passwordProblem;
    final passwordError = switch (problem) {
      PasswordProblem.tooShort => context.t(EmployeeTextKeys.passwordErrorTooShort),
      PasswordProblem.tooLong => context.t(EmployeeTextKeys.passwordErrorTooLong),
      PasswordProblem.rejected => context.t(EmployeeTextKeys.passwordErrorRejected),
      _ => null,
    };
    final showLabel = context.t(EmployeeTextKeys.passwordShow);
    final hideLabel = context.t(EmployeeTextKeys.passwordHide);
    return OnboardingPage(
      showLogo: false,
      actions: [
        JitanMobileButton(
          label: context.t(CommonTextKeys.continueAction),
          style: JitanMobileButtonStyle.brand,
          size: JitanMobileButtonSize.medium,
          busy: widget.controller.busy,
          onPressed: _submit,
        ),
        const SizedBox(height: 22),
        Text(
          context.t(
            EmployeeTextKeys.step,
            args: {'n': PasswordScreen.stepNumber, 'total': PasswordScreen.stepCount},
          ),
          style: JitanMobileTextStyles.step,
        ),
      ],
      children: [
        Semantics(header: true, child: Text(context.t(EmployeeTextKeys.passwordTitle), style: JitanMobileTextStyles.formTitle)),
        const SizedBox(height: 10),
        Text(context.t(EmployeeTextKeys.passwordText), style: JitanMobileTextStyles.caption),
        const SizedBox(height: 44),
        AutofillGroup(
          child: Column(
            children: [
              PasswordField(
                controller: _password,
                label: context.t(EmployeeTextKeys.passwordLabel),
                hint: context.t(EmployeeTextKeys.passwordHint),
                showLabel: showLabel,
                hideLabel: hideLabel,
                error: passwordError,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.newPassword],
              ),
              const SizedBox(height: 22),
              PasswordField(
                controller: _confirmation,
                label: context.t(EmployeeTextKeys.passwordConfirmLabel),
                hint: context.t(EmployeeTextKeys.passwordConfirmHint),
                showLabel: showLabel,
                hideLabel: hideLabel,
                error: problem == PasswordProblem.mismatch ? context.t(EmployeeTextKeys.passwordErrorMismatch) : null,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
                autofillHints: const [AutofillHints.newPassword],
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),
        NoteBox(
          title: context.t(EmployeeTextKeys.passwordNoteTitle),
          text: context.t(EmployeeTextKeys.passwordNoteText),
          minHeight: 86,
        ),
      ],
    );
  }
}

/// 08 Ready: the device is signed in; "Start Jitan" opens the app.
class ReadyScreen extends StatelessWidget {
  const ReadyScreen({super.key, required this.controller, required this.onStart});

  final OnboardingController controller;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) => OnboardingPage(
    actions: [
      JitanMobileButton(
        label: context.t(EmployeeTextKeys.readyAction),
        style: JitanMobileButtonStyle.brand,
        onPressed: onStart,
      ),
    ],
    children: [
      const SizedBox(height: 45),
      Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 13),
        decoration: BoxDecoration(color: JitanColors.successSurface, borderRadius: BorderRadius.circular(16)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check, size: 13, color: JitanColors.success),
            const SizedBox(width: 8),
            Text(context.t(EmployeeTextKeys.readyBadge), style: JitanMobileTextStyles.badge),
          ],
        ),
      ),
      const SizedBox(height: 23),
      Semantics(header: true, child: Text(context.t(EmployeeTextKeys.readyTitle), style: JitanMobileTextStyles.displayLarge)),
      const SizedBox(height: 8),
      Text(context.t(EmployeeTextKeys.readyText), style: JitanMobileTextStyles.bodyLarge),
      const SizedBox(height: 42),
      const OnboardingIllustration(
        asset: 'assets/illustrations/ready.png',
        widthFactor: 1.0659,
        heightFactor: 1.1022,
        left: -0.0336,
        top: -0.0489,
      ),
      const SizedBox(height: 24),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
        decoration: BoxDecoration(color: JitanColors.surface, borderRadius: BorderRadius.circular(20)),
        child: Column(
          children: [
            _SummaryRow(text: context.t(EmployeeTextKeys.readyWorkplace)),
            const SizedBox(height: 18),
            _SummaryRow(text: context.t(EmployeeTextKeys.readyMethod)),
            const SizedBox(height: 18),
            controller.locationMissing
                ? _SummaryRow(text: context.t(EmployeeTextKeys.readyLocationMissing), done: false)
                : _SummaryRow(text: context.t(EmployeeTextKeys.readyPermissions)),
          ],
        ),
      ),
    ],
  );
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.text, this.done = true});

  final String text;
  final bool done;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(
        done ? Icons.check : Icons.error_outline,
        size: 15,
        color: done ? JitanColors.success : JitanColors.warning,
      ),
      const SizedBox(width: 14),
      Expanded(
        child: Text(
          text,
          style: JitanMobileTextStyles.summary.copyWith(color: done ? null : JitanColors.warning),
        ),
      ),
    ],
  );
}
