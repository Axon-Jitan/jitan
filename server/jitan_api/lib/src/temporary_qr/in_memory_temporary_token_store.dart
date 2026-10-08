import 'temporary_token_store.dart';

/// [TemporaryTokenStore] in this process's memory: for development and for a
/// single API instance (today's production topology). Nothing is written to
/// disk; a restart forgets every outstanding QR (HR/Admin generates a new
/// one). Every method runs without an `await` between check and update, so
/// it is atomic within the isolate.
class InMemoryTemporaryTokenStore implements TemporaryTokenStore {
  InMemoryTemporaryTokenStore({DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;
  final _entries = <TemporaryTokenKey, _Entry>{};

  /// Entries currently held (for tests and diagnostics; no token values).
  int get length {
    _purge();
    return _entries.length;
  }

  @override
  Future<void> replace(TemporaryTokenKey key, String tokenId, DateTime expiresAt) async {
    _purge();
    _entries[key] = _Entry(tokenId, expiresAt.toUtc());
  }

  @override
  Future<TemporaryTokenState> inspect(TemporaryTokenKey key, String tokenId, {String? deviceId}) async =>
      _state(key, tokenId, deviceId);

  @override
  Future<TemporaryTokenState> claim(TemporaryTokenKey key, String tokenId, String deviceId) async {
    final state = _state(key, tokenId, deviceId);
    if (state == TemporaryTokenState.available) _entries[key]!.deviceId = deviceId;
    return state;
  }

  @override
  Future<void> release(TemporaryTokenKey key, String tokenId, String deviceId) async {
    final entry = _current(key, tokenId);
    if (entry != null && !entry.consumed && entry.deviceId == deviceId) entry.deviceId = null;
  }

  @override
  Future<void> consume(TemporaryTokenKey key, String tokenId, String deviceId) async {
    final entry = _current(key, tokenId);
    if (entry != null && entry.deviceId == deviceId) entry.consumed = true;
  }

  TemporaryTokenState _state(TemporaryTokenKey key, String tokenId, String? deviceId) {
    final entry = _current(key, tokenId);
    if (entry == null) return TemporaryTokenState.unknown;
    if (entry.deviceId == null) return TemporaryTokenState.available;
    if (deviceId != null && entry.deviceId == deviceId) {
      return entry.consumed ? TemporaryTokenState.consumedByThisDevice : TemporaryTokenState.claimedByThisDevice;
    }
    return TemporaryTokenState.usedElsewhere;
  }

  _Entry? _current(TemporaryTokenKey key, String tokenId) {
    _purge();
    final entry = _entries[key];
    return entry != null && entry.tokenId == tokenId ? entry : null;
  }

  void _purge() {
    final now = _clock().toUtc();
    _entries.removeWhere((_, entry) => !now.isBefore(entry.expiresAt));
  }
}

class _Entry {
  _Entry(this.tokenId, this.expiresAt);

  final String tokenId;
  final DateTime expiresAt;
  String? deviceId;
  bool consumed = false;
}
