import 'package:flutter/material.dart';
import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:jitan_core/jitan_core.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../auth/password_rules.dart';
import '../device/session_manager.dart';
import '../l10n/employee_text_keys.dart';
import '../widgets/mobile_widgets.dart';
import 'change_password_controller.dart';

/// What the profile screens need from the app.
class ProfileContext {
  const ProfileContext({
    required this.account,
    required this.meApi,
    required this.session,
    required this.onSignOut,
    required this.onSessionEnded,
  });

  final EmployeeAccount? account;
  final MeApi meApi;
  final SessionManager session;

  /// Confirmed "Sign out".
  final VoidCallback onSignOut;

  /// The server no longer accepts this device's session.
  final VoidCallback onSessionEnded;
}

/// Back arrow + title + subtitle of the Profile sub-screens.
class _SubHeader extends StatelessWidget {
  const _SubHeader({required this.title, this.text});

  final String title;
  final String? text;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      IconButton(
        tooltip: context.t(CommonTextKeys.back),
        padding: EdgeInsets.zero,
        alignment: Alignment.centerLeft,
        icon: const Icon(Icons.chevron_left, size: 30, color: JitanColors.ink),
        onPressed: () => Navigator.of(context).maybePop(),
      ),
      Expanded(
        child: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                header: true,
                child: Text(title, style: JitanMobileTextStyles.formTitle.copyWith(fontSize: 24)),
              ),
              if (text != null) ...[
                const SizedBox(height: 6),
                Text(text!, style: JitanMobileTextStyles.caption),
              ],
            ],
          ),
        ),
      ),
    ],
  );
}

class _Page extends StatelessWidget {
  const _Page({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: JitanColors.warmWhite,
    body: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(OnboardingPage.margin, 10, OnboardingPage.margin, 24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
      ),
    ),
  );
}

/// A white row with a label and a chevron (Figma "Profile row / …").
class _ProfileRow extends StatelessWidget {
  const _ProfileRow({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: JitanColors.surface,
    borderRadius: BorderRadius.circular(14),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: SizedBox(
        height: 56,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: [
              Expanded(child: Text(label, style: JitanMobileTextStyles.noteTitle.copyWith(fontSize: 12))),
              const Icon(Icons.chevron_right, color: JitanColors.inkMuted),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Profile / Employee, with the parts that exist so far: identity, employee
/// code, Password & web login, Sign out (DESIGN-CLARIFY-AUTH).
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key, required this.profile});

  final ProfileContext profile;

  @override
  Widget build(BuildContext context) {
    final account = profile.account;
    final name = [account?.firstName, account?.lastName].whereType<String>().where((n) => n.isNotEmpty).join(' ');
    return _Page(
      children: [
        Row(
          children: [
            IconButton(
              tooltip: context.t(CommonTextKeys.back),
              padding: EdgeInsets.zero,
              alignment: Alignment.centerLeft,
              icon: const Icon(Icons.chevron_left, size: 30, color: JitanColors.ink),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
            const JitanWordmark(),
          ],
        ),
        const SizedBox(height: 20),
        Semantics(
          header: true,
          child: Text(context.t(EmployeeTextKeys.profileTitle), style: JitanMobileTextStyles.title.copyWith(fontSize: 28)),
        ),
        const SizedBox(height: 20),
        if (account != null) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: JitanColors.surface, borderRadius: BorderRadius.circular(20)),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: JitanColors.ink,
                  child: Text(
                    (name.isEmpty ? account.code : name).characters.first.toUpperCase(),
                    style: JitanMobileTextStyles.cardTitle.copyWith(fontSize: 18, color: JitanColors.warmWhite),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name.isEmpty ? account.code : name, style: JitanMobileTextStyles.cardTitle.copyWith(fontSize: 17)),
                      const SizedBox(height: 6),
                      Text(account.companies.join(', '), style: JitanMobileTextStyles.caption),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            height: 54,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(color: JitanColors.surface, borderRadius: BorderRadius.circular(16)),
            child: Row(
              children: [
                Expanded(
                  child: Text(context.t(EmployeeTextKeys.profileCode), style: JitanMobileTextStyles.caption.copyWith(fontSize: 11)),
                ),
                Text(account.code, style: JitanMobileTextStyles.noteTitle.copyWith(fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
        _ProfileRow(
          label: context.t(EmployeeTextKeys.profilePasswordRow),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => PasswordWebLoginScreen(profile: profile)),
          ),
        ),
        const SizedBox(height: 28),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => SignOutScreen(onSignOut: profile.onSignOut)),
            ),
            style: TextButton.styleFrom(foregroundColor: JitanColors.errorStrong, padding: EdgeInsets.zero),
            child: Text(
              context.t(EmployeeTextKeys.profileSignOut),
              style: JitanMobileTextStyles.link.copyWith(fontSize: 12, color: JitanColors.errorStrong),
            ),
          ),
        ),
      ],
    );
  }
}

/// Profile / Password & web login.
class PasswordWebLoginScreen extends StatelessWidget {
  const PasswordWebLoginScreen({super.key, required this.profile});

  final ProfileContext profile;

  Future<void> _change(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final text = context.t(EmployeeTextKeys.changePasswordSuccess);
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => ChangePasswordScreen(profile: profile)),
    );
    if (changed ?? false) messenger.showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) => _Page(
    children: [
      _SubHeader(
        title: context.t(EmployeeTextKeys.passwordScreenTitle),
        text: context.t(EmployeeTextKeys.passwordScreenText),
      ),
      const SizedBox(height: 40),
      Container(
        constraints: const BoxConstraints(minHeight: 120),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: JitanColors.surface, borderRadius: BorderRadius.circular(18)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(context.t(EmployeeTextKeys.passwordStatusLabel), style: JitanMobileTextStyles.fieldLabel),
            const SizedBox(height: 12),
            Text(
              context.t(EmployeeTextKeys.passwordStatusValue),
              style: JitanMobileTextStyles.cardTitle.copyWith(color: JitanColors.success),
            ),
            const SizedBox(height: 8),
            Text(context.t(EmployeeTextKeys.passwordStatusText), style: JitanMobileTextStyles.noteText),
          ],
        ),
      ),
      const SizedBox(height: 30),
      JitanMobileButton(
        label: context.t(EmployeeTextKeys.passwordChangeAction),
        size: JitanMobileButtonSize.compact,
        onPressed: () => _change(context),
      ),
      const SizedBox(height: 26),
      NoteBox(
        title: context.t(EmployeeTextKeys.passwordHelpTitle),
        text: context.t(EmployeeTextKeys.passwordHelpText),
        titleStyle: JitanMobileTextStyles.noteTitle.copyWith(fontSize: 12),
        minHeight: 118,
      ),
    ],
  );
}

/// Figma "Profile / Change password": current password, new password twice.
/// Pops `true` once the server confirmed the change.
class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key, required this.profile});

  final ProfileContext profile;

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  late final _controller = ChangePasswordController(
    meApi: widget.profile.meApi,
    session: widget.profile.session,
    onSessionEnded: _sessionEnded,
  );
  final _current = TextEditingController();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();

  void _sessionEnded() {
    Navigator.of(context).popUntil((route) => route.isFirst);
    widget.profile.onSessionEnded();
  }

  @override
  void dispose() {
    _controller.dispose();
    _current.dispose();
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final navigator = Navigator.of(context);
    final changed = await _controller.submit(
      current: _current.text,
      password: _password.text,
      confirmation: _confirmation.text,
    );
    if (changed) navigator.pop(true);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _controller,
    builder: (context, _) {
      final problem = _controller.problem;
      final showLabel = context.t(EmployeeTextKeys.passwordShow);
      final hideLabel = context.t(EmployeeTextKeys.passwordHide);
      return _Page(
        children: [
          Row(
            children: [
              IconButton(
                tooltip: context.t(CommonTextKeys.back),
                padding: EdgeInsets.zero,
                alignment: Alignment.centerLeft,
                icon: const Icon(Icons.chevron_left, size: 30, color: JitanColors.ink),
                onPressed: () => Navigator.of(context).maybePop(),
              ),
              JitanWordmark(style: JitanMobileTextStyles.logo.copyWith(fontSize: 24)),
            ],
          ),
          const SizedBox(height: 24),
          Semantics(
            header: true,
            child: Text(context.t(EmployeeTextKeys.changePasswordTitle), style: JitanMobileTextStyles.formTitle),
          ),
          const SizedBox(height: 10),
          Text(context.t(EmployeeTextKeys.changePasswordText), style: JitanMobileTextStyles.caption),
          const SizedBox(height: 52),
          AutofillGroup(
            child: Column(
              children: [
                PasswordField(
                  controller: _current,
                  label: context.t(EmployeeTextKeys.changePasswordCurrentLabel),
                  hint: context.t(EmployeeTextKeys.changePasswordCurrentHint),
                  showLabel: showLabel,
                  hideLabel: hideLabel,
                  error: _controller.currentPasswordWrong
                      ? context.t(EmployeeTextKeys.changePasswordCurrentWrong)
                      : null,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.password],
                ),
                const SizedBox(height: 26),
                PasswordField(
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
                const SizedBox(height: 26),
                PasswordField(
                  controller: _confirmation,
                  label: context.t(EmployeeTextKeys.passwordConfirmLabel),
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
          if (_controller.failure == ChangePasswordFailure.unreachable) ...[
            const SizedBox(height: 20),
            Semantics(
              liveRegion: true,
              child: NoteBox(
                text: context.t(EmployeeTextKeys.changePasswordNetworkError),
                background: JitanColors.errorSurface,
                foreground: JitanColors.errorStrong,
                textStyle: JitanMobileTextStyles.cardText,
                padding: const EdgeInsets.all(14),
              ),
            ),
          ],
          const SizedBox(height: 40),
          NoteBox(
            title: context.t(EmployeeTextKeys.changePasswordRulesTitle),
            text: context.t(EmployeeTextKeys.changePasswordRulesText),
            textStyle: JitanMobileTextStyles.noteText.copyWith(fontSize: 9),
            minHeight: 86,
          ),
          const SizedBox(height: 34),
          JitanMobileButton(
            label: context.t(EmployeeTextKeys.passwordChangeAction),
            style: JitanMobileButtonStyle.brand,
            size: JitanMobileButtonSize.compact,
            busy: _controller.busy,
            onPressed: _submit,
          ),
        ],
      );
    },
  );
}

/// Profile / Sign out confirmation.
class SignOutScreen extends StatelessWidget {
  const SignOutScreen({super.key, required this.onSignOut});

  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) => _Page(
    children: [
      _SubHeader(title: context.t(EmployeeTextKeys.signOutTitle)),
      const SizedBox(height: 130),
      Container(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
        decoration: BoxDecoration(color: JitanColors.surface, borderRadius: BorderRadius.circular(22)),
        child: Column(
          children: [
            const StatusCircle(
              background: JitanColors.errorSurface,
              foreground: JitanColors.errorStrong,
              icon: Icons.north_east_rounded,
            ),
            const SizedBox(height: 20),
            Text(
              context.t(EmployeeTextKeys.signOutQuestion),
              style: JitanMobileTextStyles.identityName.copyWith(fontSize: 22),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 14),
            Text(
              context.t(EmployeeTextKeys.signOutText),
              style: JitanMobileTextStyles.caption.copyWith(fontSize: 11),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
      const SizedBox(height: 64),
      JitanMobileButton(
        label: context.t(EmployeeTextKeys.signOutTitle),
        style: JitanMobileButtonStyle.danger,
        onPressed: () {
          Navigator.of(context).popUntil((route) => route.isFirst);
          onSignOut();
        },
      ),
      const SizedBox(height: 12),
      JitanMobileButton(
        label: context.t(CommonTextKeys.cancel),
        style: JitanMobileButtonStyle.secondary,
        onPressed: () => Navigator.of(context).maybePop(),
      ),
    ],
  );
}
