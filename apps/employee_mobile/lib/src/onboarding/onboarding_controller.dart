import 'package:flutter/foundation.dart';
import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:jitan_core/jitan_core.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:logging/logging.dart';

import '../auth/password_rules.dart';
import '../device/device_settings.dart';
import '../device/permissions_gateway.dart';
import '../device/session_manager.dart';

export '../auth/password_rules.dart' show PasswordProblem;

final _log = Logger('onboarding');

/// The screens of onboarding, in order (Figma `01 — Employee App`).
enum OnboardingStep { welcome, join, confirm, language, method, permissions, password, ready, error }

/// Which Figma "Onboarding Error" screen to show.
enum OnboardingProblem {
  /// 01: unknown QR (deliberately says nothing about whether it exists).
  invalidQr,

  /// 02: this QR's onboarding was completed earlier.
  alreadyActivated,

  /// 03: inactive employee.
  accountUnavailable,

  /// 04: another device completed onboarding while this one was setting up.
  activatedElsewhere,

  /// 05: no answer to the final step. Retrying is safe (session recovery).
  networkFailure,

  /// 06: the service could not be reached before anything was changed.
  serverUnavailable,

  /// 07: onboarding completed, but this device could not store the session.
  sessionRecovery,
}

/// Drives onboarding: scan → confirm → language → registration method →
/// permissions → password → ready (the session is created with the
/// password, so no sign-in follows).
///
/// Rules from the server (ONB-01, ONB-05): a QR whose onboarding is complete
/// never restarts it; only one device can complete it; repeating the final
/// step with the same password after a lost response signs in again.
class OnboardingController extends ChangeNotifier {
  OnboardingController({
    required this._onboardingApi,
    required this._languagesApi,
    required this._session,
    required this._settings,
    required this._permissions,
    required this._onLanguageChosen,
  });

  final OnboardingApi _onboardingApi;
  final LanguagesApi _languagesApi;
  final SessionManager _session;
  final DeviceSettings _settings;
  final PermissionsGateway _permissions;
  final Future<void> Function(String languageCode) _onLanguageChosen;

  OnboardingStep _step = OnboardingStep.welcome;
  OnboardingStep get step => _step;

  /// True while a request or permission prompt is running.
  bool _busy = false;
  bool get busy => _busy;

  OnboardingProblem? _problem;
  OnboardingProblem? get problem => _problem;

  String? _qrCode;
  EmployeeAccount? _account;
  EmployeeAccount? get account => _account;

  List<Language> _languages = const [];

  /// Languages to choose from; English is always first and always present.
  List<Language> get languages => _languages;
  bool _languagesFailed = false;
  bool get languagesFailed => _languagesFailed;
  bool _languageInvalid = false;
  bool get languageInvalid => _languageInvalid;
  String _languageCode = englishLanguageCode;
  String get languageCode => _languageCode;

  RegistrationMethod _method = RegistrationMethod.automatic;
  RegistrationMethod get method => _method;

  bool? _locationGranted;

  /// `false` when automatic registration was chosen but location was refused.
  bool get locationMissing => _method == RegistrationMethod.automatic && _locationGranted == false;

  PasswordProblem? _passwordProblem;
  PasswordProblem? get passwordProblem => _passwordProblem;

  /// Kept in memory only between "Continue" and a successful sign-in, so a
  /// failed final step can be retried without retyping. Never stored.
  String? _pendingPassword;

  // ── Navigation ─────────────────────────────────────────────────────────

  void getStarted() => _go(OnboardingStep.join);

  /// The previous screen, or `false` when there is none (leave the app).
  bool back() {
    if (_busy) return true;
    final previous = switch (_step) {
      OnboardingStep.welcome => null,
      OnboardingStep.join => OnboardingStep.welcome,
      OnboardingStep.confirm => OnboardingStep.join,
      OnboardingStep.language => OnboardingStep.confirm,
      OnboardingStep.method => OnboardingStep.language,
      OnboardingStep.permissions => OnboardingStep.method,
      OnboardingStep.password => OnboardingStep.permissions,
      // Signed in: nothing to go back to.
      OnboardingStep.ready => null,
      OnboardingStep.error => OnboardingStep.join,
    };
    if (previous == null) return false;
    if (previous == OnboardingStep.join) _forgetAccount();
    _go(previous);
    return true;
  }

  // ── 02 Join: scan ──────────────────────────────────────────────────────

  /// Checks a scanned QR with the server and shows the account to confirm.
  Future<void> submitQr(String qrCode) async {
    _qrCode = qrCode;
    await _run(() async {
      _account = await _onboardingApi.start(qrCode);
      _go(OnboardingStep.confirm);
    }, onError: (e) => _show(_problemForStart(e)));
  }

  // ── 04 Confirm ─────────────────────────────────────────────────────────

  void confirmAccount() {
    _go(OnboardingStep.language);
    if (_languages.isEmpty) _loadLanguages();
  }

  /// "Not you? Go back": scan again.
  void rejectAccount() {
    _forgetAccount();
    _go(OnboardingStep.join);
  }

  // ── Language ───────────────────────────────────────────────────────────

  Future<void> _loadLanguages() async {
    _languages = const [Language(id: 0, code: englishLanguageCode, name: 'English')];
    _languagesFailed = false;
    notifyListeners();
    try {
      final fromServer = await _languagesApi.listLanguages();
      _languages = [_languages.first, ...fromServer.where((l) => l.code != englishLanguageCode)];
    } on ApiClientException catch (e) {
      _log.warning('Languages could not be loaded ($e); English stays available.');
      _languagesFailed = true;
    }
    notifyListeners();
  }

  /// Applies [code] to the app straight away (English needs no download).
  Future<void> chooseLanguage(String code) async {
    _languageCode = code;
    _languageInvalid = false;
    notifyListeners();
    await _onLanguageChosen(code);
  }

  void confirmLanguage() => _go(OnboardingStep.method);

  // ── 05 Registration method ─────────────────────────────────────────────

  void chooseMethod(RegistrationMethod method) {
    _method = method;
    notifyListeners();
  }

  void confirmMethod() => _go(OnboardingStep.permissions);

  // ── 06 Permissions ─────────────────────────────────────────────────────

  /// Asks for location (automatic registration only), then notifications.
  /// A refusal never blocks onboarding; the Ready screen says what is missing.
  Future<void> requestPermissions() async {
    _busy = true;
    notifyListeners();
    try {
      _locationGranted = _method == RegistrationMethod.automatic ? await _permissions.requestLocation() : null;
      await _permissions.requestNotifications();
      await _settings.setRegistrationMethod(_method);
    } catch (e) {
      _log.warning('Permission request failed ($e); continuing.');
    } finally {
      _busy = false;
    }
    _go(OnboardingStep.password);
  }

  // ── 07 Password → complete → signed in ─────────────────────────────────

  /// Checks the password locally, then completes onboarding on the server,
  /// which also signs this device in.
  Future<void> submitPassword(String password, String confirmation) async {
    final problem = PasswordRules.check(password, confirmation);
    if (problem != null) {
      _passwordProblem = problem;
      notifyListeners();
      return;
    }
    _passwordProblem = null;
    _pendingPassword = password;
    await _complete();
  }

  /// The error screen's main action.
  Future<void> retry() async {
    switch (_problem) {
      case OnboardingProblem.networkFailure || OnboardingProblem.sessionRecovery when _pendingPassword != null:
        await _complete();
      case OnboardingProblem.serverUnavailable when _qrCode != null:
        await submitQr(_qrCode!);
      default:
        _forgetAccount();
        _go(OnboardingStep.join);
    }
  }

  Future<void> _complete() async {
    final qr = _qrCode;
    final password = _pendingPassword;
    if (qr == null || password == null) return;
    await _run(() async {
      final result = await _onboardingApi.complete(
        OnboardingCompleteRequest(
          qrCode: qr,
          password: password,
          deviceId: await _session.deviceId(),
          languageCode: _languageCode,
        ),
      );
      _account = result.account;
      try {
        await _session.save(result.session);
      } catch (e) {
        _log.severe('Could not store the session on this device ($e).');
        _show(OnboardingProblem.sessionRecovery);
        return;
      }
      _pendingPassword = null;
      _go(OnboardingStep.ready);
    }, onError: _handleCompleteError);
  }

  void _handleCompleteError(ApiClientException e) {
    final error = e.error;
    if (e.kind != ApiFailureKind.server || error == null || (e.statusCode ?? 500) >= 500) {
      // No reliable answer: the server may have completed. Retrying is safe.
      _show(OnboardingProblem.networkFailure);
      return;
    }
    switch (error.code) {
      case ApiErrorCode.validationFailed when error.field == OnboardingCompleteRequest.fieldPassword:
        _pendingPassword = null;
        _passwordProblem = PasswordProblem.rejected;
        _go(OnboardingStep.password);
      case ApiErrorCode.validationFailed when error.field == OnboardingCompleteRequest.fieldLanguageCode:
        _languageInvalid = true;
        _go(OnboardingStep.language);
      case ApiErrorCode.onboardingAlreadyCompleted:
        _pendingPassword = null;
        _show(OnboardingProblem.activatedElsewhere);
      default:
        _pendingPassword = null;
        _show(_problemForStart(e));
    }
  }

  static OnboardingProblem _problemForStart(ApiClientException e) => switch (e.error?.code) {
    ApiErrorCode.invalidQrCode => OnboardingProblem.invalidQr,
    ApiErrorCode.onboardingAlreadyCompleted => OnboardingProblem.alreadyActivated,
    ApiErrorCode.accountInactive => OnboardingProblem.accountUnavailable,
    _ => OnboardingProblem.serverUnavailable,
  };

  // ── Helpers ────────────────────────────────────────────────────────────

  Future<void> _run(Future<void> Function() action, {required void Function(ApiClientException) onError}) async {
    if (_busy) return;
    _busy = true;
    notifyListeners();
    try {
      await action();
    } on ApiClientException catch (e) {
      _log.info('Onboarding request failed: $e');
      _busy = false;
      onError(e);
      return;
    }
    _busy = false;
    notifyListeners();
  }

  void _show(OnboardingProblem problem) {
    _problem = problem;
    _go(OnboardingStep.error);
  }

  void _go(OnboardingStep step) {
    _step = step;
    if (step != OnboardingStep.error) _problem = null;
    notifyListeners();
  }

  void _forgetAccount() {
    _qrCode = null;
    _account = null;
    _pendingPassword = null;
  }

  @override
  void dispose() {
    _pendingPassword = null;
    super.dispose();
  }
}
