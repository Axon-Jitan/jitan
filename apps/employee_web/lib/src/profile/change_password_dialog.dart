import 'package:flutter/material.dart';
import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../auth/web_session.dart';
import '../l10n/employee_web_text_keys.dart';

Future<void> showChangePasswordDialog(BuildContext context, {required WebSession session}) => showJitanModal<void>(
  context,
  barrierDismissible: false,
  builder: (_) => _ChangePasswordDialog(session: session),
);

/// Change password (Figma `1499:928`): the server checks the current one and
/// its rules; the sign-in carries on with the new session it gives back.
class _ChangePasswordDialog extends StatefulWidget {
  const _ChangePasswordDialog({required this.session});

  final WebSession session;

  @override
  State<_ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<_ChangePasswordDialog> {
  static const _minLength = 8;

  final _current = TextEditingController();
  final _next = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_next.text.length < _minLength) {
      setState(() => _error = EmployeeWebTextKeys.passwordTooShort);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.session.changePassword(_current.text, _next.text);
      if (mounted) Navigator.of(context).pop();
    } on ApiClientException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = switch (e.error?.code) {
          ApiErrorCode.invalidCredentials => EmployeeWebTextKeys.passwordWrong,
          ApiErrorCode.validationFailed => EmployeeWebTextKeys.passwordTooShort,
          _ => EmployeeWebTextKeys.failed,
        };
      });
    }
  }

  @override
  Widget build(BuildContext context) => JitanModal(
    width: 440,
    title: context.t(EmployeeWebTextKeys.passwordTitle),
    onClose: () => Navigator.of(context).pop(),
    body: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 16,
      children: [
        JitanTextField(label: context.t(EmployeeWebTextKeys.passwordCurrent), controller: _current, obscureText: true),
        JitanTextField(
          label: context.t(EmployeeWebTextKeys.passwordNew),
          controller: _next,
          obscureText: true,
          hintText: context.t(EmployeeWebTextKeys.passwordHint),
        ),
        if (_error case final error?) Text(context.t(error), style: JitanTextStyles.fieldError),
      ],
    ),
    actions: [
      JitanSecondaryButton(label: context.t(EmployeeWebTextKeys.cancel), onPressed: () => Navigator.of(context).pop()),
      JitanPrimaryButton(label: context.t(EmployeeWebTextKeys.save), busy: _busy, onPressed: _busy ? null : _save),
    ],
  );
}
