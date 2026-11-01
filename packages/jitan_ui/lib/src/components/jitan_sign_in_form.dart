import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:jitan_core/jitan_core.dart';

import '../i18n/translation_scope.dart';
import '../theme/jitan_colors.dart';
import '../theme/jitan_text_styles.dart';
import 'jitan_field_decoration.dart';
import 'jitan_primary_button.dart';

/// Employee code and password (Figma `1469:2`, `1499:2`). Generic on purpose:
/// it never says whether the code or the password was wrong. [submit] answers
/// with the key of what went wrong, or `null` when signed in.
class JitanSignInForm extends StatefulWidget {
  const JitanSignInForm({super.key, required this.submit});

  final Future<String?> Function(String code, String password) submit;

  @override
  State<JitanSignInForm> createState() => _JitanSignInFormState();
}

class _JitanSignInFormState extends State<JitanSignInForm> {
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
    final error = await widget.submit(_code.text.trim(), _password.text);
    if (error == null) TextInput.finishAutofillContext();
    if (!mounted || error == null) return;
    setState(() {
      _busy = false;
      _error = error;
    });
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Semantics(header: true, child: Text(context.t(CommonTextKeys.signInTitle), style: JitanTextStyles.modalTitle)),
      const SizedBox(height: 4),
      Text(context.t(CommonTextKeys.signInText), style: JitanTextStyles.tableCell.copyWith(color: JitanColors.inkMuted)),
      const SizedBox(height: 28),
      AutofillGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            JitanFieldLabel(
              label: context.t(CommonTextKeys.signInCode),
              child: TextField(
                controller: _code,
                autofocus: true,
                enabled: !_busy,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.username],
                style: JitanTextStyles.inputText,
                decoration: jitanFieldDecoration(hintText: context.t(CommonTextKeys.signInCodeHint)),
              ),
            ),
            const SizedBox(height: 16),
            JitanFieldLabel(
              label: context.t(CommonTextKeys.signInPassword),
              child: TextField(
                controller: _password,
                enabled: !_busy,
                obscureText: _hidden,
                autofillHints: const [AutofillHints.password],
                onSubmitted: (_) => _signIn(),
                style: JitanTextStyles.inputText,
                decoration: jitanFieldDecoration(hintText: context.t(CommonTextKeys.signInPasswordHint)).copyWith(
                  suffixIcon: IconButton(
                    tooltip: context.t(_hidden ? CommonTextKeys.signInShowPassword : CommonTextKeys.signInHidePassword),
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
      JitanPrimaryButton(label: context.t(CommonTextKeys.signInAction), busy: _busy, onPressed: _ready ? _signIn : null),
    ],
  );
}
