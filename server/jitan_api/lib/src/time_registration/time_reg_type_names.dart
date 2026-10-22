import 'package:jitan_models/jitan_models.dart';

/// The `tblTimeRegType.timeRegTypeName` of each kind of row (TIME_ENGINE_ANALYSIS
/// D5b; rows in docs/database/reference_data.sql). Jitan finds the types by
/// these names; the ids come from the database.
abstract final class TimeRegTypeNames {
  /// "Start – actual – Manual", …: the time as registered, never changed.
  static String actual(RegistrationBoundary boundary, TimeRegistrationMethod method) =>
      '${_boundary(boundary)} – actual – ${switch (method) {
        TimeRegistrationMethod.manual => 'Manual',
      }}';

  /// "Start – rounded" / "Finish – rounded": the time rounded with the
  /// employee's schedule.
  static String rounded(RegistrationBoundary boundary) => '${_boundary(boundary)} – rounded';

  /// "Start – corrected" / "Finish – corrected": HR's corrected time (D7).
  static String corrected(RegistrationBoundary boundary) => '${_boundary(boundary)} – corrected';

  static String _boundary(RegistrationBoundary boundary) => switch (boundary) {
    RegistrationBoundary.start => 'Start',
    RegistrationBoundary.finish => 'Finish',
  };
}
