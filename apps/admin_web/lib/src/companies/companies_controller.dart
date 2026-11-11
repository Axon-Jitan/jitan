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

/// Which companies the pills let through (Figma `1524:2`).
enum CompanyStatusFilter { all, active, inactive }

/// Loads the company list from the API, applies search (on the server) and
/// the status pills (here), and keeps the list current after a change.
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

  CompanyStatusFilter _status = CompanyStatusFilter.all;
  CompanyStatusFilter get status => _status;

  /// The company just added, lit up for a moment (Figma `1524:350`).
  int? _fresh;
  int? get fresh => _fresh;

  /// What the list shows: the loaded companies the status pills let through.
  List<CompanySummary> get visible => switch (_state) {
    CompaniesLoaded(:final companies) => [
      for (final c in companies)
        if (_status == CompanyStatusFilter.all || c.isActive == (_status == CompanyStatusFilter.active)) c,
    ],
    _ => const [],
  };

  /// Every company, whatever the search, for the name check while typing:
  /// the last list loaded without a search, kept current after each change.
  List<CompanySummary> _all = const [];
  List<CompanySummary> get loaded => _all;

  void updateStatus(CompanyStatusFilter status) {
    _status = status;
    if (!_disposed) notifyListeners();
  }

  /// [company] as the server answered after a change: added (and lit up),
  /// or replaced where it was. Names stay in order.
  void put(CompanySummary company, {bool added = false}) {
    _all = [for (final c in _all) if (c.id != company.id) c, company];
    if (_state case CompaniesLoaded(:final companies, :final search)) {
      final rest = [for (final c in companies) if (c.id != company.id) c];
      final next = [...rest, company]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      if (added) _fresh = company.id;
      _emit(CompaniesLoaded(companies: next, search: search));
    }
  }

  /// The lit-up row fades back.
  void settle() {
    if (_fresh == null) return;
    _fresh = null;
    if (!_disposed) notifyListeners();
  }

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
      if (search.isEmpty) _all = companies;
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
