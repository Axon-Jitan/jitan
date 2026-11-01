import 'package:flutter/foundation.dart';
import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:jitan_models/jitan_models.dart';

/// What the Terminals page is showing.
sealed class TerminalsState {
  const TerminalsState();
}

class TerminalsLoading extends TerminalsState {
  const TerminalsLoading();
}

class TerminalsLoaded extends TerminalsState {
  const TerminalsLoaded(this.terminals);

  final List<Terminal> terminals;
}

class TerminalsFailed extends TerminalsState {
  const TerminalsFailed(this.failure);

  final ApiClientException failure;
}

/// Loads the terminals and filters them for display. Holds no terminal rules:
/// the server validates every change and says each one's status.
class TerminalsController extends ChangeNotifier {
  TerminalsController(this._api);

  final TerminalsApi _api;

  TerminalsState _state = const TerminalsLoading();
  TerminalsState get state => _state;

  String _search = '';
  bool _disposed = false;

  List<Terminal> get all => switch (_state) {
    TerminalsLoaded(:final terminals) => terminals,
    _ => const [],
  };

  List<Terminal> get visible => [
    for (final terminal in all)
      if (_matches(terminal)) terminal,
  ];

  bool _matches(Terminal terminal) {
    if (_search.isEmpty) return true;
    final text = '${terminal.name} ${terminal.companyName} ${terminal.plateNumber ?? ''}';
    return text.toLowerCase().contains(_search.toLowerCase());
  }

  Future<void> load() async {
    if (_state is! TerminalsLoaded) _emit(const TerminalsLoading());
    try {
      _emit(TerminalsLoaded(await _api.list()));
    } on ApiClientException catch (failure) {
      _emit(TerminalsFailed(failure));
    }
  }

  void updateSearch(String text) {
    _search = text.trim();
    _notify();
  }

  void _emit(TerminalsState state) {
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
