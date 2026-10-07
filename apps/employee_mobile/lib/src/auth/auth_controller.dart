import 'package:flutter/foundation.dart';
import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:logging/logging.dart';

import '../device/session_manager.dart';
import 'password_rules.dart';

final _log = Logger('auth');

/// Screens of the sign-in flow (Figma "Auth / 01 … 07").
enum AuthStep {
  /// 01 Sign in.
  signIn,

  /// 02 Forgot password.
  forgotPassword,

  /// 06 Recover with QR.
  recoverWithQr,

  /// 07 Set new password after reset.
  setNewPassword,

  /// 03–05.
  error,
}

/// Which "Auth / 03–05" error screen to show.
enum AuthProblem {
  /// 03: wrong code or password; deliberately does not say which.
  invalidCredentials,

  /// 04: inactive or MFD account.
  accountUnavailable,

  /// 05: no answer or a server error. Retrying is safe: nothing changed.
  unreachable,
}

/// What "Try again" on 05 repeats.
enum _Retry { signIn, recoveryScan, recoveryPassword }

/// Sign-in and account recovery for an employee who is already activated:
/// new device, reinstall, expired session, sign-out, or sent here from
/// onboarding. Never used right after onboarding, which signs the device in
/// itself.
///
/// Recovery (V1, HR/Admin-assisted). The employee code alone never resets
/// anything: Forgot password leads to "Recover with QR", which asks HR/Admin
/// to reset access first. After HR/Admin "Reset account access" the
/// employee's password is cleared, so their existing QR is accepted once
/// (`userPassword IS NULL`, the same server rule as onboarding); they set a
/// new password and are signed in. Before a reset, or once the new password
/// is set, the QR is refused.
class AuthController extends ChangeNotifier {
  AuthController({
    required this._authApi,
    required this._onboardingApi,
    required this._session,
    required this._onSignedIn,
  });

  final AuthApi _authApi;
  final OnboardingApi _onboardingApi;
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
  _Retry? _retry;

  /// The scanned QR while recovering (a credential: never logged).
  String? _recoveryQr;

  /// A QR the server just refused; ignored if the camera reads it again.
  String? _refusedQr;

  /// Recovery was refused: access not reset (or unknown QR). The "HR/Admin
  /// reset required" note is then shown as an error.
  bool _recoveryRefused = false;
  bool get recoveryRefused => _recoveryRefused;

  PasswordProblem? _passwordProblem;
  PasswordProblem? get passwordProblem => _passwordProblem;

  /// Whether the sign-in form may be sent.
  static bool canSubmit(String code, String password) => code.trim().isNotEmpty && password.isNotEmpty;

  // ── 01 Sign in ─────────────────────────────────────────────────────────

  Future<void> signIn(String code, String password) async {
    if (_busy || !canSubmit(code, password)) return;
    _code = code.trim();
    _pendingPassword = password;
    await _sendSignIn();
  }

  Future<void> _sendSignIn() async {
    final password = _pendingPassword;
    if (password == null) return;
    await _run(_Retry.signIn, () async {
      final result = await _authApi.signIn(
        SignInRequest(code: _code, password: password, deviceId: await _session.deviceId()),
      );
      await _signedIn(result);
    }, onServerError: (code) {
      _show(switch (code) {
        ApiErrorCode.invalidCredentials => AuthProblem.invalidCredentials,
        ApiErrorCode.accountInactive => AuthProblem.accountUnavailable,
        _ => AuthProblem.unreachable,
      });
    });
  }

  // ── 02 Forgot password → 06 Recover with QR ────────────────────────────

  void openForgotPassword() => _go(AuthStep.forgotPassword);

  /// Forgot password → Continue: nothing is sent or reset; the employee is
  /// told to ask HR/Admin for a reset and to scan their QR ("Recover with
  /// QR").
  void submitForgotPassword(String code) {
    _code = code.trim();
    openRecovery();
  }

  /// "Scan QR to recover account" (Sign in) or after Forgot password.
  void openRecovery() {
    _recoveryRefused = false;
    _refusedQr = null;
    _go(AuthStep.recoverWithQr);
  }

  /// A QR read on "Recover with QR". Accepted only when HR/Admin reset the
  /// employee's access (no password set).
  Future<void> submitRecoveryQr(String qrCode) async {
    if (_busy || qrCode == _refusedQr) return;
    _recoveryQr = qrCode;
    await _run(_Retry.recoveryScan, () async {
      await _onboardingApi.start(qrCode);
      _passwordProblem = null;
      _recoveryRefused = false;
      _go(AuthStep.setNewPassword);
    }, onServerError: (code) {
      switch (code) {
        case ApiErrorCode.accountInactive:
          _show(AuthProblem.accountUnavailable);
        case ApiErrorCode.invalidQrCode || ApiErrorCode.onboardingAlreadyCompleted:
          _refuseRecovery(qrCode);
        default:
          _show(AuthProblem.unreachable);
      }
    });
  }

  void _refuseRecovery(String qrCode) {
    _refusedQr = qrCode;
    _recoveryQr = null;
    _pendingPassword = null;
    _recoveryRefused = true;
    _step = AuthStep.recoverWithQr;
  }

  // ── 07 Set new password after reset ────────────────────────────────────

  Future<void> submitNewPassword(String password, String confirmation) async {
    if (_busy) return;
    _passwordProblem = PasswordRules.check(password, confirmation);
    if (_passwordProblem != null) {
      notifyListeners();
      return;
    }
    _pendingPassword = password;
    await _sendNewPassword();
  }

  Future<void> _sendNewPassword() async {
    final qr = _recoveryQr;
    final password = _pendingPassword;
    if (qr == null || password == null) return;
    await _run(_Retry.recoveryPassword, () async {
      final result = await _onboardingApi.complete(
        OnboardingCompleteRequest(qrCode: qr, password: password, deviceId: await _session.deviceId()),
      );
      await _signedIn(result);
    }, onServerError: (code) {
      switch (code) {
        case ApiErrorCode.validationFailed:
          _pendingPassword = null;
          _passwordProblem = PasswordProblem.rejected;
        case ApiErrorCode.accountInactive:
          _show(AuthProblem.accountUnavailable);
        case ApiErrorCode.invalidQrCode || ApiErrorCode.onboardingAlreadyCompleted:
          _refuseRecovery(qr);
        default:
          _show(AuthProblem.unreachable);
      }
    });
  }

  // ── Shared ─────────────────────────────────────────────────────────────

  /// The error screen's main action: "Try again".
  Future<void> retry() async {
    if (_problem != AuthProblem.unreachable) {
      _go(AuthStep.signIn);
      return;
    }
    switch (_retry) {
      case _Retry.signIn:
        await _sendSignIn();
      case _Retry.recoveryPassword when _pendingPassword != null:
        await _sendNewPassword();
      case _Retry.recoveryScan || _Retry.recoveryPassword:
        openRecovery();
      case null:
        _go(AuthStep.signIn);
    }
  }

  /// The previous screen, or `false` when there is none (leave the flow).
  bool back() {
    if (_busy) return true;
    switch (_step) {
      case AuthStep.signIn:
        return false;
      case AuthStep.setNewPassword:
        openRecovery();
      default:
        _go(AuthStep.signIn);
    }
    return true;
  }

  Future<void> _signedIn(SessionResponse result) async {
    await _session.save(result.session);
    _pendingPassword = null;
    _recoveryQr = null;
    _busy = false;
    _onSignedIn(result.account);
  }

  /// Runs [action]; maps failures. Server answers with a code go to
  /// [onServerError]; no answer, a server fault or a storage failure is
  /// "Can't reach Jitan" (retryable: [retry] repeats [kind]).
  Future<void> _run(
    _Retry kind,
    Future<void> Function() action, {
    required void Function(String? code) onServerError,
  }) async {
    _retry = kind;
    _busy = true;
    notifyListeners();
    try {
      await action();
    } on ApiClientException catch (e) {
      _log.info('Auth request failed: ${e.kind.name} ${e.statusCode ?? ''} ${e.error?.code ?? ''}');
      if (e.kind == ApiFailureKind.server && (e.statusCode ?? 500) < 500) {
        onServerError(e.error?.code);
      } else {
        _show(AuthProblem.unreachable);
      }
    } catch (e) {
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

  void _go(AuthStep step) {
    _step = step;
    if (step != AuthStep.error) _problem = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _pendingPassword = null;
    _recoveryQr = null;
    super.dispose();
  }
}
