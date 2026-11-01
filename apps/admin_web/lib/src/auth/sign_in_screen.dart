import 'package:flutter/material.dart';
import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:jitan_core/jitan_core.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../l10n/admin_text_keys.dart';
import 'admin_session.dart';

/// HR sign-in (Figma `1469:2`, wrong password `1469:22`).
class SignInScreen extends StatelessWidget {
  const SignInScreen({super.key, required this.session});

  final AdminSession session;

  Future<String?> _submit(String code, String password) async {
    try {
      await session.signIn(code, password);
      return null;
    } on ApiClientException catch (e) {
      return switch ((e.kind, e.error?.code)) {
        (ApiFailureKind.network, _) => CommonTextKeys.signInErrorNetwork,
        (_, ApiErrorCode.invalidCredentials) => CommonTextKeys.signInErrorCredentials,
        (_, ApiErrorCode.accountInactive) => AdminTextKeys.signInErrorInactive,
        (_, ApiErrorCode.tooManyAttempts) => CommonTextKeys.signInErrorTooMany,
        _ => CommonTextKeys.signInErrorServer,
      };
    }
  }

  @override
  Widget build(BuildContext context) => JitanSignInCard(
    footnote: context.t(AdminTextKeys.signInForgot),
    children: [JitanSignInForm(submit: _submit)],
  );
}
