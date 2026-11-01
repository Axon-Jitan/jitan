import 'package:flutter/material.dart';
import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:jitan_core/jitan_core.dart';
import 'package:jitan_ui/jitan_ui.dart';

import 'src/app/web_app.dart';
import 'src/app/web_services.dart';
import 'src/auth/web_session.dart';
import 'src/l10n/employee_web_text_keys.dart';

const _apiBaseUrl = String.fromEnvironment('JITAN_API_BASE_URL');

void main() {
  registerJitanFontLicenses();

  // Absolute, or relative to the page for hosting behind Nginx (`/api`). There
  // is no default, so a misconfigured build fails visibly.
  if (_apiBaseUrl.trim().isEmpty) {
    runApp(const _ConfigurationErrorApp());
    return;
  }
  final trimmed = _apiBaseUrl.trim();
  final apiBaseUri = Uri.base.resolve(trimmed.endsWith('/') ? trimmed : '$trimmed/');

  late final WebSession session;
  final transport = ApiTransport(
    baseUri: apiBaseUri,
    httpClient: SessionHttpClient(() => session.sessionRefused()),
    accessToken: () => session.token,
  );
  final me = MeApi(transport);
  final languages = LanguagesApi(transport);
  session = WebSession(auth: AuthApi(transport), me: me, store: browserSessionStore());
  runApp(
    WebApp(
      translations: TranslationService(languages),
      services: WebServices(
        session: session,
        times: TimeRegistrationsApi(transport),
        activity: ActivityApi(transport),
        me: me,
        languages: languages,
      ),
    ),
  );
}

/// A build without `JITAN_API_BASE_URL`.
class _ConfigurationErrorApp extends StatelessWidget {
  const _ConfigurationErrorApp();

  @override
  Widget build(BuildContext context) => TranslationScope(
    translations: Translations.english(),
    child: MaterialApp(
      theme: JitanTheme.web(),
      home: Builder(
        builder: (context) => Scaffold(body: Center(child: Text(context.t(EmployeeWebTextKeys.configError)))),
      ),
    ),
  );
}
