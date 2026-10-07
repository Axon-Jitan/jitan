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
