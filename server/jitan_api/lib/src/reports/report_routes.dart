import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../auth/authorizer.dart';
import '../auth/permission.dart';
import '../auth/request_identity.dart';
import '../http/json_response.dart';
import '../http/path_id.dart';
import 'report_service.dart';

/// HR/Admin reports. Consumer: the Reports page (`apps/admin_web`).
///
/// - `GET /reports/hours?month=yyyy-MM&company=`: each employee's month. With
///   `company`, that company only (the right is checked there); without,
///   every company where the viewer may see reports, each checked on its own
///   (ENGINEERING_RULES §28a.5).
class ReportRoutes {
  const ReportRoutes(this._authorizer, this._reports);

  final Authorizer _authorizer;
  final ReportService _reports;

  Router get router => Router()..get('/reports/hours', _hours);

  Future<Response> _hours(Request request) async {
    // 401 without an identity, even when there is no company to check.
    request.identity;
    final query = request.url.queryParameters;
    final rawCompany = query['company'];
    final companyId = rawCompany == null || rawCompany.isEmpty ? null : pathId(rawCompany, 'No such company.');
    if (companyId != null) await _authorizer.require(request, Permission.viewReports, companyId: companyId);
    final report = await _reports.hours(
      month: query['month'],
      companyId: companyId,
      mayView: (id) => _authorizer.may(request, Permission.viewReports, companyId: id),
    );
    return jsonResponse(report.toJson());
  }
}
