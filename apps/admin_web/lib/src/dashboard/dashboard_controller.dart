import 'package:flutter/foundation.dart';
import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:jitan_models/jitan_models.dart';

import '../auth/platform/session_store.dart';
import 'dashboard_period.dart';

/// What the Dashboard is showing.
sealed class DashboardState {
  const DashboardState();
}

class DashboardLoading extends DashboardState {
  const DashboardLoading();
}

class DashboardLoaded extends DashboardState {
  const DashboardLoaded(this.dashboard);

  final Dashboard dashboard;
}

class DashboardFailed extends DashboardState {
  const DashboardFailed(this.failure);

  final ApiClientException failure;
}

/// Loads the Dashboard for the chosen period and remembers the period in this
/// browser. A new period keeps the old numbers up until the new ones arrive.
class DashboardController extends ChangeNotifier {
  DashboardController(this._api, this._store, {required DateTime today})
    : _period = DashboardPeriod.decode(_store.read(_storeKey), today);

  static const _storeKey = 'jitan.dashboard.period';

  final DashboardApi _api;
  final SessionStore _store;

  DashboardState _state = const DashboardLoading();
  DashboardState get state => _state;

  DashboardPeriod _period;
  DashboardPeriod get period => _period;

  int _latestRequest = 0;
  bool _disposed = false;

  Future<void> load() async {
    final request = ++_latestRequest;
    if (_state is! DashboardLoaded) _emit(const DashboardLoading());
    try {
      final dashboard = await _api.dashboard(_period.from, _period.to);
      if (request == _latestRequest) _emit(DashboardLoaded(dashboard));
    } on ApiClientException catch (failure) {
      if (request == _latestRequest) _emit(DashboardFailed(failure));
    }
  }

  void updatePeriod(DashboardPeriod period) {
    _period = period;
    _store.write(_storeKey, period.encode());
    _notify();
    load();
  }

  void _emit(DashboardState state) {
    _state = state;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
