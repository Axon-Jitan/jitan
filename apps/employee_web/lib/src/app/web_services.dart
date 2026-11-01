import 'package:jitan_api_client/jitan_api_client.dart';

import '../auth/web_session.dart';

/// Everything the pages talk to.
class WebServices {
  const WebServices({
    required this.session,
    required this.times,
    required this.activity,
    required this.me,
    required this.languages,
  });

  final WebSession session;
  final TimeRegistrationsApi times;
  final ActivityApi activity;
  final MeApi me;
  final LanguagesApi languages;
}
