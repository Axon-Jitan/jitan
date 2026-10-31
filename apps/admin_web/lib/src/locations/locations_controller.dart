import 'package:flutter/foundation.dart';
import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:jitan_models/jitan_models.dart';

/// What the Locations page is showing.
sealed class LocationsState {
  const LocationsState();
}

class LocationsLoading extends LocationsState {
  const LocationsLoading();
}

class LocationsLoaded extends LocationsState {
  const LocationsLoaded(this.locations);

  /// Every location, active or not.
  final List<Location> locations;
}

class LocationsFailed extends LocationsState {
  const LocationsFailed(this.failure);

  final ApiClientException failure;
}

/// The status filter of the Locations list; `null` = all.
enum LocationStatusFilter { active, inactive }

/// Loads the locations and filters them for display. Holds no location
/// rules: the server validates every change.
class LocationsController extends ChangeNotifier {
  LocationsController(this._api);

  final LocationsApi _api;

  LocationsState _state = const LocationsLoading();
  LocationsState get state => _state;

  String _search = '';

  LocationStatusFilter? _status;
  LocationStatusFilter? get status => _status;

  int _latestRequest = 0;
  bool _disposed = false;

  List<Location> get visible => switch (_state) {
    LocationsLoaded(:final locations) => [
      for (final location in locations)
        if (_matches(location) &&
            switch (_status) {
              null => true,
              LocationStatusFilter.active => location.isActive,
              LocationStatusFilter.inactive => !location.isActive,
            })
          location,
    ],
    _ => const [],
  };

  bool _matches(Location location) {
    if (_search.isEmpty) return true;
    final text = [location.name, location.street, location.zipcode, location.city].whereType<String>().join(' ');
    return text.toLowerCase().contains(_search.toLowerCase());
  }

  Future<void> load() async {
    final request = ++_latestRequest;
    _emit(const LocationsLoading());
    try {
      final locations = await _api.list();
      if (request == _latestRequest) _emit(LocationsLoaded(locations));
    } on ApiClientException catch (failure) {
      if (request == _latestRequest) _emit(LocationsFailed(failure));
    }
  }

  void updateSearch(String text) {
    _search = text.trim();
    _notify();
  }

  void updateStatus(LocationStatusFilter? status) {
    _status = status;
    _notify();
  }

  void _emit(LocationsState state) {
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
