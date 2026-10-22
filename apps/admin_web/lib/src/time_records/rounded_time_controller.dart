import 'package:flutter/widgets.dart';
import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:jitan_models/jitan_models.dart';

/// One time HR types in a correction (`HH:mm`, workplace-local) and what it
/// counts as after rounding. The rounded time always comes from the server
/// (`…/rounding`): the client never rounds (rule §6).
class RoundedTimeController extends ChangeNotifier {
  RoundedTimeController({required this._preview, String? initial, String? initialRounded})
    : _counted = initial ?? '',
      rounded = initialRounded,
      text = TextEditingController(text: initial ?? '') {
    _last = value;
    text.addListener(_changed);
  }

  final Future<String> Function(String time) _preview;
  final TextEditingController text;

  /// The time as the server counts it now; `null` while unknown.
  String? rounded;

  /// The server found no schedule with rounding for this day.
  bool noRounding = false;

  String _counted;
  String _last = '';
  int _request = 0;
  bool _disposed = false;

  String get value => text.text.trim();

  bool get isValid {
    try {
      CorrectTimeRequest.localTime(value);
      return true;
    } on FormatException {
      return false;
    }
  }

  /// Different from the time that already counts (or was saved last).
  bool get isChanged => value != _counted;

  /// After the server saved [value]: it is now the time that counts.
  void markSaved() => _counted = value;

  void _changed() {
    if (value == _last) return;
    _last = value;
    rounded = null;
    noRounding = false;
    notifyListeners();
    if (isValid) _fetch();
  }

  Future<void> _fetch() async {
    final request = ++_request;
    final time = value;
    try {
      final result = await _preview(time);
      if (_disposed || request != _request) return;
      rounded = result;
    } on ApiClientException catch (failure) {
      if (_disposed || request != _request) return;
      noRounding = failure.error?.code == ApiErrorCode.configurationError;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    text.dispose();
    super.dispose();
  }
}
