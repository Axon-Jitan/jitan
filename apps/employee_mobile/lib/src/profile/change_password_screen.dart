import 'package:flutter/material.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../auth/password_rules.dart';
import '../l10n/employee_text_keys.dart';
import '../widgets/mobile_widgets.dart';
import '../widgets/phone_step_page.dart';
import 'change_password_controller.dart';
import 'profile_context.dart';

/// Profile → Password (Figma `1612:364`, 2026-11-13): the current password,
/// the new one twice, on one page. Pops `true` once the server confirmed the
/// change; Profile then says so.
class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key, required this.profile, required this.bottomBar});

  final ProfileContext profile;
  final Widget bottomBar;

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  late final _controller = ChangePasswordController(meApi: widget.profile.meApi, session: widget.profile.session, onSessionEnded: _sessionEnded);
  final _current = TextEditingController();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();

  void _sessionEnded() {
    Navigator.of(context).popUntil((route) => route.isFirst);
    widget.profile.onSessionEnded();
  }

  @override
  void initState() {
    super.initState();
    // "Change password" waits until every field has something in it.
    for (final field in [_current, _password, _confirmation]) {
      field.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _current.dispose();
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  bool get _filled => _current.text.isNotEmpty && _password.text.isNotEmpty && _confirmation.text.isNotEmpty;

  Future<void> _submit() async {
    if (!_filled) return;
    final navigator = Navigator.of(context);
    final changed = await _controller.submit(current: _current.text, password: _password.text, confirmation: _confirmation.text);
    if (changed) navigator.pop(true);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _controller,
    builder: (context, _) {
      final problem = _controller.problem;
      final busy = _controller.busy;
      final showLabel = context.t(EmployeeTextKeys.passwordShow);
      final hideLabel = context.t(EmployeeTextKeys.passwordHide);
      return PhoneStepPage(
        showBack: true,
        onBack: busy ? null : () => Navigator.of(context).maybePop(),
        title: context.t(EmployeeTextKeys.changePasswordTitle),
        subtitle: context.t(EmployeeTextKeys.changePasswordText),
        note: _controller.failure == ChangePasswordFailure.unreachable
            ? Semantics(
                liveRegion: true,
                child: Text(
                  context.t(EmployeeTextKeys.changePasswordNetworkError),
                  style: JitanMobileTextStyles.detail.copyWith(color: JitanColors.errorStrong),
                ),
              )
            : null,
        action: JitanMobileButton(
          label: context.t(EmployeeTextKeys.passwordChangeAction),
          size: JitanMobileButtonSize.phone,
          busy: busy,
          onPressed: _filled ? _submit : null,
        ),
        bottomBar: widget.bottomBar,
        children: [
          AutofillGroup(
            child: Column(
              spacing: 18,
              children: [
                PasswordField(
                  phone: true,
                  controller: _current,
                  label: context.t(EmployeeTextKeys.changePasswordCurrentLabel),
                  hint: context.t(EmployeeTextKeys.changePasswordCurrentHint),
                  showLabel: showLabel,
                  hideLabel: hideLabel,
                  error: _controller.currentPasswordWrong ? context.t(EmployeeTextKeys.changePasswordCurrentWrong) : null,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.password],
                ),
                PasswordField(
                  phone: true,
                  controller: _password,
                  label: context.t(EmployeeTextKeys.changePasswordLabel),
                  hint: context.t(EmployeeTextKeys.changePasswordNewHint),
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
                PasswordField(
                  phone: true,
                  controller: _confirmation,
                  label: context.t(EmployeeTextKeys.changePasswordConfirmLabel),
                  hint: context.t(EmployeeTextKeys.changePasswordConfirmHint),
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
          Text(context.t(EmployeeTextKeys.changePasswordNote), style: JitanMobileTextStyles.detail),
        ],
      );
    },
  );
}
