import 'package:logging/logging.dart';
import 'package:shelf/shelf.dart';

import '../auth/request_identity.dart';

final _log = Logger('lists.setup');

/// Jitan completes its own fixed lists (registration types, schedule types,
/// days, kinds of place, terminal kinds, audit names): HR never has to
/// (product owner, 2026-11-12). They are names the code reads, so there is
/// nothing to choose.
///
/// The first time someone who may manage the lists makes a request after
/// the server starts (an HR or Admin user), what is missing is added, as by
/// "Add what's missing": exactly the missing names, each audited under that
/// person, in one transaction. Once complete it does not run again until the
/// next start (an update brings new names). When adding fails (e.g. IT's
/// database account may not add rows) it waits [retryAfter] before trying
/// again, and the Dashboard tells Admin the setup is not finished. The
/// request itself always goes on.
class FixedListSetup {
  FixedListSetup({
    required this._addAllMissing,
    required this._mayManage,
    this.retryAfter = const Duration(minutes: 10),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  /// Adds what every list misses for [actorUserId]; `true` when they are
  /// complete afterwards.
  final Future<bool> Function(int actorUserId) _addAllMissing;

  /// Whether the request's user may manage the lists.
  final Future<bool> Function(Request request) _mayManage;
  final Duration retryAfter;
  final DateTime Function() _clock;

  bool _complete = false;
  DateTime? _failedAt;
  Future<void>? _running;

  /// Runs after authentication, before the routes.
  Middleware get middleware => (inner) => (request) async {
    await _completeFor(request);
    return inner(request);
  };

  Future<void> _completeFor(Request request) async {
    if (_complete || !request.hasIdentity) return;
    final failedAt = _failedAt;
    if (failedAt != null && _clock().difference(failedAt) < retryAfter) return;
    final bool allowed;
    try {
      allowed = await _mayManage(request);
    } on Object {
      return;
    }
    if (!allowed) return;
    // Requests at the same moment wait for the one run.
    await (_running ??= _run(request.identity.userId));
  }

  Future<void> _run(int actorUserId) async {
    try {
      _complete = await _addAllMissing(actorUserId);
      _failedAt = _complete ? null : _clock();
      if (!_complete) _log.warning('Some fixed lists are still incomplete after adding what was missing.');
    } on Object catch (error) {
      _failedAt = _clock();
      // No details: they may hold database errors (§28a.4).
      _log.warning('Could not complete the fixed lists (${error.runtimeType}); trying again later.');
    } finally {
      _running = null;
    }
  }
}
