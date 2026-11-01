import 'package:flutter/foundation.dart';
import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:jitan_models/jitan_models.dart';

/// One month of the employee's days. The server counts everything; "to fix"
/// is the days they can do something about.
class PeriodController extends ChangeNotifier {
  PeriodController(this._api, {DateTime Function()? clock}) : _clock = clock ?? DateTime.now {
    final now = _clock();
    _month = DateTime(now.year, now.month);
  }

  final TimeRegistrationsApi _api;
  final DateTime Function() _clock;

  late DateTime _month;
  DateTime get month => _month;

  MyPeriod? _period;
  MyPeriod? get period => _period;

  bool _failed = false;
  bool get failed => _failed;
  bool get loading => _period == null && !_failed;

  bool _disposed = false;

  bool get canGoNext {
    final now = _clock();
    return _month.isBefore(DateTime(now.year, now.month));
  }

  /// The days worth a line: planned or with something registered.
  List<MyPeriodDay> get days => [
    for (final day in _period?.days ?? const <MyPeriodDay>[])
      if (day.day != null) day,
  ];

  int get toFix => days.where(isToFix).length;

  static bool isToFix(MyPeriodDay day) => switch (day.day?.status) {
    TimeRecordStatus.missingStart || TimeRecordStatus.missingFinish || TimeRecordStatus.noRegistration => true,
    _ => false,
  };

  Future<void> load() async {
    _failed = false;
    _notify();
    final now = _clock();
    final last = DateTime(_month.year, _month.month + 1, 0);
    final today = DateTime(now.year, now.month, now.day);
    try {
      _period = await _api.period(from: _month, to: last.isAfter(today) ? today : last);
    } on ApiClientException {
      _period = null;
      _failed = true;
    }
    _notify();
  }

  Future<void> go(int months) async {
    _month = DateTime(_month.year, _month.month + months);
    _period = null;
    await load();
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
