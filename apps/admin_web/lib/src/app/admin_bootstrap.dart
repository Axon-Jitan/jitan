import 'package:flutter/material.dart';
import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:jitan_core/jitan_core.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../common/api_failure_text.dart';
import 'admin_app.dart';

/// Loads the user's translations before showing the app (I18N-01):
///
/// ```text
/// /me/language (none or not signed in → English) → bundle + English bundle → AdminApp
/// ```
///
/// If loading fails there is no text to show yet, so the error shows
/// translation keys (the end of the fallback chain) with a retry action.
class AdminBootstrap extends StatefulWidget {
  const AdminBootstrap({super.key, required this.translationService, required this.companiesApi});

  final TranslationService translationService;
  final CompaniesApi companiesApi;

  @override
  State<AdminBootstrap> createState() => _AdminBootstrapState();
}

class _AdminBootstrapState extends State<AdminBootstrap> {
  Translations? _translations;
  ApiClientException? _failure;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _failure = null);
    try {
      final service = widget.translationService;
      final translations = await service.load(await service.resolveUserLanguageCode());
      if (mounted) setState(() => _translations = translations);
    } on ApiClientException catch (failure) {
      if (mounted) setState(() => _failure = failure);
    }
  }

  @override
  Widget build(BuildContext context) {
    final translations = _translations;
    if (translations != null) {
      return TranslationScope(translations: translations, child: AdminApp(companiesApi: widget.companiesApi));
    }
    return TranslationScope(
      translations: Translations.keysOnly(),
      child: MaterialApp(
        theme: JitanTheme.light(),
        debugShowCheckedModeBanner: false,
        home: Builder(
          builder: (context) => Scaffold(body: _failure == null ? _loading() : _error(context, _failure!)),
        ),
      ),
    );
  }

  /// No label: no text is available until the bundle has loaded.
  Widget _loading() => const Center(child: CircularProgressIndicator());

  Widget _error(BuildContext context, ApiClientException failure) {
    final keys = failureTextKeysFor(failure);
    return JitanErrorState(
      title: context.t(keys.title),
      message: context.t(keys.message),
      retryLabel: context.t(CommonTextKeys.retry),
      onRetry: _load,
    );
  }
}
