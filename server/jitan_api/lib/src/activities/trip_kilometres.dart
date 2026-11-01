import 'package:jitan_models/jitan_models.dart';

import '../database/sql_executor.dart';
import '../locations/location_repository.dart';
import '../routing/driving_distance.dart';
import '../time_registration/workplace_clock.dart';
import 'activity_repository.dart';

/// Trips and their distance. [unknown]: trips counted without one, because a
/// place or the route is not known, so [metres] may be too low.
typedef TripTotals = ({int trips, int metres, int unknown});

/// One trip, between two `tblAddress` rows; `null` for a place not known.
typedef Trip = ({int? from, int? to});

/// Kilometres, calculated when asked and never stored (D23, D40): the normal
/// route of each transport, from where the employee was to where they arrive.
/// The road they actually drove is not known to Jitan.
class TripKilometres {
  TripKilometres({
    required this._activities,
    required this._locations,
    required this._distance,
    required this._executor,
    required this._clock,
  });

  final ActivityRepository _activities;
  final LocationRepository _locations;
  final DrivingDistance _distance;
  final SqlExecutor _executor;
  final WorkplaceClock _clock;

  /// The trips of [day], one day's activities oldest first. Transports in a
  /// row are one trip. It leaves from the row's own place, else from the place
  /// of the activity before; it arrives at the place of the activity after,
  /// else at the project it was for. Out and back to one place says nothing
  /// about where they went, so that arrival is not known either.
  static List<Trip> tripsOf(List<ActivityRow> day) {
    bool isTransport(int i) => day[i].typeName == ActivityRepository.transportType;
    int? place(ActivityRow row) => row.addressId ?? row.projectAddressId;
    final trips = <Trip>[];
    for (var i = 0; i < day.length; i++) {
      if (!isTransport(i) || (i > 0 && isTransport(i - 1))) continue;
      var last = i;
      while (last + 1 < day.length && isTransport(last + 1)) {
        last++;
      }
      final from = day[i].addressId ?? (i > 0 ? place(day[i - 1]) : null);
      final after = last + 1 < day.length ? place(day[last + 1]) : null;
      final arrives = after ?? day[last].projectAddressId;
      trips.add((from: from, to: arrives == from ? null : arrives));
    }
    return trips;
  }

  /// Each trip of one day's activities with its distance, in order.
  Future<List<({Trip trip, int? metres})>> distancesOf(List<ActivityRow> day) async {
    final points = await _points();
    return [for (final trip in tripsOf(day)) (trip: trip, metres: await _metres(trip, points))];
  }

  Future<int?> _metres(Trip trip, Map<int, GeoPoint> points) async {
    final from = points[trip.from], to = points[trip.to];
    return from == null || to == null ? null : _distance.metres(from, to);
  }

  /// The totals of one day's activities.
  Future<TripTotals> ofDay(List<ActivityRow> day) async => _total(tripsOf(day), await _points());

  /// The totals of [userIds] from [from] up to [to], day by day.
  Future<Map<int, TripTotals>> ofUsers(List<int> userIds, DateTime from, DateTime to) async {
    final rows = await _activities.ofUsers(_executor, userIds, from, to);
    final points = await _points();
    final totals = <int, TripTotals>{};
    for (final MapEntry(key: userId, value: activities) in rows.entries) {
      final days = <DateTime, List<ActivityRow>>{};
      for (final row in activities) {
        final local = _clock.wallClockOf(row.at);
        days.putIfAbsent(DateTime.utc(local.year, local.month, local.day), () => []).add(row);
      }
      totals[userId] = await _total([for (final day in days.values) ...tripsOf(day)], points);
    }
    return totals;
  }

  Future<Map<int, GeoPoint>> _points() async => {
    for (final location in await _locations.all(_executor))
      if (location.point != null) location.id: location.point!,
  };

  Future<TripTotals> _total(List<Trip> trips, Map<int, GeoPoint> points) async {
    var metres = 0, unknown = 0;
    for (final trip in trips) {
      final distance = await _metres(trip, points);
      if (distance == null) {
        unknown++;
      } else {
        metres += distance;
      }
    }
    return (trips: trips.length, metres: metres, unknown: unknown);
  }
}
