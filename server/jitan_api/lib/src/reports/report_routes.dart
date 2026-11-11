import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../auth/authorizer.dart';
import '../auth/permission.dart';
import '../auth/request_identity.dart';
import '../http/json_response.dart';
import '../http/path_id.dart';
import 'dashboard_service.dart';
import 'project_report_service.dart';
import 'report_service.dart';

/// HR/Admin reports. Consumer: the Reports page (`apps/admin_web`).
///
/// - `GET /reports/hours?month=yyyy-MM&company=`: each employee's month. With
///   `company`, that company only (the right is checked there); without,
///   every company where the viewer may see reports, each checked on its own
///   (ENGINEERING_RULES §28a.5).
/// - `GET /reports/projects?month=yyyy-MM`: each project's month. A project
///   has no company (D44): it holds the employees of every company where the
///   viewer may see reports, each checked on its own.
/// - `GET /dashboard?from=yyyy-MM-dd&to=yyyy-MM-dd`: today, the totals and the
///   period, for every company where the viewer may see reports. Consumer:
///   the Dashboard page.
class ReportRoutes {
  const ReportRoutes(this._authorizer, this._reports, this._dashboard, this._projects);

  final Authorizer _authorizer;
  final ReportService _reports;
  final DashboardService _dashboard;
  final ProjectReportService _projects;

  Router get router => Router()
    ..get('/reports/hours', _hours)
    ..get('/reports/projects', _projectReport)
    ..get('/dashboard', _overview);

  Future<Response> _overview(Request request) async {
    // 401 without an identity, even when there is no company to check.
    request.identity;
    final query = request.url.queryParameters;
    final dashboard = await _dashboard.dashboard(
      from: query['from'],
      to: query['to'],
      mayView: (id) => _authorizer.may(request, Permission.viewReports, companyId: id),
    );
    return jsonResponse(dashboard.toJson());
  }

  Future<Response> _projectReport(Request request) async {
    // 401 without an identity, even when there is no company to check.
    request.identity;
    final report = await _projects.projects(
      month: request.url.queryParameters['month'],
      mayView: (id) => _authorizer.may(request, Permission.viewReports, companyId: id),
    );
    return jsonResponse(report.toJson());
  }

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
