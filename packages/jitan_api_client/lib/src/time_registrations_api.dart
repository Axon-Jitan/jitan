import 'package:jitan_models/jitan_models.dart';

import 'api_client_exception.dart';
import 'api_transport.dart';

/// Read-only time registrations: an employee's (HR/Admin, company-scoped)
/// or the signed-in user's own. Oldest first, one page at a time.
///
/// [from] (inclusive) and [to] (exclusive) are wall-clock times: stored
/// times have no timezone yet (GAP-02), so they are sent without offset and
/// a UTC [DateTime] is refused rather than silently converted.
class TimeRegistrationsApi {
  const TimeRegistrationsApi(this._transport);

  final ApiTransport _transport;

  Future<TimeRegistrationPage> forEmployee(
    int companyId,
    int userId, {
    required DateTime from,
    required DateTime to,
    int? limit,
    String? cursor,
  }) =>
      _page('companies/$companyId/employees/$userId/time-registrations', from, to, limit, cursor);

  Future<TimeRegistrationPage> mine({required DateTime from, required DateTime to, int? limit, String? cursor}) =>
      _page('me/time-registrations', from, to, limit, cursor);

  /// Registers the signed-in employee's start or finish; returns the actual
  /// and rounded times the server stored. Sending the same registration again
  /// (e.g. after a lost response) returns the same pair, never a duplicate.
  Future<RegisteredTime> register(RegisterTimeRequest request) async {
    final json = await _transport.postJson('me/time-registrations', request.toJson());
    try {
      return RegisteredTime.fromJson(json);
    } on FormatException catch (e) {
      throw ApiClientException.invalidResponse(201, 'Registered time: ${e.message}');
    }
  }

  /// The signed-in employee's day (`GET /me/today`): schedule, today's
  /// registrations as HR sees them, and the registered total once finished.
  Future<MyDay> today() async {
    final json = await _transport.getJson('me/today');
    try {
      return MyDay.fromJson(json);
    } on FormatException catch (e) {
      throw ApiClientException.invalidResponse(200, 'Today: ${e.message}');
    }
  }

  Future<TimeRegistrationPage> _page(String path, DateTime from, DateTime to, int? limit, String? cursor) async {
    final json = await _transport.getJson(
      path,
      query: {
        TimeRegistrationQuery.from: _wallClock(from),
        TimeRegistrationQuery.to: _wallClock(to),
        if (limit != null) TimeRegistrationQuery.limit: '$limit',
        TimeRegistrationQuery.cursor: ?cursor,
      },
    );
    try {
      return TimeRegistrationPage.fromJson(json);
    } on FormatException catch (e) {
      throw ApiClientException.invalidResponse(200, '$path: ${e.message}');
    }
  }

  /// `yyyy-MM-ddTHH:mm:ss`, no offset.
  static String _wallClock(DateTime value) {
    if (value.isUtc) throw ArgumentError.value(value, 'value', 'Pass a wall-clock (non-UTC) DateTime (GAP-02).');
    return value.toIso8601String().substring(0, 19);
  }
}
