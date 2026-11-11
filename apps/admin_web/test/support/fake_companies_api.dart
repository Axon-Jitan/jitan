import 'dart:async';

import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:jitan_models/jitan_models.dart';

/// Stand-in for [CompaniesApi]: each call waits on a [Completer] the test
/// controls, so loading, success, failure and out-of-order responses can
/// all be exercised.
class FakeCompaniesApi implements CompaniesApi {
  final calls = <String?>[];
  final _pending = <Completer<List<CompanySummary>>>[];

  @override
  Future<List<CompanySummary>> listCompanies({String? search}) {
    calls.add(search);
    final completer = Completer<List<CompanySummary>>();
    _pending.add(completer);
    return completer.future;
  }

  int get pendingCount => _pending.where((c) => !c.isCompleted).length;

  /// Completes call number [index] (default: the latest).
  void succeed(List<CompanySummary> companies, {int? index}) =>
      _pending[index ?? _pending.length - 1].complete(companies);

  void fail(ApiClientException failure, {int? index}) => _pending[index ?? _pending.length - 1].completeError(failure);

  /// Every write, e.g. `create Proceq`, `rename 2 Almeco Group`, `deactivate 2`.
  final writes = <String>[];

  /// Thrown by the next write when set.
  ApiClientException? writeFailure;

  /// What the writes answer with: the company after the change.
  CompanySummary Function(String write) answer = (_) => company(9, 'Proceq');

  Future<CompanySummary> _write(String write) async {
    writes.add(write);
    if (writeFailure case final failure?) {
      writeFailure = null;
      throw failure;
    }
    return answer(write);
  }

  @override
  Future<CompanySummary> create(CompanyRequest request) => _write('create ${request.name}');

  @override
  Future<CompanySummary> rename(int companyId, CompanyRequest request) => _write('rename $companyId ${request.name}');

  @override
  Future<CompanySummary> deactivate(int companyId) => _write('deactivate $companyId');

  @override
  Future<CompanySummary> reactivate(int companyId) => _write('reactivate $companyId');
}

CompanySummary company(int id, String name, {bool active = true, int employees = 0, DateTime? lastUpdatedAt}) =>
    CompanySummary(id: id, name: name, isActive: active, employeeCount: employees, lastUpdatedAt: lastUpdatedAt);

ApiClientException serverError(int status, String code) =>
    ApiClientException.server(status, ApiError(code: code, message: 'server detail'));
