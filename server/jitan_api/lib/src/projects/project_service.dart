import 'package:jitan_models/jitan_models.dart';

import '../audit/audit_event.dart';
import '../audit/audit_log_repository.dart';
import '../companies/company_repository.dart';
import '../database/sql_executor.dart';
import '../employees/employee_repository.dart';
import '../http/api_exception.dart';
import '../locations/location_repository.dart';
import 'project_repository.dart';

/// HR/Admin managing projects (Figma `647:1192` …, D16, D17, D27). HR adds
/// them by hand until the SAP import exists (D21). A client project has its
/// client's address, chosen from Locations so Jitan can recognise arrival
/// there; an internal project has none. Every change is audited in the same
/// transaction; an action that changes nothing is not.
class ProjectService {
  ProjectService({
    required this._projects,
    required this._companies,
    required this._employees,
    required this._locations,
    required this._audit,
    required this._transactions,
    required this._executor,
  });

  /// `tblProjectType` row that needs a client address.
  static const clientTypeName = 'Client';

  static final _date = RegExp(r'^\d{4}-\d{2}-\d{2}$');

  final ProjectRepository _projects;
  final CompanyRepository _companies;
  final EmployeeRepository _employees;
  final LocationRepository _locations;
  final AuditLogRepository _audit;
  final TransactionRunner _transactions;
  final SqlExecutor _executor;

  Future<ProjectOptions> options() async {
    final types = await _projects.types(_executor);
    return ProjectOptions(
      types: types,
      statuses: await _projects.statuses(_executor),
      addressTypeIds: [
        for (final type in types)
          if (type.name == clientTypeName) type.id,
      ],
    );
  }

  /// Every project of the companies where [mayView] agrees.
  Future<List<ProjectSummary>> list(Future<bool> Function(int companyId) mayView) async {
    final companies = [
      for (final company in await _companies.listCompanies())
        if (await mayView(company.id)) company.id,
    ];
    return _projects.list(_executor, companies);
  }

  Future<ProjectDetails> find(int companyId, int projectId) async =>
      await _projects.find(_executor, companyId, projectId) ?? (throw _notFound());

  Future<ProjectDetails> create(int actorUserId, int companyId, ProjectRequest request) async {
    final project = await _validated(request);
    final id = await _transactions.transaction((tx) async {
      final id = await _projects.insert(tx, companyId, project);
      await _record(tx, AuditEventType.projectCreated, actorUserId, companyId, id);
      return id;
    });
    return find(companyId, id);
  }

  Future<ProjectDetails> update(int actorUserId, int companyId, int projectId, ProjectRequest request) async {
    final project = await _validated(request);
    await _transactions.transaction((tx) async {
      if (!await _projects.lock(tx, companyId, projectId)) throw _notFound();
      await _projects.update(tx, projectId, project);
      await _record(tx, AuditEventType.projectChanged, actorUserId, companyId, projectId);
    });
    return find(companyId, projectId);
  }

  /// Makes [request]'s employees the project's team. Only members of the
  /// project's company can be on it.
  Future<ProjectDetails> assign(
    int actorUserId,
    int companyId,
    int projectId,
    ProjectEmployeesRequest request,
  ) async {
    final wanted = request.employeeIds.toSet();
    final members = {for (final e in await _employees.listForCompanies([companyId])) e.id};
    if (!members.containsAll(wanted)) {
      throw const ApiException.validation('employeeIds', 'Everyone on a project must belong to its company.');
    }
    await _transactions.transaction((tx) async {
      if (!await _projects.lock(tx, companyId, projectId)) throw _notFound();
      final links = await _projects.links(tx, projectId);
      for (final userId in wanted) {
        final link = links[userId];
        if (link?.current ?? false) continue;
        final id = link?.id ?? await _projects.addLink(tx, userId, projectId);
        if (link != null) await _projects.setLink(tx, link.id, current: true);
        await _recordAssignment(tx, AuditEventType.projectEmployeeAssigned, actorUserId, companyId, projectId, userId, id);
      }
      for (final MapEntry(key: userId, value: link) in links.entries) {
        if (!link.current || wanted.contains(userId)) continue;
        await _projects.setLink(tx, link.id, current: false);
        await _recordAssignment(tx, AuditEventType.projectEmployeeUnassigned, actorUserId, companyId, projectId, userId, link.id);
      }
    });
    return find(companyId, projectId);
  }

  Future<ProjectRequest> _validated(ProjectRequest request) async {
    final project = request.trimmed();
    if (project.name.isEmpty) throw const ApiException.validation(ProjectRequest.fieldName, 'Give the project a name.');
    _checkLength(project.name, ProjectRequest.maxNameLength, ProjectRequest.fieldName);
    _checkLength(project.reference, ProjectRequest.maxReferenceLength, ProjectRequest.fieldReference);
    _checkLength(project.description, ProjectRequest.maxDescriptionLength, ProjectRequest.fieldDescription);
    final start = _parseDate(project.startDate, ProjectRequest.fieldStartDate);
    final end = project.endDate == null ? null : _parseDate(project.endDate!, ProjectRequest.fieldEndDate);
    if (end != null && end.isBefore(start)) {
      throw const ApiException.validation(ProjectRequest.fieldEndDate, 'The end date is before the start date.');
    }
    final options = await this.options();
    if (!options.types.any((t) => t.id == project.typeId)) {
      throw const ApiException.validation(ProjectRequest.fieldType, 'Choose a type.');
    }
    if (!options.statuses.any((s) => s.id == project.statusId)) {
      throw const ApiException.validation(ProjectRequest.fieldStatus, 'Choose a status.');
    }
    if (!options.addressTypeIds.contains(project.typeId)) {
      return ProjectRequest(
        name: project.name,
        typeId: project.typeId,
        statusId: project.statusId,
        startDate: project.startDate,
        endDate: project.endDate,
        reference: project.reference,
        description: project.description,
      );
    }
    final addressId = project.addressId;
    final location = addressId == null ? null : await _locations.find(_executor, addressId);
    if (location == null || !location.isActive) {
      throw const ApiException.validation(ProjectRequest.fieldAddress, 'Choose the client address.');
    }
    return project;
  }

  static void _checkLength(String? value, int max, String field) {
    if ((value?.length ?? 0) > max) throw ApiException.validation(field, 'At most $max characters.');
  }

  static DateTime _parseDate(String value, String field) {
    final parsed = _date.hasMatch(value) ? DateTime.tryParse(value) : null;
    if (parsed == null || parsed.toIso8601String().substring(0, 10) != value) {
      throw ApiException.validation(field, 'Give a date, e.g. 2026-10-22.');
    }
    return parsed;
  }

  Future<void> _record(SqlExecutor tx, AuditEventType type, int actorUserId, int companyId, int projectId) =>
      _audit.record(
        tx,
        AuditEvent(
          type: type,
          actorUserId: actorUserId,
          references: {EventLogReference.company: companyId, EventLogReference.project: projectId},
        ),
      );

  Future<void> _recordAssignment(
    SqlExecutor tx,
    AuditEventType type,
    int actorUserId,
    int companyId,
    int projectId,
    int userId,
    int userProjectId,
  ) => _audit.record(
    tx,
    AuditEvent(
      type: type,
      actorUserId: actorUserId,
      references: {
        EventLogReference.user: userId,
        EventLogReference.company: companyId,
        EventLogReference.project: projectId,
        EventLogReference.userProject: userProjectId,
      },
    ),
  );

  static ApiException _notFound() => const ApiException.notFound('No such project.');
}
