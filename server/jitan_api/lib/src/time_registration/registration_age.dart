/// How old a time sent "as it happened" may be (review H1, product owner
/// 2026-11-16). Older times are refused: they go as a change with a reason,
/// which HR approves (D30, D31).
abstract final class RegistrationAge {
  /// Tapped by the employee (Start, Finish, a switch of activity): only the
  /// difference between the phone's clock and the server's.
  static const tapped = Duration(minutes: 5);

  /// Detected by the phone (arriving, leaving, a trip): the leaving time is
  /// sent when the employee answers "What happened?", at least an hour later
  /// and sometimes the next morning.
  static const detected = Duration(hours: 24);

  /// Whether [at] is too old to be sent as it happened at [now].
  static bool tooOld(DateTime at, DateTime now, {required bool detected}) =>
      now.difference(at) > (detected ? RegistrationAge.detected : tapped);

  static const message = 'This time is too old to send as it happened. Enter it as a change with a reason.';
}
