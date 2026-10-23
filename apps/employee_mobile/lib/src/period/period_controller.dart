import 'package:flutter/foundation.dart';
import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:jitan_models/jitan_models.dart';

/// Period's view (Figma 398:6 menu).
enum PeriodView { day, week, month }

sealed class PeriodState {
  const PeriodState();
}

class PeriodLoading extends PeriodState {
  const PeriodLoading();
}

/// "This day": today as on the Today screen.
class PeriodDayLoaded extends PeriodState {
  const PeriodDayLoaded(this.today);

  final MyDay today;
}

/// "This week" / "This month".
class PeriodRangeLoaded extends PeriodState {
  const PeriodRangeLoaded(this.period);

  final MyPeriod period;
}

class PeriodFailed extends PeriodState {
  const PeriodFailed(this.failure);

  final ApiClientException failure;
}

/// The employee's Period: today, this week or this month, read from the
/// server (`GET /me/today`, `GET /me/period`). Every total and status comes
/// from the server; nothing is calculated here (rule §6).
class PeriodController extends ChangeNotifier {
  PeriodController(this._api, {required this.onSessionEnded, DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  final TimeRegistrationsApi _api;
  final DateTime Function() _clock;

  /// A 401: the session is no longer valid.
  final VoidCallback onSessionEnded;

  PeriodView _view = PeriodView.day;
  PeriodView get view => _view;

  PeriodState _state = const PeriodLoading();
  PeriodState get state => _state;

  bool _disposed = false;

  DateTime now() => _clock();

  /// Today as a calendar day.
  DateTime get today {
    final n = _clock();
    return DateTime.utc(n.year, n.month, n.day);
  }

  /// The days of the current view: Monday to Sunday, or the whole month.
  (DateTime, DateTime) get range {
    final t = today;
    return switch (_view) {
      PeriodView.day => (t, t),
      PeriodView.week => (t.subtract(Duration(days: t.weekday - 1)), t.add(Duration(days: 7 - t.weekday))),
      PeriodView.month => (DateTime.utc(t.year, t.month), DateTime.utc(t.year, t.month + 1, 0)),
    };
  }

  void select(PeriodView view) {
    if (view == _view) return;
    _view = view;
    load();
  }

  Future<void> load() async {
    _set(const PeriodLoading());
    try {
      if (_view == PeriodView.day) {
        _set(PeriodDayLoaded(await _api.today()));
      } else {
        final (from, to) = range;
        _set(PeriodRangeLoaded(await _api.period(from: from, to: to)));
      }
    } on ApiClientException catch (e) {
      if (e.statusCode == 401) return onSessionEnded();
      _set(PeriodFailed(e));
    }
  }

  void _set(PeriodState value) {
    _state = value;
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
