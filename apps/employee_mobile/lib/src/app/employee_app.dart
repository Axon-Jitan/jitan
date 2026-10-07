import 'package:flutter/material.dart';
import 'package:jitan_core/jitan_core.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../home/home_screen.dart';
import '../l10n/employee_text_keys.dart';
import '../onboarding/onboarding_controller.dart';
import '../onboarding/onboarding_flow.dart';
import 'employee_services.dart';

enum _Phase { restoring, onboarding, signedIn }

/// The Employee app. A stored session opens Home directly; without one the
/// employee onboards, which signs this device in (no separate sign-in).
///
/// Translations: English is built in and shown at once. A signed-in user's
/// language loads in the background; during onboarding the chosen language
/// applies as soon as it is picked (I18N-01).
class EmployeeApp extends StatefulWidget {
  const EmployeeApp({super.key, required this.services});

  final EmployeeServices services;

  @override
  State<EmployeeApp> createState() => _EmployeeAppState();
}

class _EmployeeAppState extends State<EmployeeApp> {
  EmployeeServices get _services => widget.services;

  _Phase _phase = _Phase.restoring;
  late Translations _translations = _services.translationService.cachedForCurrentUser() ?? Translations.english();
  OnboardingController? _onboarding;
  EmployeeAccount? _account;

  @override
  void initState() {
    super.initState();
    _restore();
  }

  @override
  void dispose() {
    _onboarding?.dispose();
    super.dispose();
  }

  Future<void> _restore() async {
    final signedIn = await _services.session.restore();
    if (!mounted) return;
    if (signedIn) {
      setState(() => _phase = _Phase.signedIn);
      await _applyUserLanguage();
    } else {
      _startOnboarding();
    }
  }

  void _startOnboarding() {
    _onboarding?.dispose();
    setState(() {
      _account = null;
      _onboarding = OnboardingController(
        onboardingApi: _services.onboardingApi,
        languagesApi: _services.languagesApi,
        session: _services.session,
        settings: _services.settings,
        permissions: _services.permissions,
        onLanguageChosen: _applyLanguage,
      );
      _phase = _Phase.onboarding;
    });
  }

  Future<void> _applyLanguage(String code) async {
    final translations = await _services.translationService.load(code);
    if (mounted) setState(() => _translations = translations);
  }

  Future<void> _applyUserLanguage() async {
    final translations = await _services.translationService.loadForCurrentUser();
    if (mounted && translations.languageCode != _translations.languageCode) {
      setState(() => _translations = translations);
    }
  }

  void _finishOnboarding() {
    final account = _onboarding?.account;
    _onboarding?.dispose();
    setState(() {
      _onboarding = null;
      _account = account;
      _phase = _Phase.signedIn;
    });
  }

  Future<void> _sessionEnded() async {
    await _services.session.clear();
    if (mounted) _startOnboarding();
  }

  @override
  Widget build(BuildContext context) => TranslationScope(
    translations: _translations,
    child: Builder(
      builder: (context) => MaterialApp(
        title: context.t(EmployeeTextKeys.appTitle),
        debugShowCheckedModeBanner: false,
        theme: JitanTheme.light(),
        home: switch (_phase) {
          _Phase.restoring => const Scaffold(backgroundColor: JitanColors.warmWhite),
          _Phase.onboarding => OnboardingFlow(
            controller: _onboarding!,
            scanQr: _services.scanQr,
            onFinished: _finishOnboarding,
          ),
          _Phase.signedIn => HomeScreen(
            meApi: _services.meApi,
            initialAccount: _account,
            onSessionEnded: _sessionEnded,
          ),
        },
      ),
    ),
  );
}
