import 'package:flutter/material.dart';
import 'package:jitan_core/jitan_core.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../auth/auth_controller.dart';
import '../auth/auth_flow.dart';
import '../home/home_screen.dart';
import '../l10n/employee_text_keys.dart';
import '../onboarding/onboarding_controller.dart';
import '../onboarding/onboarding_flow.dart';
import '../profile/profile_screens.dart';
import 'employee_services.dart';

/// Where the app is. Signed out has two ways in: onboarding (first time,
/// with a temporary onboarding QR, which signs the device in by itself) and sign-in
/// (already activated: new device, reinstall, expired session, sign-out).
enum _Phase { restoring, onboarding, signIn, signedIn }

/// The Employee app. A stored session opens Home directly. After sign-out or
/// an ended session (also after a restart) the app opens sign-in; a fresh
/// install opens onboarding.
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
  AuthController? _auth;
  EmployeeAccount? _account;

  @override
  void initState() {
    super.initState();
    _restore();
  }

  @override
  void dispose() {
    _onboarding?.dispose();
    _auth?.dispose();
    super.dispose();
  }

  Future<void> _restore() async {
    final session = _services.session;
    final signedIn = await session.restore();
    final returning = !signedIn && await session.hasSignedInBefore();
    if (!mounted) return;
    if (signedIn) {
      _enterSignedIn(null);
    } else if (returning) {
      _startSignIn();
    } else {
      _startOnboarding();
    }
  }

  /// Drops the signed-out flows. Disposed after the frame: the flow being
  /// replaced may still be finishing the call that ended it.
  void _disposeFlows() {
    final onboarding = _onboarding;
    final auth = _auth;
    _onboarding = null;
    _auth = null;
    if (onboarding == null && auth == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      onboarding?.dispose();
      auth?.dispose();
    });
  }

  void _startOnboarding() {
    _disposeFlows();
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

  void _startSignIn() {
    _disposeFlows();
    final auth = AuthController(
      authApi: _services.authApi,
      recoveryApi: _services.recoveryApi,
      session: _services.session,
      onSignedIn: _enterSignedIn,
    );
    setState(() {
      _account = null;
      _auth = auth;
      _phase = _Phase.signIn;
    });
  }

  void _enterSignedIn(EmployeeAccount? account) {
    _disposeFlows();
    setState(() {
      _account = account;
      _phase = _Phase.signedIn;
    });
    _applyUserLanguage();
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

  void _finishOnboarding() => _enterSignedIn(_onboarding?.account);

  /// Sign-out, or the server no longer accepts the session (expired,
  /// password changed elsewhere, access reset, account disabled).
  Future<void> _signOut() async {
    await _services.session.clear();
    if (mounted) _startSignIn();
  }

  ProfileContext _profileFor(EmployeeAccount? account) => ProfileContext(
    account: account,
    meApi: _services.meApi,
    session: _services.session,
    settings: _services.settings,
    permissions: _services.permissions,
    onMethodChanged: _services.automaticRegistration.start,
    onSignOut: _signOut,
    onSessionEnded: _signOut,
  );

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
            qrScannerView: _services.qrScannerView,
            onFinished: _finishOnboarding,
            onSignIn: _startSignIn,
          ),
          _Phase.signIn => AuthFlow(
            controller: _auth!,
            onLeave: _startOnboarding,
            scannerView: _services.qrScannerView,
          ),
          _Phase.signedIn => HomeScreen(
            key: ValueKey(_account),
            meApi: _services.meApi,
            timeRegistrationsApi: _services.timeRegistrationsApi,
            presence: _services.presence,
            onReady: _services.automaticRegistration.start,
            clock: _services.clock,
            initialAccount: _account,
            onSessionEnded: _signOut,
            profileFor: _profileFor,
          ),
        },
      ),
    ),
  );
}
