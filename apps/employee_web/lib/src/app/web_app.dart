import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:jitan_core/jitan_core.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../auth/web_session.dart';
import '../l10n/employee_web_text_keys.dart';
import 'web_router.dart';
import 'web_services.dart';

/// Shows at once in built-in English, then the person's language when it has
/// arrived: rendering never waits for translations (I18N-01).
class WebApp extends StatefulWidget {
  const WebApp({super.key, required this.services, required this.translations, this.clock, this.initialLocation});

  final WebServices services;
  final TranslationService translations;
  final DateTime Function()? clock;
  final String? initialLocation;

  @override
  State<WebApp> createState() => _WebAppState();
}

class _WebAppState extends State<WebApp> {
  late Translations _text = widget.translations.cachedForCurrentUser() ?? Translations.english();
  late final GoRouter _router = buildWebRouter(
    services: widget.services,
    onLanguageChanged: _loadLanguage,
    clock: widget.clock,
    initialLocation: widget.initialLocation,
  );

  WebSession get _session => widget.services.session;

  @override
  void initState() {
    super.initState();
    if (_session.status == WebSessionStatus.checking) _session.restore();
    _session.addListener(_loadLanguage);
    _loadLanguage();
  }

  @override
  void dispose() {
    _session.removeListener(_loadLanguage);
    _router.dispose();
    super.dispose();
  }

  Future<void> _loadLanguage() async {
    if (_session.status != WebSessionStatus.signedIn) return;
    final text = await widget.translations.loadForCurrentUser();
    if (mounted && text.languageCode != _text.languageCode) setState(() => _text = text);
  }

  @override
  Widget build(BuildContext context) => TranslationScope(
    translations: _text,
    child: Builder(
      builder: (context) => MaterialApp.router(
        title: context.t(EmployeeWebTextKeys.appTitle),
        theme: JitanTheme.web(),
        routerConfig: _router,
        debugShowCheckedModeBanner: false,
      ),
    ),
  );
}
