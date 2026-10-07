import 'package:flutter/material.dart';
import 'package:jitan_core/jitan_core.dart';
import 'package:jitan_ui/jitan_ui.dart';

import 'admin_app.dart';
import 'admin_services.dart';

/// Shows the app immediately: in the user's language if it is already in
/// the translation cache, otherwise in built-in English. Then switches to the
/// user's database language once it is confirmed and loaded (I18N-01).
///
/// Rendering never waits for, or depends on, the translation API: if the
/// user language or bundle cannot be loaded, the app simply stays in English
/// (the service logs why).
class AdminBootstrap extends StatefulWidget {
  const AdminBootstrap({super.key, required this.translationService, required this.services});

  final TranslationService translationService;
  final AdminServices services;

  @override
  State<AdminBootstrap> createState() => _AdminBootstrapState();
}

class _AdminBootstrapState extends State<AdminBootstrap> {
  late Translations _translations =
      widget.translationService.cachedForCurrentUser() ?? Translations.english();

  @override
  void initState() {
    super.initState();
    _loadUserLanguage();
  }

  Future<void> _loadUserLanguage() async {
    final translations = await widget.translationService.loadForCurrentUser();
    if (mounted && translations.languageCode != _translations.languageCode) {
      setState(() => _translations = translations);
    }
  }

  @override
  Widget build(BuildContext context) => TranslationScope(
        translations: _translations,
        child: AdminApp(services: widget.services),
      );
}
