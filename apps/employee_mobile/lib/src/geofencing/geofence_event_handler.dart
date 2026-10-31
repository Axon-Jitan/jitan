import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:logging/logging.dart';

import '../today/today_controller.dart';
import 'workplace_presence.dart';

final _log = Logger('geofencing');

/// What the phone reports about a location.
enum GeofenceChange { entered, stayed, left }

/// Turns the phone's geofence events into registrations (D32, D33). No time
/// rule lives here: the server rounds, and adds nothing to a running day.
///
/// - Entered: remember the moment. Back at a recognised location, the employee
///   is no longer away.
/// - Stayed [arrivalDelay] inside: register the start, at the moment of
///   entering.
/// - Left: only remembered, while the day runs. Leaving is not a finish.
///
/// Android may deliver "stayed" late or not at all, so [catchUp] (the app
/// opens) and leaving apply the same rule from the stored moment of entering.
///
/// A start that can't be sent is lost here and the Today screen still offers
/// Start work; queueing waits for PRODUCT-CLARIFY-OFFLINE.
class GeofenceEventHandler {
  GeofenceEventHandler({required this._api, required this._presence, DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final TimeRegistrationsApi _api;
  final WorkplacePresence _presence;
  final DateTime Function() _clock;

  /// How long inside before an arrival counts (D33).
  static const arrivalDelay = Duration(minutes: 5);

  Future<void> handle(GeofenceChange change, int addressId) => switch (change) {
    GeofenceChange.entered => _entered(addressId),
    GeofenceChange.stayed => _stayed(addressId),
    GeofenceChange.left => _left(addressId),
  };

  Future<void> _entered(int addressId) async {
    await _presence.entered(addressId, _clock());
    await _presence.clearAway();
  }

  /// Registers an arrival whose "stayed" event never came.
  Future<void> catchUp() async {
    final entered = await _presence.lastEntered();
    if (entered != null && _longEnough(entered.at)) await _stayed(entered.addressId);
  }

  bool _longEnough(DateTime enteredAt) => _clock().difference(enteredAt) >= arrivalDelay;

  Future<void> _stayed(int addressId) async {
    final at = await _presence.enteredAt(addressId) ?? _clock().subtract(arrivalDelay);
    await _presence.clearEntered();
    try {
      await _api.register(
        RegisterTimeRequest(
          boundary: RegistrationBoundary.start,
          method: TimeRegistrationMethod.geofence,
          entry: RegistrationEntry.now,
          at: at.toUtc(),
          addressId: addressId,
        ),
      );
    } on ApiClientException catch (e) {
      _log.warning('The arrival could not be sent: ${e.kind.name} ${e.statusCode ?? ''}');
    }
  }

  Future<void> _left(int addressId) async {
    final entered = await _presence.enteredAt(addressId);
    if (entered != null && _longEnough(entered)) await _stayed(addressId);
    await _presence.clearEntered();
    final now = _clock();
    try {
      final day = await _api.today();
      if (TodayController.phaseOf(day) == TodayPhase.working) await _presence.left(addressId, now);
    } on ApiClientException catch (e) {
      // Offline: remember it. Today only shows it while the day is running.
      _log.warning('The day could not be read on leaving: ${e.kind.name} ${e.statusCode ?? ''}');
      await _presence.left(addressId, now);
    }
  }
}
