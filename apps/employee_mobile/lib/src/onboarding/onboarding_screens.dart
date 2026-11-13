import 'package:flutter/material.dart';
import 'package:jitan_core/jitan_core.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../device/device_settings.dart';
import '../l10n/employee_text_keys.dart';
import '../widgets/mobile_widgets.dart';
import '../widgets/phone_widgets.dart';
import 'onboarding_controller.dart';
import '../widgets/phone_step_page.dart';

// The onboarding screens, drawn in Figma `1591:356` (2026-11-13).

JitanMobileButton _button(String label, VoidCallback? onPressed, {bool busy = false}) =>
    JitanMobileButton(label: label, onPressed: onPressed, busy: busy, size: JitanMobileButtonSize.phone);

/// Welcome. "Already set up? Sign in" is for an employee who finished setup
/// before, on a new phone or after a reinstall.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key, required this.controller, required this.onSignIn});

  final OnboardingController controller;
  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) => PhoneStepPage(
    large: true,
    title: context.t(EmployeeTextKeys.welcomeTitle),
    subtitle: context.t(EmployeeTextKeys.welcomeText),
    action: _button(context.t(EmployeeTextKeys.welcomeAction), controller.getStarted),
    link: PhoneQuietLink(label: context.t(EmployeeTextKeys.welcomeSignIn), onPressed: onSignIn),
    children: const [
      OnboardingIllustration(
        asset: 'assets/illustrations/welcome.png',
        widthFactor: 1.0633,
        heightFactor: 1.1061,
        left: -0.0348,
        top: -0.0478,
      ),
    ],
  );
}

/// Join your workplace: opens the scanner.
class JoinScreen extends StatelessWidget {
  const JoinScreen({super.key, required this.controller, required this.onScan});

  final OnboardingController controller;

  /// Opens the camera; the scanned value goes to [OnboardingController.submitQr].
  final VoidCallback onScan;

  @override
  Widget build(BuildContext context) => PhoneStepPage(
    showBack: true,
    onBack: controller.back,
    title: context.t(EmployeeTextKeys.joinTitle),
    subtitle: context.t(EmployeeTextKeys.joinText),
    action: _button(context.t(EmployeeTextKeys.joinAction), onScan, busy: controller.busy),
    children: const [
      OnboardingIllustration(
        asset: 'assets/illustrations/join_workplace.png',
        widthFactor: 1.0469,
        heightFactor: 1.0837,
        left: -0.0266,
        top: -0.0359,
      ),
    ],
  );
}

/// Step 1, "Is this you?": the account the setup QR belongs to.
class ConfirmScreen extends StatelessWidget {
  const ConfirmScreen({super.key, required this.controller});

  final OnboardingController controller;

  @override
  Widget build(BuildContext context) {
    final account = controller.account;
    final name = [account?.firstName, account?.lastName].whereType<String>().where((n) => n.isNotEmpty).join(' ');
    final displayName = name.isEmpty ? (account?.code ?? '') : name;
    final details = [...?account?.companies, ?account?.code].join(' · ');
    return PhoneStepPage(
      showBack: true,
      onBack: controller.back,
      step: 1,
      above: Row(
        spacing: 6,
        children: [
          const Icon(Icons.check, size: 16, color: JitanColors.success),
          Text(
            context.t(EmployeeTextKeys.confirmVerified),
            style: JitanMobileTextStyles.label.copyWith(color: JitanColors.success),
          ),
        ],
      ),
      title: context.t(EmployeeTextKeys.confirmTitle),
      subtitle: context.t(EmployeeTextKeys.confirmText),
      action: _button(context.t(EmployeeTextKeys.confirmAction), controller.confirmAccount),
      link: PhoneQuietLink(
        label: '${context.t(EmployeeTextKeys.confirmNotYou)} ${context.t(EmployeeTextKeys.confirmGoBack)}',
        onPressed: controller.rejectAccount,
      ),
      children: [
        PhoneListCard(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 18),
              child: Row(
                spacing: 12,
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: JitanColors.ink,
                    child: Text(
                      displayName.isEmpty ? '' : displayName.characters.first.toUpperCase(),
                      style: JitanMobileTextStyles.rowTitle.copyWith(fontSize: 17, color: JitanColors.surface),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: 2,
                      children: [
                        Text(displayName, style: JitanMobileTextStyles.rowTitle.copyWith(fontSize: 17)),
                        if (details.isNotEmpty) Text(details, style: JitanMobileTextStyles.detail),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Step 2, the registration method (stays on the phone, GAP-07).
class MethodScreen extends StatelessWidget {
  const MethodScreen({super.key, required this.controller});

  final OnboardingController controller;

  @override
  Widget build(BuildContext context) {
    Widget option(RegistrationMethod method, String title, String text) {
      final selected = controller.method == method;
      return PhoneListRow(
        title: title,
        detail: text,
        selected: selected,
        trailing: selected ? const PhoneCheck() : null,
        onTap: () => controller.chooseMethod(method),
      );
    }

    return PhoneStepPage(
      showBack: true,
      onBack: controller.back,
      step: 2,
      title: context.t(EmployeeTextKeys.methodTitle),
      subtitle: context.t(EmployeeTextKeys.methodText),
      action: _button(context.t(CommonTextKeys.continueAction), controller.confirmMethod),
      children: [
        PhoneListCard(
          padding: EdgeInsets.zero,
          children: [
            option(
              RegistrationMethod.automatic,
              context.t(EmployeeTextKeys.methodAutomaticTitle),
              context.t(EmployeeTextKeys.methodAutomaticText),
            ),
            option(
              RegistrationMethod.qr,
              context.t(EmployeeTextKeys.methodQrTitle),
              context.t(EmployeeTextKeys.methodQrText),
            ),
            option(
              RegistrationMethod.manual,
              context.t(EmployeeTextKeys.methodManualTitle),
              context.t(EmployeeTextKeys.methodManualText),
            ),
          ],
        ),
      ],
    );
  }
}

/// Step 3: what the phone will ask for. "Continue" shows the system prompts;
/// location only for Automatic.
class PermissionsScreen extends StatelessWidget {
  const PermissionsScreen({super.key, required this.controller});

  final OnboardingController controller;

  @override
  Widget build(BuildContext context) => PhoneStepPage(
    showBack: true,
    onBack: controller.busy ? null : controller.back,
    step: 3,
    title: context.t(EmployeeTextKeys.permissionsTitle),
    subtitle: context.t(EmployeeTextKeys.permissionsText),
    action: _button(context.t(CommonTextKeys.continueAction), controller.requestPermissions, busy: controller.busy),
    children: [
      PhoneListCard(
        padding: EdgeInsets.zero,
        children: [
          if (controller.method == RegistrationMethod.automatic)
            PhoneListRow(
              title: context.t(EmployeeTextKeys.permissionsLocationTitle),
              detail: context.t(EmployeeTextKeys.permissionsLocationText),
            ),
          PhoneListRow(
            title: context.t(EmployeeTextKeys.permissionsNotificationsTitle),
            detail: context.t(EmployeeTextKeys.permissionsNotificationsText),
          ),
        ],
      ),
      const SizedBox(height: 12),
      Text(context.t(EmployeeTextKeys.permissionsNote), style: JitanMobileTextStyles.detail),
    ],
  );
}

/// Step 4, the language. Languages come from `tblLanguage` (any number);
/// English is built in and always first. Each row shows the language's own
/// name and, when a translation exists, its name in the current language.
class LanguageScreen extends StatelessWidget {
  const LanguageScreen({super.key, required this.controller});

  final OnboardingController controller;

  @override
  Widget build(BuildContext context) => PhoneStepPage(
    showBack: true,
    onBack: controller.back,
    step: 4,
    title: context.t(EmployeeTextKeys.languageTitle),
    subtitle: context.t(EmployeeTextKeys.languageText),
    action: _button(context.t(CommonTextKeys.continueAction), controller.confirmLanguage),
    children: [
      PhoneListCard(
        padding: EdgeInsets.zero,
        children: [
          for (final language in controller.languages)
            PhoneListRow(
              title: _ownName(context, language),
              titleStyle: JitanMobileTextStyles.rowTitle.copyWith(fontWeight: FontWeight.w500),
              detail: _translatedName(context, language),
              selected: controller.languageCode == language.code,
              trailing: controller.languageCode == language.code ? const PhoneCheck() : null,
              onTap: () => controller.chooseLanguage(language.code),
            ),
        ],
      ),
      if (controller.languageInvalid || controller.languagesFailed) ...[
        const SizedBox(height: 12),
        Semantics(
          liveRegion: true,
          child: Text(
            context.t(controller.languageInvalid ? EmployeeTextKeys.languageInvalid : EmployeeTextKeys.languageLoadFailed),
            style: JitanMobileTextStyles.detail.copyWith(
              color: controller.languageInvalid ? JitanColors.errorStrong : JitanColors.inkMuted,
            ),
          ),
        ),
      ],
    ],
  );
}

String _ownName(BuildContext context, Language language) =>
    language.code == englishLanguageCode ? context.t(EmployeeTextKeys.languageEnglish) : language.name;

/// The language's name in the current language, unless it reads the same
/// ("English" under "English").
String? _translatedName(BuildContext context, Language language) {
  final translated = context.tOrNull(CommonTextKeys.languageName(language.code));
  return translated == _ownName(context, language) ? null : translated;
}

/// Step 5, the password. Mandatory: there is no "Set this later" (decision
/// 2026-10-07, ONB-01). "Finish setup" completes onboarding and signs in.
class PasswordScreen extends StatefulWidget {
  const PasswordScreen({super.key, required this.controller});

  final OnboardingController controller;

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
    final controller = widget.controller;
    final problem = controller.passwordProblem;
    final passwordError = switch (problem) {
      PasswordProblem.tooShort => context.t(EmployeeTextKeys.passwordErrorTooShort),
      PasswordProblem.tooLong => context.t(EmployeeTextKeys.passwordErrorTooLong),
      PasswordProblem.rejected => context.t(EmployeeTextKeys.passwordErrorRejected),
      _ => null,
    };
    final showLabel = context.t(EmployeeTextKeys.passwordShow);
    final hideLabel = context.t(EmployeeTextKeys.passwordHide);
    return PhoneStepPage(
      showBack: true,
      onBack: controller.busy ? null : controller.back,
      step: 5,
      title: context.t(EmployeeTextKeys.passwordTitle),
      subtitle: context.t(EmployeeTextKeys.passwordText),
      action: _button(context.t(EmployeeTextKeys.passwordAction), _submit, busy: controller.busy),
      children: [
        AutofillGroup(
          child: Column(
            children: [
              PasswordField(
                phone: true,
                controller: _password,
                label: context.t(EmployeeTextKeys.passwordLabel),
                hint: context.t(EmployeeTextKeys.passwordHint),
                showLabel: showLabel,
                hideLabel: hideLabel,
                error: passwordError,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.newPassword],
              ),
              const SizedBox(height: 18),
              PasswordField(
                phone: true,
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
        const SizedBox(height: 14),
        Text(context.t(EmployeeTextKeys.passwordNote), style: JitanMobileTextStyles.detail),
      ],
    );
  }
}

/// Ready: the phone is signed in. Shows what was set up; "Start Jitan" opens
/// the app.
class ReadyScreen extends StatelessWidget {
  const ReadyScreen({super.key, required this.controller, required this.onStart});

  final OnboardingController controller;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final companies = controller.account?.companies ?? const <String>[];
    final language = controller.languageCode == englishLanguageCode
        ? context.t(EmployeeTextKeys.languageEnglish)
        : controller.languages.where((l) => l.code == controller.languageCode).firstOrNull?.name;
    final method = context.t(switch (controller.method) {
      RegistrationMethod.automatic => EmployeeTextKeys.methodAutomaticTitle,
      RegistrationMethod.qr => EmployeeTextKeys.methodQrTitle,
      RegistrationMethod.manual => EmployeeTextKeys.methodManualTitle,
    });
    return PhoneStepPage(
      large: true,
      title: context.t(EmployeeTextKeys.readyTitle),
      subtitle: context.t(EmployeeTextKeys.readyText),
      action: _button(context.t(EmployeeTextKeys.readyAction), onStart),
      children: [
        const OnboardingIllustration(
          asset: 'assets/illustrations/ready.png',
          widthFactor: 1.0659,
          heightFactor: 1.1022,
          left: -0.0336,
          top: -0.0489,
        ),
        const SizedBox(height: 16),
        PhoneListCard(
          children: [
            if (companies.isNotEmpty) _SummaryRow(label: context.t(EmployeeTextKeys.readyWorkplace), value: companies.join(', ')),
            _SummaryRow(label: context.t(EmployeeTextKeys.readyMethod), value: method),
            if (language != null) _SummaryRow(label: context.t(EmployeeTextKeys.readyLanguage), value: language),
          ],
        ),
        if (controller.locationMissing) ...[
          const SizedBox(height: 12),
          Text(
            context.t(EmployeeTextKeys.readyLocationMissing),
            style: JitanMobileTextStyles.detail.copyWith(color: JitanColors.warning),
          ),
        ],
      ],
    );
  }
}

/// "Registration    Automatic".
class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 14),
    child: Row(
      spacing: 12,
      children: [
        Text(label, style: JitanMobileTextStyles.rowText.copyWith(color: JitanColors.inkMuted)),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: JitanMobileTextStyles.rowText,
          ),
        ),
      ],
    ),
  );
}
