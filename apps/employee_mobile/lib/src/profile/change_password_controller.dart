import 'package:flutter/foundation.dart';
import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:logging/logging.dart';

import '../auth/password_rules.dart';
import '../device/session_manager.dart';

final _log = Logger('profile');

/// Outcome of a change-password attempt that did not succeed.
enum ChangePasswordFailure {
  /// No answer or a server error: the password has not been changed.
  unreachable,
}

/// Profile → Password & web login → Change password (Figma "Profile /
/// Change password"). The server verifies the current password. On success
/// it returns a new session for this device, stored here; every other device
/// is signed out.
class ChangePasswordController extends ChangeNotifier {
  ChangePasswordController({required this._meApi, required this._session, required this._onSessionEnded});

  final MeApi _meApi;
  final SessionManager _session;

  /// The session is no longer valid (401): sign this device out.
  final VoidCallback _onSessionEnded;

  bool _busy = false;
  bool get busy => _busy;

  /// Problem with the new password (and its confirmation).
  PasswordProblem? _problem;
  PasswordProblem? get problem => _problem;

  /// The server did not accept the current password.
  bool _currentPasswordWrong = false;
  bool get currentPasswordWrong => _currentPasswordWrong;

  ChangePasswordFailure? _failure;
  ChangePasswordFailure? get failure => _failure;

  /// Returns `true` when the new password is set and this device holds the
  /// new session.
  Future<bool> submit({required String current, required String password, required String confirmation}) async {
    if (_busy) return false;
    _failure = null;
    _currentPasswordWrong = current.isEmpty;
    _problem = PasswordRules.check(password, confirmation);
    if (_currentPasswordWrong || _problem != null) {
      notifyListeners();
      return false;
    }
    _busy = true;
    notifyListeners();
    try {
      final result = await _meApi.changePassword(currentPassword: current, newPassword: password);
      await _session.save(result.session);
      return true;
    } on ApiClientException catch (e) {
      _log.info('Change password failed: ${e.kind.name} ${e.statusCode ?? ''} ${e.error?.code ?? ''}');
      final error = e.error;
      if (e.statusCode == 401) {
        _onSessionEnded();
      } else if (error?.code == ApiErrorCode.validationFailed &&
          error?.field == ChangePasswordRequest.fieldCurrentPassword) {
        _currentPasswordWrong = true;
      } else if (error?.code == ApiErrorCode.validationFailed) {
        _problem = PasswordProblem.rejected;
      } else {
        _failure = ChangePasswordFailure.unreachable;
      }
      return false;
    } catch (e) {
      // The server changed the password but this device could not store the
      // new session: its old session no longer works, so sign in again.
      _log.severe('Could not store the new session ($e).');
      _onSessionEnded();
      return false;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }
}
