import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:jitan_models/jitan_models.dart';

/// What the Employees screen is showing for one company.
sealed class EmployeesState {
  const EmployeesState();
}

class EmployeesLoading extends EmployeesState {
  const EmployeesLoading();
}

class EmployeesLoaded extends EmployeesState {
  const EmployeesLoaded({required this.employees, required this.search});

  final List<EmployeeSummary> employees;

  /// The search the list was loaded for ('' = unfiltered).
  final String search;
}

class EmployeesFailed extends EmployeesState {
  const EmployeesFailed(this.failure);

  final ApiClientException failure;
}

/// Loads one company's employees and applies search. One controller per
/// company: a new company gets a new controller, so results never mix.
///
/// Holds no business rules: scoping and filtering happen on the server.
class EmployeesController extends ChangeNotifier {
  EmployeesController(this._api, {required this.companyId, this.searchDelay = defaultSearchDelay});

  static const defaultSearchDelay = Duration(milliseconds: 300);

  final EmployeesApi _api;
  final int companyId;
  final Duration searchDelay;

  EmployeesState _state = const EmployeesLoading();
  EmployeesState get state => _state;

  String _search = '';
  Timer? _searchTimer;
  int _latestRequest = 0;
  bool _disposed = false;

  Future<void> load() async {
    final request = ++_latestRequest;
    final search = _search;
    _emit(const EmployeesLoading());
    try {
      final employees = await _api.listForCompany(companyId, search: search);
      if (request == _latestRequest) _emit(EmployeesLoaded(employees: employees, search: search));
    } on ApiClientException catch (failure) {
      if (request == _latestRequest) _emit(EmployeesFailed(failure));
    }
  }

  void updateSearch(String text) {
    final search = text.trim();
    if (search == _search) return;
    _search = search;
    _searchTimer?.cancel();
    _searchTimer = Timer(searchDelay, load);
  }

  void _emit(EmployeesState state) {
    if (_disposed) return;
    _state = state;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _searchTimer?.cancel();
    super.dispose();
  }
}
