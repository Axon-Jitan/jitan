import 'package:flutter/material.dart';
import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:jitan_core/jitan_core.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../l10n/employee_web_text_keys.dart';
import 'web_session.dart';

/// Sign in (Figma `1499:2`). Forgetting a password goes through HR: there is
/// no reset by email, because no email is needed.
class SignInScreen extends StatelessWidget {
  const SignInScreen({super.key, required this.session});

  final WebSession session;

  Future<String?> _submit(String code, String password) async {
    try {
      await session.signIn(code, password);
      return null;
    } on ApiClientException catch (e) {
      return switch ((e.kind, e.error?.code)) {
        (ApiFailureKind.network, _) => CommonTextKeys.signInErrorNetwork,
        (_, ApiErrorCode.invalidCredentials) => CommonTextKeys.signInErrorCredentials,
        (_, ApiErrorCode.accountInactive) => EmployeeWebTextKeys.signInInactive,
        (_, ApiErrorCode.tooManyAttempts) => CommonTextKeys.signInErrorTooMany,
        _ => CommonTextKeys.signInErrorServer,
      };
    }
  }

  @override
  Widget build(BuildContext context) => JitanSignInCard(
    footnote: context.t(EmployeeWebTextKeys.signInForgot),
    children: [JitanSignInForm(submit: _submit)],
  );
}
