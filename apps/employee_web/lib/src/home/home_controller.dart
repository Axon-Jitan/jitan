import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:jitan_models/jitan_models.dart';

/// Today, kept fresh while Home is open. Holds no rules: the server says what
/// the day is, and the running total is display only.
class HomeController extends ChangeNotifier {
  HomeController({required this._times, required this._activities, DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  final TimeRegistrationsApi _times;
  final ActivityApi _activities;
  final DateTime Function() _clock;

  static const _refreshEvery = Duration(minutes: 1);

  MyDay? _day;
  MyDay? get day => _day;

  MyActivity _activity = MyActivity.disabled;
  MyActivity get activity => _activity;

  bool _failed = false;

  /// Nothing to show: the page says Jitan can't be reached.
  bool get failed => _failed && _day == null;

  bool get loading => _day == null && !_failed;

  DateTime get now => _clock();

  Timer? _refresh;
  bool _disposed = false;

  Future<void> start() async {
    await load();
    _refresh = Timer.periodic(_refreshEvery, (_) => load());
  }

  Future<void> load() async {
    _failed = false;
    _notify();
    try {
      _day = await _times.today();
      _activity = await _activities.mine();
    } on ApiClientException {
      // What was on the screen stays; with nothing, the page says so.
      _failed = true;
    }
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _refresh?.cancel();
    super.dispose();
  }
}
