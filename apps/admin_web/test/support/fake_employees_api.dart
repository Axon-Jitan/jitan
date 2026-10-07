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

  void succeed(List<EmployeeSummary> employees, {int? index}) =>
      _pending[index ?? _pending.length - 1].complete(employees);

  void fail(ApiClientException failure, {int? index}) =>
      _pending[index ?? _pending.length - 1].completeError(failure);

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
}) =>
    EmployeeSummary(id: id, firstName: first, lastName: last, code: code, groups: groups, isActive: active);
