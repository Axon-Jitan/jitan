import 'package:flutter/foundation.dart';
import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:logging/logging.dart';

import '../device/session_manager.dart';

final _log = Logger('auth');

/// Screens of the sign-in flow (Figma "Auth / 01 … 05").
enum AuthStep { signIn, forgotPassword, recovery, error }

/// Which "Auth / 03–05" error screen to show.
enum AuthProblem {
  /// 03: wrong code or password; deliberately does not say which.
  invalidCredentials,

  /// 04: inactive or MFD account (only reported for the correct password).
  accountUnavailable,

  /// 05: no answer or a server error. Retrying is safe: nothing changed.
  unreachable,
}

/// Sign-in with employee code + password, for an employee who is already
/// activated: new device, reinstall, expired session, sign-out, or sent
/// here from onboarding. Never used right after onboarding, which signs the
/// device in itself.
///
/// Forgot password (V1, HR/Admin-assisted): the employee code is asked for,
/// nothing is sent or reset, and the employee is told to contact HR/Admin,
/// or to change the password on a device where they are still signed in.
class AuthController extends ChangeNotifier {
  AuthController({required this._authApi, required this._session, required this._onSignedIn});

  final AuthApi _authApi;
  final SessionManager _session;

  /// The device is signed in: open Home.
  final void Function(EmployeeAccount account) _onSignedIn;

  AuthStep _step = AuthStep.signIn;
  AuthStep get step => _step;

  AuthProblem? _problem;
  AuthProblem? get problem => _problem;

  bool _busy = false;
  bool get busy => _busy;

  /// The employee code as last entered; kept across the flow's screens.
  String _code = '';
  String get code => _code;

  /// Kept in memory only so "Try again" after a network error can resend;
  /// cleared after success or a definite answer. Never stored or logged.
  String? _pendingPassword;

  /// Whether the sign-in form may be sent.
  static bool canSubmit(String code, String password) => code.trim().isNotEmpty && password.isNotEmpty;

  Future<void> signIn(String code, String password) async {
    if (_busy || !canSubmit(code, password)) return;
    _code = code.trim();
    _pendingPassword = password;
    await _send();
  }

  Future<void> _send() async {
    final password = _pendingPassword;
    if (password == null) return;
    _busy = true;
    notifyListeners();
    try {
      final result = await _authApi.signIn(
        SignInRequest(code: _code, password: password, deviceId: await _session.deviceId()),
      );
      await _session.save(result.session);
      _pendingPassword = null;
      _busy = false;
      _onSignedIn(result.account);
      return;
    } on ApiClientException catch (e) {
      _log.info('Sign-in failed: ${e.kind.name} ${e.statusCode ?? ''} ${e.error?.code ?? ''}');
      _show(switch (e.error?.code) {
        ApiErrorCode.invalidCredentials => AuthProblem.invalidCredentials,
        ApiErrorCode.accountInactive => AuthProblem.accountUnavailable,
        _ => AuthProblem.unreachable,
      });
    } catch (e) {
      // Storing the session failed: nothing changed on the server either.
      _log.severe('Could not store the session on this device ($e).');
      _show(AuthProblem.unreachable);
    }
    _busy = false;
    notifyListeners();
  }

  void _show(AuthProblem problem) {
    if (problem != AuthProblem.unreachable) _pendingPassword = null;
    _problem = problem;
    _step = AuthStep.error;
  }

  /// The error screen's main action: "Try again".
  Future<void> retry() async {
    if (_problem == AuthProblem.unreachable && _pendingPassword != null) {
      await _send();
    } else {
      _go(AuthStep.signIn);
    }
  }

  void openForgotPassword() => _go(AuthStep.forgotPassword);

  /// Forgot password → Continue: shows how to recover. Sends nothing and
  /// changes nothing; the code is only repeated for the employee to give
  /// to HR/Admin.
  void submitForgotPassword(String code) {
    _code = code.trim();
    _go(AuthStep.recovery);
  }

  /// "Contact HR/Admin" from onboarding: the recovery guidance directly.
  void showRecovery() => _go(AuthStep.recovery);

  /// The previous screen, or `false` when there is none (leave the flow).
  bool back() {
    if (_busy) return true;
    if (_step == AuthStep.signIn) return false;
    _go(AuthStep.signIn);
    return true;
  }

  void _go(AuthStep step) {
    _step = step;
    if (step != AuthStep.error) _problem = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _pendingPassword = null;
    super.dispose();
  }
}
