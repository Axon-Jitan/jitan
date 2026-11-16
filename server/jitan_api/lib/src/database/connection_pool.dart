import 'dart:async';
import 'dart:collection';

/// Jitan's own pool of database connections (review L8, DB-DRIVER-01).
///
/// The driver's pool (mysql_client_plus 0.1.3) puts every connection back,
/// even one that was closed or whose `ROLLBACK` failed, and offers no way to
/// drop one: such a connection then fails every later request, or carries
/// an unfinished transaction into the next one. Here a connection goes back
/// only while it is open and was not [discard]ed; otherwise it is closed and
/// its place is free for a new one.
///
/// Generic over the connection type so it can be tested without MySQL.
class ConnectionPool<C extends Object> {
  ConnectionPool({
    required this._open,
    required this._isOpen,
    required this._close,
    required this.maxConnections,
  });

  final Future<C> Function() _open;
  final bool Function(C connection) _isOpen;
  final Future<void> Function(C connection) _close;
  final int maxConnections;

  final _idle = <C>[];
  final _discarded = Set<C>.identity();
  final _waiting = Queue<Completer<C>>();
  int _count = 0;
  bool _closed = false;

  /// Open connections, idle or in use.
  int get size => _count;

  /// Connections waiting to be used.
  int get idle => _idle.length;

  /// Runs [body] on one connection and gives the connection back afterwards,
  /// also when [body] throws.
  Future<T> withConnection<T>(Future<T> Function(C connection) body) async {
    final connection = await _acquire();
    try {
      return await body(connection);
    } finally {
      _release(connection);
    }
  }

  /// Marks [connection], in use by the caller, as not to be used again: it
  /// is closed when the caller gives it back. Closing ends its session, so
  /// MySQL rolls back anything open on it and frees its named locks.
  void discard(C connection) => _discarded.add(connection);

  Future<C> _acquire() async {
    if (_closed) throw StateError('The connection pool is closed.');
    while (_idle.isNotEmpty) {
      final connection = _idle.removeLast();
      if (_isOpen(connection)) return connection;
      _count--;
    }
    if (_count < maxConnections) return _openOne();
    final turn = Completer<C>();
    _waiting.add(turn);
    return turn.future;
  }

  Future<C> _openOne() async {
    _count++;
    try {
      return await _open();
    } catch (_) {
      _count--;
      rethrow;
    }
  }

  void _release(C connection) {
    final usable = !_closed && !_discarded.remove(connection) && _isOpen(connection);
    if (!usable) {
      _count--;
      unawaited(_closeQuietly(connection));
      // Its place is free: someone waiting gets a new connection.
      if (!_closed && _waiting.isNotEmpty && _count < maxConnections) {
        final turn = _waiting.removeFirst();
        _openOne().then(turn.complete, onError: turn.completeError);
      }
      return;
    }
    if (_waiting.isNotEmpty) {
      _waiting.removeFirst().complete(connection);
    } else {
      _idle.add(connection);
    }
  }

  Future<void> _closeQuietly(C connection) async {
    try {
      if (_isOpen(connection)) await _close(connection);
    } catch (_) {
      // Already gone: nothing more to free.
    }
  }

  /// Closes the idle connections; those in use close when given back.
  /// Anyone still waiting gets an error.
  Future<void> close() async {
    _closed = true;
    while (_waiting.isNotEmpty) {
      _waiting.removeFirst().completeError(StateError('The connection pool is closed.'));
    }
    final idle = [..._idle];
    _idle.clear();
    _count -= idle.length;
    for (final connection in idle) {
      await _closeQuietly(connection);
    }
  }
}
