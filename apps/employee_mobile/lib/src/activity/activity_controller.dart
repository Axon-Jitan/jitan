import 'package:flutter/foundation.dart';
import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:jitan_models/jitan_models.dart';

/// What the employee is on, for Home. It never gets in the way of the day:
/// when it can't be loaded, Home simply shows no project card.
class ActivityController extends ChangeNotifier {
  ActivityController(this._api, {this.onSwitched, DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  final ActivityApi _api;
  final DateTime Function() _clock;

  /// A switch was saved: the day's totals may have changed (D39).
  final VoidCallback? onSwitched;

  MyActivity _activity = MyActivity.disabled;
  MyActivity get activity => _activity;

  bool _disposed = false;

  /// Worth a card: something to show, or something to choose from.
  bool get showsCard => _activity.enabled && (_activity.current?.project != null || _activity.projects.isNotEmpty);

  Future<void> load() async {
    try {
      _set(await _api.mine());
    } on ApiClientException {
      // Keeps what it had; the day itself is not affected.
    }
  }

  /// Throws what the server refused, for the screen to show.
  Future<void> switchTo({required ActivityKind kind, int? projectId}) async {
    _set(await _api.switchTo(SwitchActivityRequest(kind: kind, at: _clock().toUtc(), projectId: projectId)));
    onSwitched?.call();
  }

  void _set(MyActivity activity) {
    _activity = activity;
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
