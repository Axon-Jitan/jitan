import 'package:flutter/material.dart';
import 'package:jitan_core/jitan_core.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../l10n/employee_text_keys.dart';
import '../onboarding/qr_scanner_view.dart';
import '../widgets/mobile_widgets.dart';
import '../widgets/phone_step_page.dart';
import '../widgets/phone_widgets.dart';
import '../widgets/qr_camera_frame.dart';
import 'auth_controller.dart';
import 'password_rules.dart';

// Sign-in and recovery, drawn in Figma `1592:211` (2026-11-13).

JitanMobileButton _button(String label, VoidCallback? onPressed, {bool busy = false}) =>
    JitanMobileButton(label: label, onPressed: onPressed, busy: busy, size: JitanMobileButtonSize.phone);

/// Sign in: employee code and password. "Forgot password?" opens the
/// recovery scanner; "First time? Set up with my QR" goes back to onboarding.
class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key, required this.controller, required this.onUseQr});

  final AuthController controller;

  /// "First time? Set up with my QR": back to onboarding.
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
  Widget build(BuildContext context) => PhoneStepPage(
    title: context.t(EmployeeTextKeys.signInTitle),
    subtitle: context.t(EmployeeTextKeys.signInText),
    contentGap: 28,
    action: _button(
      context.t(EmployeeTextKeys.signInAction),
      AuthController.canSubmit(_code.text, _password.text) ? _submit : null,
      busy: widget.controller.busy,
    ),
    link: PhoneQuietLink(label: context.t(EmployeeTextKeys.signInUseQr), onPressed: widget.onUseQr),
    children: [
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
            const SizedBox(height: 18),
            PasswordField(
              phone: true,
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
        child: PhoneQuietLink(
          label: context.t(EmployeeTextKeys.forgotLink),
          onPressed: widget.controller.openRecovery,
        ),
      ),
    ],
  );
}

/// "Forgot your password?": the recovery scanner. Only HR can reset access,
/// so the screen says that first. The QR is accepted only after HR/Admin
/// "Reset account access"; before that a red line says so and scanning goes
/// on. An expired or used QR shows "QR expired or used" on the same screen.
class RecoverWithQrScreen extends StatelessWidget {
  const RecoverWithQrScreen({super.key, required this.controller, required this.scannerView});

  final AuthController controller;
  final QrScannerView scannerView;

  @override
  Widget build(BuildContext context) {
    final refusal = controller.recoveryRefusal;
    final expired = refusal == RecoveryRefusal.qrExpiredOrUsed;
    final (note, color) = switch (refusal) {
      null => (EmployeeTextKeys.recoverNoteText, JitanColors.inkMuted),
      RecoveryRefusal.resetRequired => (EmployeeTextKeys.recoverRefused, JitanColors.errorStrong),
      RecoveryRefusal.qrExpiredOrUsed => (EmployeeTextKeys.recoverExpiredNoteText, JitanColors.inkMuted),
    };
    return PhoneStepPage(
      showBack: true,
      onBack: controller.busy ? null : controller.back,
      title: context.t(expired ? EmployeeTextKeys.recoverExpiredTitle : EmployeeTextKeys.recoverTitle),
      subtitle: context.t(expired ? EmployeeTextKeys.recoverExpiredText : EmployeeTextKeys.recoverText),
      children: [
        QrCameraFrame(
          scannerView: scannerView,
          onDetected: controller.submitRecoveryQr,
          busy: controller.busy,
          hint: context.t(EmployeeTextKeys.recoverScanHint),
        ),
        const SizedBox(height: 14),
        Semantics(
          liveRegion: true,
          child: Text(
            context.t(note),
            textAlign: TextAlign.center,
            style: JitanMobileTextStyles.detail.copyWith(color: color),
          ),
        ),
      ],
    );
  }
}

/// Set a new password after the reset. "Save and sign in" stores it
/// (Argon2id on the server) and signs this phone in.
class SetNewPasswordScreen extends StatefulWidget {
  const SetNewPasswordScreen({super.key, required this.controller});

  final AuthController controller;

  @override
  State<SetNewPasswordScreen> createState() => _SetNewPasswordScreenState();
}

class _SetNewPasswordScreenState extends State<SetNewPasswordScreen> {
  final _password = TextEditingController();
  final _confirmation = TextEditingController();

  @override
  void dispose() {
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  void _submit() => widget.controller.submitNewPassword(_password.text, _confirmation.text);

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final problem = controller.passwordProblem;
    final showLabel = context.t(EmployeeTextKeys.passwordShow);
    final hideLabel = context.t(EmployeeTextKeys.passwordHide);
    return PhoneStepPage(
      showBack: true,
      onBack: controller.busy ? null : controller.back,
      title: context.t(EmployeeTextKeys.newPasswordTitle),
      subtitle: context.t(EmployeeTextKeys.newPasswordText),
      contentGap: 28,
      action: _button(context.t(EmployeeTextKeys.newPasswordAction), _submit, busy: controller.busy),
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
                error: switch (problem) {
                  PasswordProblem.tooShort => context.t(EmployeeTextKeys.passwordErrorTooShort),
                  PasswordProblem.tooLong => context.t(EmployeeTextKeys.passwordErrorTooLong),
                  PasswordProblem.rejected => context.t(EmployeeTextKeys.passwordErrorRejected),
                  _ => null,
                },
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
        Text(context.t(EmployeeTextKeys.newPasswordNoteText), style: JitanMobileTextStyles.detail),
      ],
    );
  }
}

/// Couldn't sign in, account unavailable, too many attempts, can't reach
/// Jitan: a small icon, the title, one sentence, a line of help, one action.
class AuthErrorScreen extends StatelessWidget {
  const AuthErrorScreen({super.key, required this.controller});

  final AuthController controller;

  @override
  Widget build(BuildContext context) {
    void retry() => controller.retry();
    void back() => controller.back();
    final (tone, title, text, help, actionKey, onAction, linkKey, onLink) =
        switch (controller.problem ?? AuthProblem.unreachable) {
          AuthProblem.invalidCredentials => (
            PhoneTone.error,
            EmployeeTextKeys.errorInvalidTitle,
            EmployeeTextKeys.errorInvalidText,
            EmployeeTextKeys.errorInvalidHelp,
            CommonTextKeys.retry,
            retry,
            EmployeeTextKeys.errorInvalidForgot,
            controller.openRecovery,
          ),
          AuthProblem.accountUnavailable => (
            PhoneTone.warning,
            EmployeeTextKeys.errorAccountTitle,
            EmployeeTextKeys.errorAccountText,
            EmployeeTextKeys.errorAccountHelp,
            CommonTextKeys.back,
            back,
            null,
            null,
          ),
          AuthProblem.tooManyAttempts => (
            PhoneTone.warning,
            EmployeeTextKeys.errorTooManyTitle,
            EmployeeTextKeys.errorTooManyText,
            EmployeeTextKeys.errorTooManyHelp,
            CommonTextKeys.back,
            back,
            null,
            null,
          ),
          AuthProblem.unreachable => (
            PhoneTone.retry,
            EmployeeTextKeys.errorReachTitle,
            EmployeeTextKeys.errorReachText,
            EmployeeTextKeys.errorReachHelp,
            CommonTextKeys.retry,
            retry,
            CommonTextKeys.back,
            back,
          ),
        };
    final busy = controller.busy;
    return PhoneStepPage(
      showBack: true,
      onBack: busy ? null : back,
      above: Padding(padding: const EdgeInsets.only(top: 14, bottom: 10), child: PhoneStatusIcon(tone: tone)),
      title: context.t(title),
      subtitle: context.t(text),
      contentGap: 12,
      action: _button(context.t(actionKey), onAction, busy: busy),
      link: linkKey == null ? null : PhoneQuietLink(label: context.t(linkKey), onPressed: busy ? null : onLink),
      children: [Text(context.t(help), style: JitanMobileTextStyles.detail)],
    );
  }
}
