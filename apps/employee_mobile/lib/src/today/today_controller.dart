import 'package:flutter/foundation.dart';
import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:jitan_models/jitan_models.dart';

import '../geofencing/away_reminder.dart';
import '../geofencing/geofence_event_handler.dart';
import '../geofencing/workplace_presence.dart';

/// Which "Today" screen the day calls for.
enum TodayPhase {
  /// Never registered: "When did you arrive?" right after onboarding (22:2).
  firstDay,

  /// "Good morning, Disan." and Start work (1444:3).
  notStarted,

  /// "You're working." and Finish work (1436:128).
  working,

  /// "Your day is complete." (1436:213).
  complete,
}

sealed class TodayState {
  const TodayState();
}

class TodayLoading extends TodayState {
  const TodayLoading();
}

class TodayLoaded extends TodayState {
  const TodayLoaded(this.day);

  final MyDay day;
}

class TodayFailed extends TodayState {
  const TodayFailed(this.failure);

  final ApiClientException failure;
}

/// The employee's day on the phone: loads `GET /me/today` and registers
/// start and finish (`POST /me/time-registrations`). Every status, time and
/// total comes from the server; after a registration the day is loaded
/// again rather than guessed (rules §6, §21).
///
/// Offline queueing is not built yet (PRODUCT_CLARIFICATIONS, offline): a
/// registration that can't reach the server fails visibly and is not kept.
class TodayController extends ChangeNotifier {
  TodayController(this._api, {required this._presence, required this._reminder, required this.onSessionEnded, DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final TimeRegistrationsApi _api;
  final WorkplacePresence _presence;
  final AwayReminder _reminder;
  final DateTime Function() _clock;

  /// A 401: the session is no longer valid.
  final VoidCallback onSessionEnded;

  TodayState state = const TodayLoading();

  /// Left a location while the day runs (D32); `null` otherwise.
  AwayFromWorkplace? away;

  /// "Start work" / "Finish work" is being sent.
  bool busy = false;

  /// Why the last Start work / Finish work failed; `null` otherwise.
  ApiClientException? registerFailure;

  bool _disposed = false;

  DateTime now() => _clock();

  static TodayPhase phaseOf(MyDay myDay) {
    final day = myDay.day;
    if (day == null || day.status == TimeRecordStatus.nonWork) {
      return myDay.firstDay ? TodayPhase.firstDay : TodayPhase.notStarted;
    }
    bool pending(RegistrationBoundary b) => day.pending.any((p) => p.boundary == b);
    // Came back after a finish, with a finish time still waiting for HR.
    final registered = [for (final e in day.events) if (e.active && e.kind == TimeRecordEventKind.registered) e];
    final finishedBefore = registered.any((e) => e.boundary == RegistrationBoundary.finish);
    if (day.finish == null && finishedBefore && registered.lastOrNull?.boundary == RegistrationBoundary.start) {
      return TodayPhase.working;
    }
    if (day.finish != null || pending(RegistrationBoundary.finish)) return TodayPhase.complete;
    if (day.start != null || pending(RegistrationBoundary.start)) return TodayPhase.working;
    return TodayPhase.notStarted;
  }

  Future<void> load() async {
    try {
      final day = await _api.today();
      away = await _awayOn(day);
      _set(TodayLoaded(day));
    } on ApiClientException catch (e) {
      if (e.statusCode == 401) return onSessionEnded();
      // Keep showing the day already loaded; only a first load fails.
      if (state is! TodayLoaded) _set(TodayFailed(e));
    }
  }

  /// Being away only means something today, while the day runs or during a
  /// break; otherwise it is forgotten.
  Future<AwayFromWorkplace?> _awayOn(MyDay day) async {
    final remembered = await _presence.away();
    if (remembered == null) return null;
    final left = remembered.leftAt.toLocal();
    final now = _clock();
    final sameDay = left.year == now.year && left.month == now.month && left.day == now.day;
    if (sameDay && (remembered.onBreak || phaseOf(day) == TodayPhase.working)) return remembered;
    await _forgetAway();
    return null;
  }

  Future<void> _forgetAway() async {
    await _presence.clearAway();
    await _reminder.cancel();
  }

  /// An hour away with no answer yet: "We need one answer." (Figma 19:76).
  bool get needsAnswer {
    final left = away;
    return left != null && !left.onBreak && _clock().difference(left.leftAt) >= GeofenceEventHandler.questionAfter;
  }

  /// Every answer stores the time they left as a finish (D34b).
  Future<void> _finishAtLeaving(AwayFromWorkplace left) => _api.register(
    RegisterTimeRequest(
      boundary: RegistrationBoundary.finish,
      method: TimeRegistrationMethod.geofence,
      entry: RegistrationEntry.now,
      at: left.leftAt.toUtc(),
      addressId: left.addressId,
    ),
  );

  Future<void> _answer(Future<void> Function(AwayFromWorkplace left) after) async {
    final left = away;
    if (left == null) return;
    busy = true;
    registerFailure = null;
    _notify();
    try {
      await _finishAtLeaving(left);
      await after(left);
      await load();
    } on ApiClientException catch (e) {
      if (e.statusCode == 401) return onSessionEnded();
      registerFailure = e;
    } finally {
      busy = false;
      _notify();
    }
  }

  /// "Finished work": the day ends at the time they left.
  Future<void> answerFinished() => _answer((_) => _forgetAway());

  /// "Break / personal": the time away is not work; coming back starts again.
  Future<void> answerBreak() => _answer((left) async {
    await _presence.left(left.addressId, left.leftAt, onBreak: true);
    await _reminder.cancel();
  });

  /// "Travelling for work" / "Other": the time they enter, with a reason,
  /// waits for HR (D31). Throws [ApiClientException] for the screen to show.
  Future<void> answerWithTime(int hour, int minute, String reason) async {
    final left = away;
    if (left == null) return;
    await _finishAtLeaving(left);
    await registerAt(RegistrationBoundary.finish, RegistrationEntry.corrected, hour, minute, reason: reason);
    await _forgetAway();
    await load();
  }

  Future<void> retry() async {
    _set(const TodayLoading());
    await load();
  }

  /// "Start work" / "Finish work": registered at this moment (entry `now`).
  Future<void> registerNow(RegistrationBoundary boundary) async {
    busy = true;
    registerFailure = null;
    _notify();
    try {
      await _api.register(
        RegisterTimeRequest(
          boundary: boundary,
          method: TimeRegistrationMethod.manual,
          entry: RegistrationEntry.now,
          at: _clock().toUtc(),
        ),
      );
      await load();
    } on ApiClientException catch (e) {
      if (e.statusCode == 401) return onSessionEnded();
      registerFailure = e;
    } finally {
      busy = false;
      _notify();
    }
  }

  /// A time the employee entered ([entry] corrected or first day) at
  /// [hour]:[minute] on the phone's today. Throws [ApiClientException] for
  /// the time entry screen to show; reloads the day after success.
  Future<void> registerAt(RegistrationBoundary boundary, RegistrationEntry entry, int hour, int minute, {String? reason}) async {
    final today = _clock();
    try {
      await _api.register(
        RegisterTimeRequest(
          boundary: boundary,
          method: TimeRegistrationMethod.manual,
          entry: entry,
          at: DateTime(today.year, today.month, today.day, hour, minute).toUtc(),
          reason: reason,
        ),
      );
    } on ApiClientException catch (e) {
      if (e.statusCode == 401) onSessionEnded();
      rethrow;
    }
    await load();
  }

  void _set(TodayState value) {
    state = value;
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
