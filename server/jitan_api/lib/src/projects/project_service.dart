import 'package:jitan_models/jitan_models.dart';

import '../audit/audit_event.dart';
import '../audit/audit_log_repository.dart';
import '../database/database_exception.dart';
import '../database/sql_executor.dart';
import '../http/api_exception.dart';
import '../locations/location_repository.dart';
import 'project_repository.dart';

/// HR/Admin managing projects (D43, D44, Figma `1512:2` …) until SAP is
/// connected. A project is a `tblAddress` row of the kind "Project location",
/// named `<SAP number> <name>`: a client site (an address with its pin and
/// area, written like a location) or internal work at one of the workshops.
/// Every change is audited in the same transaction.
class ProjectService {
  ProjectService({
    required this._projects,
    required this._locations,
    required this._audit,
    required this._transactions,
    required this._executor,
  });

  final ProjectRepository _projects;
  final LocationRepository _locations;
  final AuditLogRepository _audit;
  final TransactionRunner _transactions;
  final SqlExecutor _executor;

  Future<List<ProjectSummary>> list() async {
    final workshops = await _workshopNames();
    return [for (final row in await _projects.list(_executor)) summaryOf(row, workshops)];
  }

  Future<ProjectDetails> find(int projectId) async {
    final row = await _projects.find(_executor, projectId) ?? (throw _notFound());
    final workshops = await _locations.all(_executor, withProjects: false);
    final names = {for (final w in workshops) ?ProjectRepository.coordinatesOf(w.point): w.name};
    return ProjectDetails(
      summary: summaryOf(row, names),
      site: row.hasArea ? await _locations.find(_executor, projectId) : null,
      workshopId: row.hasArea
          ? null
          : workshops.where((w) => ProjectRepository.coordinatesOf(w.point) == row.coordinates).firstOrNull?.id,
    );
  }

  Future<ProjectDetails> create(int actorUserId, ProjectRequest request) async {
    final project = _validated(request);
    final fullName = ProjectRequest.fullName(project.sapNumber, project.name);
    final workshop = await _workshop(project);
    final id = await _write(fullName, () => _transactions.transaction((tx) async {
      final kind = await _projects.projectKindId(tx) ?? (throw _kindMissing());
      if (await _locations.nameTaken(tx, fullName)) throw _nameTaken(fullName);
      final int addressId;
      final references = <EventLogReference, int>{};
      if (project.site case final site?) {
        final keys = await _locations.insert(tx, _named(site, fullName));
        addressId = keys.addressId;
        references[EventLogReference.geofence] = keys.geofenceId;
        references[EventLogReference.geofenceAddress] = keys.geofenceAddressId;
      } else {
        addressId = await _projects.insertInternal(tx, fullName, workshop!);
      }
      references[EventLogReference.address] = addressId;
      references[EventLogReference.addressLocationType] = await _projects.link(tx, addressId, kind);
      await _audit.record(tx, AuditEvent(type: AuditEventType.projectCreated, actorUserId: actorUserId, references: references));
      return addressId;
    }));
    return find(id);
  }

  /// A client site stays a client site and an internal project internal: the
  /// kind is chosen when it is added.
  Future<ProjectDetails> update(int actorUserId, int projectId, ProjectRequest request) async {
    final project = _validated(request);
    final fullName = ProjectRequest.fullName(project.sapNumber, project.name);
    final workshop = await _workshop(project);
    await _write(fullName, () => _transactions.transaction((tx) async {
      if (!await _projects.lock(tx, projectId)) throw _notFound();
      final current = (await _projects.find(tx, projectId))!;
      if (current.hasArea != (project.site != null)) {
        throw const ApiException.validation(ProjectRequest.fieldWorkshop, 'A project keeps its kind of place.');
      }
      if (await _locations.nameTaken(tx, fullName, exceptAddressId: projectId)) throw _nameTaken(fullName);
      if (project.site case final site?) {
        final (_, keys) = await _locations.lock(tx, projectId) ?? (throw _notFound());
        await _locations.update(tx, keys, _named(site, fullName));
      } else {
        await _projects.updateInternal(tx, projectId, fullName, workshop!);
      }
      await _audit.record(
        tx,
        AuditEvent(
          type: AuditEventType.projectChanged,
          actorUserId: actorUserId,
          references: {EventLogReference.address: projectId},
        ),
      );
    }));
    return find(projectId);
  }

  /// Off: nobody can choose it any more, and its site is no longer
  /// recognised. Registrations stay.
  Future<ProjectDetails> setActive(int actorUserId, int projectId, {required bool active}) async {
    await _transactions.transaction((tx) async {
      if (!await _projects.lock(tx, projectId)) throw _notFound();
      if ((await _projects.find(tx, projectId))!.isActive == active) return;
      await _projects.setActive(tx, projectId, active: active);
      await _audit.record(
        tx,
        AuditEvent(
          type: AuditEventType.projectChanged,
          actorUserId: actorUserId,
          references: {EventLogReference.address: projectId},
        ),
      );
    });
    return find(projectId);
  }

  /// The summary of [row]; [workshops] names a workshop by its coordinates.
  static ProjectSummary summaryOf(ProjectRow row, Map<String, String> workshops) {
    final (sapNumber, name) = ProjectRequest.split(row.fullName);
    return ProjectSummary(
      id: row.id,
      sapNumber: sapNumber,
      name: name,
      isClientSite: row.hasArea,
      isActive: row.isActive,
      placeName: row.hasArea ? row.city : workshops[row.coordinates],
      lastUsed: row.lastUsed,
    );
  }

  /// The workplaces' names by coordinates: an internal project sits at one.
  Future<Map<String, String>> _workshopNames() async => {
    for (final w in await _locations.all(_executor, withProjects: false)) ?ProjectRepository.coordinatesOf(w.point): w.name,
  };

  /// The active workshop of an internal project; 400 otherwise.
  Future<Location?> _workshop(ProjectRequest project) async {
    if (project.site != null) return null;
    final id = project.workshopId;
    final workshop = id == null
        ? null
        : (await _locations.all(_executor, withProjects: false)).where((w) => w.id == id).firstOrNull;
    if (workshop == null || !workshop.isActive || workshop.point == null) {
      throw const ApiException.validation(ProjectRequest.fieldWorkshop, 'Choose a workshop.');
    }
    return workshop;
  }

  static ProjectRequest _validated(ProjectRequest request) {
    final project = request.trimmed();
    if (project.sapNumber.isEmpty) {
      throw const ApiException.validation(ProjectRequest.fieldSapNumber, 'Give the SAP number.');
    }
    if (project.sapNumber.contains(RegExp(r'\s')) || project.sapNumber.length > ProjectRequest.maxSapNumberLength) {
      throw ApiException.validation(
        ProjectRequest.fieldSapNumber,
        'One word, at most ${ProjectRequest.maxSapNumberLength} characters.',
      );
    }
    if (project.name.isEmpty) throw const ApiException.validation(ProjectRequest.fieldName, 'Give the project a name.');
    if (ProjectRequest.fullName(project.sapNumber, project.name).length > ProjectRequest.maxFullNameLength) {
      throw ApiException.validation(
        ProjectRequest.fieldName,
        'The SAP number and name together are at most ${ProjectRequest.maxFullNameLength} characters.',
      );
    }
    if (project.site == null && project.workshopId == null) {
      throw const ApiException.validation(ProjectRequest.fieldWorkshop, 'Choose a workshop.');
    }
    return project;
  }

  /// The client site, named after the project.
  static LocationRequest _named(LocationRequest site, String fullName) => LocationRequest(
    name: fullName,
    street: site.street,
    number: site.number,
    box: site.box,
    zipcode: site.zipcode,
    city: site.city,
    point: site.point,
    radiusMeters: site.radiusMeters,
  );

  /// The address name's unique key still catches an exact race.
  static Future<T> _write<T>(String fullName, Future<T> Function() action) async {
    try {
      return await action();
    } on DatabaseQueryException catch (e) {
      if (e.isDuplicateKey) throw _nameTaken(fullName);
      if (e.isValueTooLong) throw const ApiException.badRequest('A value is longer than allowed.');
      rethrow;
    }
  }

  static ApiException _nameTaken(String fullName) => ApiException(
    409,
    ApiErrorCode.duplicateLocationName,
    'A project or location named "$fullName" already exists.',
    field: ProjectRequest.fieldName,
  );

  static ApiException _kindMissing() =>
      ApiException.configurationError('Add "Project location" on the Lists page first.');

  static ApiException _notFound() => const ApiException.notFound('No such project.');
}
