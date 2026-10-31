import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../l10n/admin_text_keys.dart';
import 'admin_session.dart';
import 'sign_in_card.dart';

/// HR sign-in (Figma `1469:2`, wrong password `1469:22`). Generic on purpose:
/// it never says whether the code or the password was wrong.
class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key, required this.session});

  final AdminSession session;

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _code = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  bool _hidden = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _code.addListener(_changed);
    _password.addListener(_changed);
  }

  void _changed() => setState(() {});

  @override
  void dispose() {
    _code.dispose();
    _password.dispose();
    super.dispose();
  }

  bool get _ready => !_busy && _code.text.trim().isNotEmpty && _password.text.isNotEmpty;

  Future<void> _signIn() async {
    if (!_ready) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.session.signIn(_code.text.trim(), _password.text);
      TextInput.finishAutofillContext();
    } on ApiClientException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = switch ((e.kind, e.error?.code)) {
          (ApiFailureKind.network, _) => AdminTextKeys.signInErrorNetwork,
          (_, ApiErrorCode.invalidCredentials) => AdminTextKeys.signInErrorCredentials,
          (_, ApiErrorCode.accountInactive) => AdminTextKeys.signInErrorInactive,
          _ => AdminTextKeys.signInErrorServer,
        };
      });
    }
  }

  @override
  Widget build(BuildContext context) => SignInCard(
    footnote: context.t(AdminTextKeys.signInForgot),
    children: [
      Semantics(header: true, child: Text(context.t(AdminTextKeys.signInTitle), style: JitanTextStyles.modalTitle)),
      const SizedBox(height: 4),
      Text(context.t(AdminTextKeys.signInText), style: JitanTextStyles.tableCell.copyWith(color: JitanColors.inkMuted)),
      const SizedBox(height: 28),
      AutofillGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            JitanFieldLabel(
              label: context.t(AdminTextKeys.signInCode),
              child: TextField(
                controller: _code,
                autofocus: true,
                enabled: !_busy,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.username],
                style: JitanTextStyles.inputText,
                decoration: jitanFieldDecoration(hintText: context.t(AdminTextKeys.signInCodeHint)),
              ),
            ),
            const SizedBox(height: 16),
            JitanFieldLabel(
              label: context.t(AdminTextKeys.signInPassword),
              child: TextField(
                controller: _password,
                enabled: !_busy,
                obscureText: _hidden,
                autofillHints: const [AutofillHints.password],
                onSubmitted: (_) => _signIn(),
                style: JitanTextStyles.inputText,
                decoration: jitanFieldDecoration(hintText: context.t(AdminTextKeys.signInPasswordHint)).copyWith(
                  suffixIcon: IconButton(
                    tooltip: context.t(_hidden ? AdminTextKeys.signInShowPassword : AdminTextKeys.signInHidePassword),
                    icon: Icon(_hidden ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 18),
                    onPressed: () => setState(() => _hidden = !_hidden),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      SizedBox(height: _error == null ? 24 : 12),
      if (_error case final error?) ...[
        Semantics(
          liveRegion: true,
          child: Text(context.t(error), style: JitanTextStyles.tableCell.copyWith(fontSize: 13, color: JitanColors.errorStrong)),
        ),
        const SizedBox(height: 16),
      ],
      JitanPrimaryButton(
        label: context.t(AdminTextKeys.signInAction),
        busy: _busy,
        onPressed: _ready ? _signIn : null,
      ),
    ],
  );
}
