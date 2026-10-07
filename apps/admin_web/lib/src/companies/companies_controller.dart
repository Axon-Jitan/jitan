import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:jitan_models/jitan_models.dart';

/// What the Companies screen is showing.
sealed class CompaniesState {
  const CompaniesState();
}

class CompaniesLoading extends CompaniesState {
  const CompaniesLoading();
}

class CompaniesLoaded extends CompaniesState {
  const CompaniesLoaded({required this.companies, required this.search});

  final List<CompanySummary> companies;

  /// The search the list was loaded for ('' = unfiltered).
  final String search;
}

class CompaniesFailed extends CompaniesState {
  const CompaniesFailed(this.failure);

  final ApiClientException failure;
}

/// Loads the company list from the API and applies search.
///
/// Holds no business rules: filtering happens on the server; this only
/// sequences requests and exposes their outcome.
class CompaniesController extends ChangeNotifier {
  CompaniesController(this._api, {this.searchDelay = defaultSearchDelay});

  /// Pause after the last keystroke before searching.
  static const defaultSearchDelay = Duration(milliseconds: 300);

  final CompaniesApi _api;
  final Duration searchDelay;

  CompaniesState _state = const CompaniesLoading();
  CompaniesState get state => _state;

  String _search = '';
  Timer? _searchTimer;

  /// Increments per request so a slow, outdated response never overwrites a
  /// newer one.
  int _latestRequest = 0;
  bool _disposed = false;

  Future<void> load() async {
    final request = ++_latestRequest;
    final search = _search;
    _emit(const CompaniesLoading());
    try {
      final companies = await _api.listCompanies(search: search);
      if (request == _latestRequest) _emit(CompaniesLoaded(companies: companies, search: search));
    } on ApiClientException catch (failure) {
      if (request == _latestRequest) _emit(CompaniesFailed(failure));
    }
  }

  void updateSearch(String text) {
    final search = text.trim();
    if (search == _search) return;
    _search = search;
    _searchTimer?.cancel();
    _searchTimer = Timer(searchDelay, load);
  }

  void _emit(CompaniesState state) {
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
