/// When each terminal last checked in, kept in memory only (GAP-09): a tablet
/// checks in about every minute, so after a restart every working tablet is
/// known again within a minute. Nothing is stored.
class TerminalPresence {
  final _lastSeen = <int, DateTime>{};

  void seen(int deviceId, DateTime at) => _lastSeen[deviceId] = at.toUtc();

  DateTime? lastSeen(int deviceId) => _lastSeen[deviceId];

  void forget(int deviceId) => _lastSeen.remove(deviceId);
}
