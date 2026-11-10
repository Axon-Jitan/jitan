import 'package:flutter/foundation.dart';
import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:jitan_models/jitan_models.dart';

/// What the Lists page is showing.
sealed class ListsState {
  const ListsState();
}

class ListsLoading extends ListsState {
  const ListsLoading();
}

class ListsLoaded extends ListsState {
  const ListsLoaded(this.overview);

  final FixedListOverview overview;
}

class ListsFailed extends ListsState {
  const ListsFailed(this.failure);

  final ApiClientException failure;
}

/// Loads the lists and adds what they miss. Knows no list's entries: the
/// server says what Jitan needs and adds only that.
class ListsController extends ChangeNotifier {
  ListsController(this._api);

  final FixedListsApi _api;

  ListsState _state = const ListsLoading();
  ListsState get state => _state;

  bool _adding = false;
  bool get adding => _adding;

  /// The last "Add what's missing" failed.
  bool _addFailed = false;
  bool get addFailed => _addFailed;

  bool _disposed = false;

  Future<void> load() async {
    if (_state is! ListsLoaded) _emit(const ListsLoading());
    try {
      _emit(ListsLoaded(await _api.overview()));
    } on ApiClientException catch (failure) {
      _emit(ListsFailed(failure));
    }
  }

  Future<void> addAllMissing() async {
    _adding = true;
    _addFailed = false;
    _notify();
    try {
      _state = ListsLoaded(await _api.addAllMissing());
    } on ApiClientException {
      _addFailed = true;
    }
    _adding = false;
    _notify();
  }

  void _emit(ListsState state) {
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
