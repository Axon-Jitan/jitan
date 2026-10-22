import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../config/config_exception.dart';

/// Converts between UTC, in which registrations are stored, and the
/// workplace's local time, in which schedules are read (TIME_ENGINE_ANALYSIS
/// D9). Daylight saving is handled by the IANA time zone database.
class WorkplaceClock {
  WorkplaceClock._(this._location);

  /// The clock of IANA time zone [name] (e.g. `Europe/Brussels`). Throws
  /// [ConfigException] for an unknown name, so a wrong setting stops the
  /// server at startup.
  factory WorkplaceClock(String name) {
    if (!_loaded) {
      tz_data.initializeTimeZones();
      _loaded = true;
    }
    try {
      return WorkplaceClock._(tz.getLocation(name));
    } on tz.LocationNotFoundException {
      throw ConfigException('JITAN_TIMEZONE "$name" is not a known time zone (e.g. Europe/Brussels).');
    }
  }

  static var _loaded = false;

  final tz.Location _location;

  String get name => _location.name;

  /// [utc] as the workplace's wall clock: a UTC-flagged value holding the
  /// local fields, so calculations on it ignore daylight saving.
  DateTime wallClockOf(DateTime utc) {
    final local = tz.TZDateTime.from(utc.toUtc(), _location);
    return DateTime.utc(local.year, local.month, local.day, local.hour, local.minute, local.second);
  }

  /// The UTC moment of the workplace wall-clock time [wallClock] (its fields
  /// are read as local time).
  DateTime utcOf(DateTime wallClock) => DateTime.fromMicrosecondsSinceEpoch(
    tz.TZDateTime(
      _location,
      wallClock.year,
      wallClock.month,
      wallClock.day,
      wallClock.hour,
      wallClock.minute,
      wallClock.second,
    ).microsecondsSinceEpoch,
    isUtc: true,
  );
}
