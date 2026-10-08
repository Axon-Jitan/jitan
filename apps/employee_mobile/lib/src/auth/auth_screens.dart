import 'package:flutter/material.dart';
import 'package:jitan_core/jitan_core.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../l10n/employee_text_keys.dart';
import '../onboarding/qr_scanner_view.dart';
import '../widgets/mobile_widgets.dart';
import '../widgets/qr_camera_frame.dart';
import 'auth_controller.dart';
import 'password_rules.dart';

// Spacing measured from the Figma "Auth / …" frames (390 × 844).

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
  Widget build(BuildContext context) => BrandedScaffold(
    children: [
      BrandedHeader(title: context.t(EmployeeTextKeys.signInTitle), text: context.t(EmployeeTextKeys.signInText)),
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
      const SizedBox(height: 24),
      Row(
        children: [
          const Expanded(child: Divider(color: JitanColors.inputBorder, height: 1)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(context.t(EmployeeTextKeys.signInOr), style: JitanMobileTextStyles.caption.copyWith(fontSize: 10)),
          ),
          const Expanded(child: Divider(color: JitanColors.inputBorder, height: 1)),
        ],
      ),
      const SizedBox(height: 18),
      JitanMobileButton(
        label: context.t(EmployeeTextKeys.signInRecoverQr),
        size: JitanMobileButtonSize.compact,
        onPressed: widget.controller.openRecovery,
      ),
      const SizedBox(height: 24),
      NoteBox(
        title: context.t(EmployeeTextKeys.signInHelpTitle),
        text: context.t(EmployeeTextKeys.signInHelp),
        minHeight: 86,
      ),
      const SizedBox(height: 4),
      Center(
        child: TextButton(
          onPressed: widget.onUseQr,
          style: TextButton.styleFrom(foregroundColor: JitanColors.vermilion),
          child: Text(
            context.t(EmployeeTextKeys.signInUseQr),
            style: JitanMobileTextStyles.link.copyWith(fontSize: 11, color: JitanColors.vermilion),
          ),
        ),
      ),
    ],
  );
}

/// Auth / 02 Forgot password: asks for the employee code. Continue sends
/// nothing and resets nothing; it opens "Recover with QR", which tells the
/// employee to ask HR/Admin for a reset first.
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
  Widget build(BuildContext context) => BrandedScaffold(
    children: [
      BrandedHeader(title: context.t(EmployeeTextKeys.forgotTitle), text: context.t(EmployeeTextKeys.forgotText)),
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

/// Auth / 06 Recover with QR: embedded camera. The QR is accepted only
/// after HR/Admin "Reset account access"; otherwise it shows Auth / 06B
/// Recovery refused ("Account reset required") and scanning continues.
class RecoverWithQrScreen extends StatelessWidget {
  const RecoverWithQrScreen({super.key, required this.controller, required this.scannerView});

  final AuthController controller;
  final QrScannerView scannerView;

  @override
  Widget build(BuildContext context) {
    final refusal = controller.recoveryRefusal;
    final expired = refusal == RecoveryRefusal.qrExpiredOrUsed;
    final (noteTitle, noteText) = switch (refusal) {
      null => (EmployeeTextKeys.recoverNoteTitle, EmployeeTextKeys.recoverNoteText),
      RecoveryRefusal.resetRequired => (EmployeeTextKeys.recoverRefusedTitle, EmployeeTextKeys.recoverRefusedText),
      RecoveryRefusal.qrExpiredOrUsed => (EmployeeTextKeys.recoverExpiredNoteTitle, EmployeeTextKeys.recoverExpiredNoteText),
    };
    return BrandedScaffold(
      children: [
        // Auth / 06, 06B (refused) and 06C (QR expired or used).
        BrandedHeader(
          title: context.t(expired ? EmployeeTextKeys.recoverExpiredTitle : EmployeeTextKeys.recoverTitle),
          text: context.t(expired ? EmployeeTextKeys.recoverExpiredText : EmployeeTextKeys.recoverText),
        ),
        const SizedBox(height: 56),
        QrCameraFrame(
          scannerView: scannerView,
          onDetected: controller.submitRecoveryQr,
          busy: controller.busy,
          hint: context.t(expired ? EmployeeTextKeys.recoverExpiredScanHint : EmployeeTextKeys.recoverScanHint),
        ),
        if (refusal == RecoveryRefusal.resetRequired)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Text(
              context.t(EmployeeTextKeys.recoverRefused),
              textAlign: TextAlign.center,
              style: JitanMobileTextStyles.noteTitle.copyWith(color: JitanColors.errorStrong),
            ),
          )
        else
          const SizedBox(height: 26),
        Semantics(
          liveRegion: true,
          child: NoteBox(
            title: context.t(noteTitle),
            text: context.t(noteText),
            background: refusal != null ? JitanColors.errorSurface : JitanColors.warningSurface,
            foreground: refusal != null ? JitanColors.errorStrong : JitanColors.warning,
            textStyle: JitanMobileTextStyles.noteText.copyWith(fontSize: 9),
            minHeight: 94,
          ),
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
}

/// Auth / 07 Set new password after reset. "Set password & sign in" stores
/// the new password (Argon2id on the server) and signs this device in.
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
    final problem = widget.controller.passwordProblem;
    final showLabel = context.t(EmployeeTextKeys.passwordShow);
    final hideLabel = context.t(EmployeeTextKeys.passwordHide);
    return BrandedScaffold(
      children: [
        BrandedHeader(title: context.t(EmployeeTextKeys.newPasswordTitle), text: context.t(EmployeeTextKeys.newPasswordText)),
        const SizedBox(height: 70),
        AutofillGroup(
          child: Column(
            children: [
              PasswordField(
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
              const SizedBox(height: 26),
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
        const SizedBox(height: 38),
        NoteBox(
          title: context.t(EmployeeTextKeys.newPasswordNoteTitle),
          text: context.t(EmployeeTextKeys.newPasswordNoteText),
          textStyle: JitanMobileTextStyles.noteText.copyWith(fontSize: 9),
          minHeight: 86,
        ),
        const SizedBox(height: 50),
        JitanMobileButton(
          label: context.t(EmployeeTextKeys.newPasswordAction),
          style: JitanMobileButtonStyle.brand,
          size: JitanMobileButtonSize.compact,
          busy: widget.controller.busy,
          onPressed: _submit,
        ),
      ],
    );
  }
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
