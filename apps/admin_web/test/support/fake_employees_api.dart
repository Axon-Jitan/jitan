import 'dart:async';

import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:jitan_models/jitan_models.dart';

/// Stand-in for [EmployeesApi]: each call waits on a [Completer] the test
/// controls.
class FakeEmployeesApi implements EmployeesApi {
  /// (companyId, search) of every call.
  final calls = <(int, String?)>[];
  final _pending = <Completer<List<EmployeeSummary>>>[];

  @override
  Future<List<EmployeeSummary>> listForCompany(int companyId, {String? search}) {
    calls.add((companyId, search));
    final completer = Completer<List<EmployeeSummary>>();
    _pending.add(completer);
    return completer.future;
  }

  /// (companyId, userId) of every remove.
  final removes = <(int, int)>[];
  final _pendingRemoves = <Completer<void>>[];

  @override
  Future<void> remove(int companyId, int userId) {
    removes.add((companyId, userId));
    final completer = Completer<void>();
    _pendingRemoves.add(completer);
    return completer.future;
  }

  void removeSucceeds() => _pendingRemoves.last.complete();

  void removeFails(ApiClientException failure) => _pendingRemoves.last.completeError(failure);

  /// Every company (no "Current company"): recorded in [calls] as company -1.
  @override
  Future<List<EmployeeSummary>> listAll({String? search}) => listForCompany(-1, search: search);

  void succeed(List<EmployeeSummary> employees, {int? index}) =>
      _pending[index ?? _pending.length - 1].complete(employees);

  void fail(ApiClientException failure, {int? index}) => _pending[index ?? _pending.length - 1].completeError(failure);

  /// (companyId, request) of every create.
  final creates = <(int, CreateEmployeeRequest)>[];
  final _pendingCreates = <Completer<EmployeeSummary>>[];

  @override
  Future<EmployeeSummary> create(int companyId, CreateEmployeeRequest request) {
    creates.add((companyId, request));
    final completer = Completer<EmployeeSummary>();
    _pendingCreates.add(completer);
    return completer.future;
  }

  void createSucceeds(EmployeeSummary employee) => _pendingCreates.last.complete(employee);

  void createFails(ApiClientException failure) => _pendingCreates.last.completeError(failure);

  /// (companyId, userId) of every details request.
  final detailRequests = <(int, int)>[];
  final _pendingDetails = <Completer<EmployeeDetails>>[];

  @override
  Future<EmployeeDetails> details(int companyId, int userId) {
    detailRequests.add((companyId, userId));
    final completer = Completer<EmployeeDetails>();
    _pendingDetails.add(completer);
    return completer.future;
  }

  void detailsSucceed(EmployeeDetails details) => _pendingDetails.last.complete(details);

  void detailsFail(ApiClientException failure) => _pendingDetails.last.completeError(failure);

  /// (companyId, userId, purpose) of every temporary QR request.
  final qrRequests = <(int, int, TemporaryQrPurpose)>[];
  final _pendingQr = <Completer<TemporaryQrResponse>>[];

  @override
  Future<TemporaryQrResponse> temporaryQr(int companyId, int userId, TemporaryQrPurpose purpose) {
    qrRequests.add((companyId, userId, purpose));
    final completer = Completer<TemporaryQrResponse>();
    _pendingQr.add(completer);
    return completer.future;
  }

  /// Answers the last request with [value], valid until [expiresAt].
  void qrSucceeds(String value, {required DateTime expiresAt}) =>
      _pendingQr.last.complete(TemporaryQrResponse(qrCode: value, purpose: qrRequests.last.$3, expiresAt: expiresAt));

  void qrFails(ApiClientException failure) => _pendingQr.last.completeError(failure);

  /// (companyId, userId) of every reset-access request.
  final resetRequests = <(int, int)>[];
  final _pendingResets = <Completer<void>>[];

  @override
  Future<void> resetAccess(int companyId, int userId) {
    resetRequests.add((companyId, userId));
    final completer = Completer<void>();
    _pendingResets.add(completer);
    return completer.future;
  }

  void resetSucceeds() => _pendingResets.last.complete();

  void resetFails(ApiClientException failure) => _pendingResets.last.completeError(failure);

  /// (companyId, request) of every import check.
  final importChecks = <(int, EmployeeImportRequest)>[];
  final _pendingChecks = <Completer<EmployeeImportCheck>>[];

  @override
  Future<EmployeeImportCheck> checkImport(int companyId, EmployeeImportRequest request) {
    importChecks.add((companyId, request));
    final completer = Completer<EmployeeImportCheck>();
    _pendingChecks.add(completer);
    return completer.future;
  }

  void checkSucceeds(List<EmployeeImportProblem> problems) =>
      _pendingChecks.last.complete(EmployeeImportCheck(problems: problems));

  void checkFails(ApiClientException failure) => _pendingChecks.last.completeError(failure);

  /// (companyId, request) of every import.
  final imports = <(int, EmployeeImportRequest)>[];
  final _pendingImports = <Completer<EmployeeImportResult>>[];

  @override
  Future<EmployeeImportResult> importEmployees(int companyId, EmployeeImportRequest request) {
    imports.add((companyId, request));
    final completer = Completer<EmployeeImportResult>();
    _pendingImports.add(completer);
    return completer.future;
  }

  void importSucceeds(EmployeeImportResult result) => _pendingImports.last.complete(result);

  void importFails(ApiClientException failure) => _pendingImports.last.completeError(failure);
}

/// Stand-in for [GroupsApi] with a controllable result.
class FakeGroupsApi implements GroupsApi {
  final _pending = <Completer<List<GroupSummary>>>[];
  int get calls => _pending.length;

  @override
  Future<List<GroupSummary>> listGroups() {
    final completer = Completer<List<GroupSummary>>();
    _pending.add(completer);
    return completer.future;
  }

  void succeed(List<GroupSummary> groups) => _pending.last.complete(groups);

  void fail(ApiClientException failure) => _pending.last.completeError(failure);
}

EmployeeSummary employee(
  int id,
  String? first,
  String? last,
  String code, {
  List<String> groups = const [],
  bool active = true,
  bool activated = false,
  List<int> companyIds = const [],
}) => EmployeeSummary(
  id: id,
  firstName: first,
  lastName: last,
  code: code,
  groups: groups,
  isActive: active,
  isActivated: activated,
  companyIds: companyIds,
);
