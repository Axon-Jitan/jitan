import 'package:jitan_models/jitan_models.dart';

import '../database/sql_executor.dart';
import '../locations/location_repository.dart';
import '../projects/project_repository.dart';
import '../time_registration/workplace_clock.dart';
import 'activity_repository.dart';
import 'trip_kilometres.dart';

/// The lines of a day's activities as the phone shows them (Home's timeline
/// and Period's, 2026-11-13): each activity with its project or place, and
/// transports in a row as one line with their distance. Read-only, from the
/// `tblTimeReg` "Activity – …" rows (D44).
class ActivityEntries {
  ActivityEntries({
    required this._activities,
    required this._projects,
    required this._locations,
    required this._kilometres,
    required this._executor,
    required this._clock,
  });

  final ActivityRepository _activities;
  final ProjectRepository _projects;
  final LocationRepository _locations;
  final TripKilometres _kilometres;
  final SqlExecutor _executor;
  final WorkplaceClock _clock;

  static const _typeNames = {
    'Activity – Work': ActivityKind.work,
    'Activity – Client on site': ActivityKind.clientOnSite,
    'Activity – Client in-house': ActivityKind.clientInHouse,
    'Activity – Internal': ActivityKind.internal,
    ActivityRepository.transportType: ActivityKind.transport,
  };

  /// [userId]'s lines from [from] up to [to] (UTC), oldest first.
  Future<List<ActivityEntry>> between(int userId, DateTime from, DateTime to) async {
    final rows = await _activities.between(_executor, userId, from, to);
    if (rows.isEmpty) return const [];
    return _linesOf(rows, await _names());
  }

  /// [userId]'s lines per workplace-local day, from [first] to [last]
  /// (both dates inclusive). Days without activities are left out.
  Future<Map<DateTime, List<ActivityEntry>>> byDay(int userId, DateTime first, DateTime last) async {
    final rows = await _activities.between(
      _executor,
      userId,
      _clock.utcOf(DateTime(first.year, first.month, first.day)),
      _clock.utcOf(DateTime(last.year, last.month, last.day + 1)),
    );
    if (rows.isEmpty) return const {};
    final byDate = <DateTime, List<ActivityRow>>{};
    for (final row in rows) {
      final local = _clock.wallClockOf(row.at);
      byDate.putIfAbsent(DateTime.utc(local.year, local.month, local.day), () => []).add(row);
    }
    final names = await _names();
    return {for (final MapEntry(:key, :value) in byDate.entries) key: await _linesOf(value, names)};
  }

  /// Project names (every project, so an old day still names one that was
  /// switched off since) and place names, by `addressID`.
  Future<({Map<int, String> projects, Map<int, String> places})> _names() async => (
    projects: {for (final p in await _projects.list(_executor)) p.id: p.fullName},
    places: {for (final l in await _locations.all(_executor)) l.id: l.name},
  );

  /// One day's rows as lines: transports in a row are one line.
  Future<List<ActivityEntry>> _linesOf(List<ActivityRow> rows, ({Map<int, String> projects, Map<int, String> places}) names) async {
    final trips = await _kilometres.distancesOf(rows);
    bool isTransport(int i) => rows[i].typeName == ActivityRepository.transportType;
    var trip = 0;
    final lines = <ActivityEntry>[];
    for (final (i, row) in rows.indexed) {
      if (!isTransport(i)) {
        lines.add(
          ActivityEntry(
            timeLocal: _time(row.at),
            kind: _typeNames[row.typeName] ?? ActivityKind.work,
            projectName: names.projects[row.addressId],
            placeName: names.places[row.addressId],
          ),
        );
      } else if (i == 0 || !isTransport(i - 1)) {
        final (trip: to, :metres) = trips[trip++];
        lines.add(ActivityEntry(timeLocal: _time(row.at), kind: ActivityKind.transport, placeName: names.places[to.to], metres: metres));
      }
    }
    return lines;
  }

  String _time(DateTime at) {
    final local = _clock.wallClockOf(at);
    return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }
}
