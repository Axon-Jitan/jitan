import 'package:jitan_models/jitan_models.dart';

import 'api_client_exception.dart';
import 'api_transport.dart';

/// `GET /time-records`: HR/Admin Time records.
class TimeRecordsApi {
  const TimeRecordsApi(this._transport);

  final ApiTransport _transport;

  /// The working days from [from] to [to] (workplace-local calendar days,
  /// both inclusive) of [companyId]'s employees, or of every company when
  /// `null`; [search] matches name or code.
  Future<List<TimeRecordDay>> list({required DateTime from, required DateTime to, int? companyId, String? search}) async {
    final term = search?.trim() ?? '';
    final json = await _transport.getJson(
      'time-records',
      query: {
        'from': TimeRecordDay.dateText(from),
        'to': TimeRecordDay.dateText(to),
        'company': ?companyId?.toString(),
        if (term.isNotEmpty) 'search': term,
      },
    );
    try {
      return TimeRecordList.fromJson(json).days;
    } on FormatException catch (e) {
      throw ApiClientException.invalidResponse(200, 'Time records: ${e.message}');
    }
  }

  /// HR corrects or adds [request.boundary] of [date] for [userId] (rounded
  /// by the server). Returns the day as it is now.
  Future<TimeRecordDay?> correct(int companyId, int userId, DateTime date, CorrectTimeRequest request) =>
      _day('companies/$companyId/employees/$userId/time-records/${TimeRecordDay.dateText(date)}/correct', request.toJson());

  /// What local [time] (`HH:mm`) on [date] would count as after rounding.
  Future<String> previewRounding(int companyId, int userId, DateTime date, RegistrationBoundary boundary, String time) async {
    final json = await _transport.getJson(
      'companies/$companyId/employees/$userId/time-records/${TimeRecordDay.dateText(date)}/rounding',
      query: {'boundary': boundary.wireName, 'time': time},
    );
    try {
      return json.readString('rounded');
    } on FormatException catch (e) {
      throw ApiClientException.invalidResponse(200, 'Rounding preview: ${e.message}');
    }
  }

  /// HR marks [date] as non-work; the day's registrations are switched off.
  Future<TimeRecordDay?> markNonWork(int companyId, int userId, DateTime date, String reason) => _day(
    'companies/$companyId/employees/$userId/time-records/${TimeRecordDay.dateText(date)}/non-work',
    MarkNonWorkRequest(reason: reason).toJson(),
  );

  /// HR approves the employee's correction [registrationId]: it now counts.
  Future<TimeRecordDay?> approve(int companyId, int userId, int registrationId) =>
      _day('companies/$companyId/employees/$userId/time-registrations/$registrationId/approve', const {});

  /// HR rejects the employee's correction [registrationId].
  Future<TimeRecordDay?> reject(int companyId, int userId, int registrationId) =>
      _day('companies/$companyId/employees/$userId/time-registrations/$registrationId/reject', const {});

  Future<TimeRecordDay?> _day(String path, Map<String, Object?> body) async {
    final json = await _transport.postJson(path, body);
    try {
      return TimeRecordList.fromJson(json).days.firstOrNull;
    } on FormatException catch (e) {
      throw ApiClientException.invalidResponse(200, 'Time record: ${e.message}');
    }
  }
}
