import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../auth/authorizer.dart';
import '../auth/permission.dart';
import '../auth/request_identity.dart';
import '../http/json_response.dart';
import '../http/path_id.dart';
import 'time_record_service.dart';

/// HR/Admin Time records. Consumer: the Time records page (`apps/admin_web`).
///
/// - `GET /time-records?from=yyyy-MM-dd&to=yyyy-MM-dd&company=&search=`: the
///   working days in the period. With `company`, that company only (the
///   right is checked there); without, every company where the viewer may
///   see registrations, each checked on its own (ENGINEERING_RULES §28a.5).
class TimeRecordRoutes {
  const TimeRecordRoutes(this._authorizer, this._records);

  final Authorizer _authorizer;
  final TimeRecordService _records;

  Router get router => Router()..get('/time-records', _list);

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
}
