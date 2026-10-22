import 'package:jitan_models/jitan_models.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../auth/authorizer.dart';
import '../auth/permission.dart';
import '../auth/request_identity.dart';
import '../http/api_exception.dart';
import '../http/json_request.dart';
import '../http/json_response.dart';
import '../http/path_id.dart';
import 'my_day_service.dart';
import 'time_correction_service.dart';
import 'time_record_service.dart';

/// HR/Admin Time records. Consumer: the Time records page (`apps/admin_web`).
///
/// - `GET /time-records?from=yyyy-MM-dd&to=yyyy-MM-dd&company=&search=`: the
///   working days in the period. With `company`, that company only (the
///   right is checked there); without, every company where the viewer may
///   see registrations, each checked on its own (ENGINEERING_RULES §28a.5).
/// - `POST /companies/{c}/employees/{u}/time-records/{date}/correct` with a
///   `CorrectTimeRequest`: HR corrects or adds that day's start or finish
/// - `POST …/time-records/{date}/non-work` with a `MarkNonWorkRequest`
/// - `GET …/time-records/{date}/rounding?boundary=start&time=08:04`: what a
///   time would count as after rounding (`{"rounded": "08:15"}`)
/// - `POST /companies/{c}/employees/{u}/time-registrations/{id}/approve` and
///   `…/reject`: the employee's correction waiting for review (D31)
///
/// The writes need `correctTimeRegistrations` in company `c` and answer with
/// the day as it is now (`{"days": [day]}`, or no day when nothing is left).
///
/// - `GET /me/today`: the signed-in employee's own day (`MyDay`). Acts only
///   on the signed-in user, so it needs no permission. Consumer: the
///   Employee App "Today" screens.
class TimeRecordRoutes {
  const TimeRecordRoutes(this._authorizer, this._records, this._corrections, this._myDay);

  final Authorizer _authorizer;
  final TimeRecordService _records;
  final TimeCorrectionService _corrections;
  final MyDayService _myDay;

  static const _employee = '/companies/<companyId|[0-9]+>/employees/<userId|[0-9]+>';

  Router get router => Router()
    ..get('/time-records', _list)
    ..get('/me/today', (Request r) async => jsonResponse((await _myDay.today(r.identity.userId)).toJson()))
    ..post('$_employee/time-records/<date>/correct', _correct)
    ..post('$_employee/time-records/<date>/non-work', _nonWork)
    ..get('$_employee/time-records/<date>/rounding', _preview)
    ..post('$_employee/time-registrations/<id|[0-9]+>/approve', (Request r, String c, String u, String id) => _review(r, c, u, id, approve: true))
    ..post('$_employee/time-registrations/<id|[0-9]+>/reject', (Request r, String c, String u, String id) => _review(r, c, u, id, approve: false));

  Future<Response> _list(Request request) async {
    // 401 without an identity, even when there is no company to check.
    request.identity;
    final query = request.url.queryParameters;
    final rawCompany = query['company'];
    final companyId = rawCompany == null || rawCompany.isEmpty ? null : pathId(rawCompany, 'No such company.');
    if (companyId != null) {
      await _authorizer.require(request, Permission.viewTimeRegistrations, companyId: companyId);
    }
    final list = await _records.records(
      companyId: companyId,
      search: query['search'],
      from: query['from'],
      to: query['to'],
      mayView: (id) => _authorizer.may(request, Permission.viewTimeRegistrations, companyId: id),
    );
    return jsonResponse(list.toJson());
  }

  Future<Response> _correct(Request request, String companyId, String userId, String date) async {
    final company = pathId(companyId, 'No such company.');
    final identity = await _authorizer.require(request, Permission.correctTimeRegistrations, companyId: company);
    final body = await _read(request, CorrectTimeRequest.fromJson);
    final day = await _corrections.correct(identity.userId, company, pathId(userId, 'No such employee.'), date, body);
    return _day(day);
  }

  Future<Response> _nonWork(Request request, String companyId, String userId, String date) async {
    final company = pathId(companyId, 'No such company.');
    final identity = await _authorizer.require(request, Permission.correctTimeRegistrations, companyId: company);
    final body = await _read(request, MarkNonWorkRequest.fromJson);
    final day = await _corrections.markNonWork(identity.userId, company, pathId(userId, 'No such employee.'), date, body.reason);
    return _day(day);
  }

  Future<Response> _preview(Request request, String companyId, String userId, String date) async {
    final company = pathId(companyId, 'No such company.');
    await _authorizer.require(request, Permission.correctTimeRegistrations, companyId: company);
    final query = request.url.queryParameters;
    final RegistrationBoundary boundary;
    try {
      boundary = RegistrationBoundary.fromWire(query['boundary'] ?? '');
    } on FormatException catch (e) {
      throw ApiException.badRequest(e.message);
    }
    final rounded = await _corrections.preview(company, pathId(userId, 'No such employee.'), date, boundary, query['time'] ?? '');
    return jsonResponse({'rounded': rounded});
  }

  Future<Response> _review(Request request, String companyId, String userId, String id, {required bool approve}) async {
    final company = pathId(companyId, 'No such company.');
    final identity = await _authorizer.require(request, Permission.correctTimeRegistrations, companyId: company);
    final user = pathId(userId, 'No such employee.');
    final registration = pathId(id, 'No such registration.');
    final day = approve
        ? await _corrections.approve(identity.userId, company, user, registration)
        : await _corrections.reject(identity.userId, company, user, registration);
    return _day(day);
  }

  static Future<T> _read<T>(Request request, T Function(Map<String, Object?>) parse) async {
    try {
      return parse(await readJsonObject(request));
    } on FormatException catch (e) {
      throw ApiException.badRequest(e.message);
    }
  }

  static Response _day(TimeRecordDay? day) => jsonResponse(TimeRecordList(days: [?day]).toJson());
}
