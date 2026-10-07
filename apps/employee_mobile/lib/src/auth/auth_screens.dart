import 'package:flutter/material.dart';
import 'package:jitan_core/jitan_core.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../l10n/employee_text_keys.dart';
import '../widgets/mobile_widgets.dart';
import 'auth_controller.dart';

// Spacing measured from the Figma "Auth / …" frames (390 × 844).

/// Logo, title and subtitle at the top of the auth screens.
class _AuthHeader extends StatelessWidget {
  const _AuthHeader({required this.title, required this.text});

  final String title;
  final String text;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      JitanWordmark(style: JitanMobileTextStyles.logo.copyWith(fontSize: 24)),
      const SizedBox(height: 28),
      Semantics(header: true, child: Text(title, style: JitanMobileTextStyles.formTitle)),
      const SizedBox(height: 10),
      Text(text, style: JitanMobileTextStyles.caption),
    ],
  );
}

class _AuthScaffold extends StatelessWidget {
  const _AuthScaffold({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: JitanColors.warmWhite,
    body: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(OnboardingPage.margin, 0, OnboardingPage.margin, 24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
      ),
    ),
  );
}

/// Auth / 01 Sign in.
class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key, required this.controller, required this.onUseQr});

  final AuthController controller;

  /// "Set up with my QR": back to onboarding for a first-time employee.
  final VoidCallback onUseQr;

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  late final _code = TextEditingController(text: widget.controller.code);
  final _password = TextEditingController();

  @override
  void dispose() {
    _code.dispose();
    _password.dispose();
    super.dispose();
  }

  void _submit() => widget.controller.signIn(_code.text, _password.text);

  @override
  Widget build(BuildContext context) => _AuthScaffold(
    children: [
      _AuthHeader(title: context.t(EmployeeTextKeys.signInTitle), text: context.t(EmployeeTextKeys.signInText)),
      const SizedBox(height: 70),
      AutofillGroup(
        child: Column(
          children: [
            LabeledTextField(
              controller: _code,
              label: context.t(EmployeeTextKeys.codeLabel),
              hint: context.t(EmployeeTextKeys.codeHint),
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.username],
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 26),
            PasswordField(
              controller: _password,
              label: context.t(EmployeeTextKeys.signInPasswordLabel),
              hint: context.t(EmployeeTextKeys.signInPasswordHint),
              showLabel: context.t(EmployeeTextKeys.passwordShow),
              hideLabel: context.t(EmployeeTextKeys.passwordHide),
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
              onChanged: (_) => setState(() {}),
              autofillHints: const [AutofillHints.password],
            ),
          ],
        ),
      ),
      Align(
        alignment: Alignment.centerRight,
        child: TextButton(
          onPressed: widget.controller.openForgotPassword,
          style: TextButton.styleFrom(foregroundColor: JitanColors.vermilion),
          child: Text(
            context.t(EmployeeTextKeys.forgotLink),
            style: JitanMobileTextStyles.link.copyWith(fontSize: 11, color: JitanColors.vermilion),
          ),
        ),
      ),
      const SizedBox(height: 32),
      JitanMobileButton(
        label: context.t(EmployeeTextKeys.signInAction),
        style: JitanMobileButtonStyle.brand,
        size: JitanMobileButtonSize.medium,
        busy: widget.controller.busy,
        onPressed: AuthController.canSubmit(_code.text, _password.text) ? _submit : null,
      ),
      const SizedBox(height: 34),
      NoteBox(
        title: context.t(EmployeeTextKeys.signInHelpTitle),
        text: context.t(EmployeeTextKeys.signInHelp),
        minHeight: 86,
      ),
      const SizedBox(height: 4),
      Center(
        child: TextButton(
          onPressed: widget.onUseQr,
          style: TextButton.styleFrom(foregroundColor: JitanColors.inkMuted),
          child: Text(context.t(EmployeeTextKeys.signInUseQr), style: JitanMobileTextStyles.link.copyWith(fontSize: 11)),
        ),
      ),
    ],
  );
}

/// Auth / 02 Forgot password: asks for the employee code. Continue sends
/// nothing; it shows how to recover ([RecoveryScreen]).
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key, required this.controller});

  final AuthController controller;

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  late final _code = TextEditingController(text: widget.controller.code);

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  void _submit() => widget.controller.submitForgotPassword(_code.text);

  @override
  Widget build(BuildContext context) => _AuthScaffold(
    children: [
      _AuthHeader(title: context.t(EmployeeTextKeys.forgotTitle), text: context.t(EmployeeTextKeys.forgotText)),
      const SizedBox(height: 88),
      LabeledTextField(
        controller: _code,
        label: context.t(EmployeeTextKeys.codeLabel),
        hint: context.t(EmployeeTextKeys.codeHint),
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _submit(),
        onChanged: (_) => setState(() {}),
      ),
      const SizedBox(height: 46),
      JitanMobileButton(
        label: context.t(CommonTextKeys.continueAction),
        style: JitanMobileButtonStyle.brand,
        size: JitanMobileButtonSize.medium,
        onPressed: _code.text.trim().isEmpty ? null : _submit,
      ),
      const SizedBox(height: 12),
      Center(
        child: TextButton(
          onPressed: widget.controller.back,
          style: TextButton.styleFrom(foregroundColor: JitanColors.inkMuted),
          child: Text(context.t(EmployeeTextKeys.forgotBack), style: JitanMobileTextStyles.link.copyWith(fontSize: 11)),
        ),
      ),
    ],
  );
}

/// After "Forgot password" (and "Contact HR/Admin"): recovery is
/// HR/Admin-assisted in V1. No Figma frame yet; built from the Auth screens'
/// parts (DESIGN-CLARIFY-AUTH).
class RecoveryScreen extends StatelessWidget {
  const RecoveryScreen({super.key, required this.controller});

  final AuthController controller;

  @override
  Widget build(BuildContext context) => _AuthScaffold(
    children: [
      _AuthHeader(title: context.t(EmployeeTextKeys.recoveryTitle), text: context.t(EmployeeTextKeys.recoveryText)),
      if (controller.code.isNotEmpty) ...[
        const SizedBox(height: 16),
        Text(
          context.t(EmployeeTextKeys.recoveryCode, args: {'code': controller.code}),
          style: JitanMobileTextStyles.cardTitleSmall,
        ),
      ],
      const SizedBox(height: 40),
      NoteBox(
        title: context.t(EmployeeTextKeys.recoveryStepsTitle),
        text: context.t(EmployeeTextKeys.recoveryStepsText),
        background: JitanColors.warningSurface,
        foreground: JitanColors.warning,
        radius: 18,
        minHeight: 100,
      ),
      const SizedBox(height: 16),
      NoteBox(
        title: context.t(EmployeeTextKeys.recoveryDeviceTitle),
        text: context.t(EmployeeTextKeys.recoveryDeviceText),
        minHeight: 86,
      ),
      const SizedBox(height: 34),
      JitanMobileButton(
        label: context.t(EmployeeTextKeys.forgotBack),
        style: JitanMobileButtonStyle.secondary,
        size: JitanMobileButtonSize.medium,
        onPressed: controller.back,
      ),
    ],
  );
}

/// Auth / 03 Invalid credentials, 04 Account unavailable, 05 Network error.
class AuthErrorScreen extends StatelessWidget {
  const AuthErrorScreen({super.key, required this.controller});

  final AuthController controller;

  @override
  Widget build(BuildContext context) {
    final retry = StatusAction(
      label: context.t(CommonTextKeys.retry),
      primary: true,
      busy: controller.busy,
      onPressed: controller.retry,
    );
    final back = StatusAction(label: context.t(CommonTextKeys.back), onPressed: controller.busy ? null : controller.back);
    return switch (controller.problem ?? AuthProblem.unreachable) {
      AuthProblem.invalidCredentials => StatusPage(
        showLogo: true,
        buttonSize: JitanMobileButtonSize.medium,
        tone: StatusTone.error,
        title: context.t(EmployeeTextKeys.errorInvalidTitle),
        text: context.t(EmployeeTextKeys.errorInvalidText),
        helpTitle: context.t(EmployeeTextKeys.errorInvalidHelpTitle),
        help: context.t(EmployeeTextKeys.errorInvalidHelp),
        actions: [
          retry,
          StatusAction(label: context.t(EmployeeTextKeys.errorInvalidForgot), onPressed: controller.openForgotPassword),
        ],
      ),
      AuthProblem.accountUnavailable => StatusPage(
        showLogo: true,
        buttonSize: JitanMobileButtonSize.medium,
        tone: StatusTone.warning,
        title: context.t(EmployeeTextKeys.errorAccountTitle),
        text: context.t(EmployeeTextKeys.errorAccountText),
        helpTitle: context.t(EmployeeTextKeys.errorAccountHelpTitle),
        help: context.t(EmployeeTextKeys.errorAccountHelp),
        actions: [back],
      ),
      AuthProblem.unreachable => StatusPage(
        showLogo: true,
        buttonSize: JitanMobileButtonSize.medium,
        tone: StatusTone.error,
        title: context.t(EmployeeTextKeys.errorReachTitle),
        text: context.t(EmployeeTextKeys.errorReachText),
        helpTitle: context.t(EmployeeTextKeys.errorReachHelpTitle),
        help: context.t(EmployeeTextKeys.errorReachHelp),
        actions: [retry, back],
      ),
    };
  }
}
