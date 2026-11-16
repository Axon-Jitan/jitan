import 'dart:convert';

import 'package:jitan_models/jitan_models.dart';

import '../device/secure_store.dart';

/// The employee has left a location and the day is still open (D32).
class AwayFromWorkplace {
  const AwayFromWorkplace({required this.addressId, required this.leftAt, this.name, this.onBreak = false});

  final int addressId;
  final DateTime leftAt;

  /// Answered "Break / personal": nothing more to ask until they return.
  final bool onBreak;

  /// The location's name; `null` if the phone no longer knows it.
  final String? name;
}

/// What the phone remembers between geofence events, which wake the app one
/// at a time: when it entered a location, and that it left one. Never sent
/// anywhere; a leaving is only stored on the server once it is a finish, or
/// part of a trip when another location follows (D40).
class WorkplacePresence {
  const WorkplacePresence(this._store);

  final SecureStore _store;

  static const _enteredKey = 'presence.entered';
  static const _awayKey = 'presence.away';
  static const _namesKey = 'presence.names';
  static const _refusedKey = 'presence.refused';
  static const _tripOriginKey = 'presence.tripOrigin';
  /// Each trip waiting has its own key, named after the moment it began:
  /// adding or confirming one touches only that key, so the app and the
  /// background isolate (two geofence events at once) can't lose or remove
  /// each other's trips (review 2026-11-16).
  static const _tripPrefix = 'presence.trip.';

  /// Trips as stored before: one (`presence.trip`) or a list
  /// (`presence.trips`); moved to their own keys once read.
  static const _oldTripKey = 'presence.trip';
  static const _oldTripsKey = 'presence.trips';

  /// The employee code the remembered events belong to.
  static const _ownerKey = 'presence.owner';

  /// Called when [code] signs in: events remembered for someone else are
  /// dropped, never sent with this employee's session. Events with no owner
  /// (stored before owners were kept) can't be told apart, so they are
  /// dropped too. The same employee signing in again keeps theirs.
  Future<void> belongTo(String code) async {
    if (await _store.read(_ownerKey) != code) {
      for (final key in [_enteredKey, _awayKey, _tripOriginKey, _oldTripKey, _oldTripsKey]) {
        await _store.delete(key);
      }
      for (final key in await _store.keysStartingWith(_tripPrefix)) {
        await _store.delete(key);
      }
    }
    await _store.write(_ownerKey, code);
  }

  /// The locations the phone watches, for their names.
  Future<void> saveNames(List<Location> locations) =>
      _store.write(_namesKey, jsonEncode({for (final l in locations) '${l.id}': l.name}));

  Future<String?> nameOf(int addressId) async {
    final stored = await _store.read(_namesKey);
    if (stored == null) return null;
    return (jsonDecode(stored) as Map<String, Object?>)['$addressId'] as String?;
  }

  Future<void> entered(int addressId, DateTime at) =>
      _store.write(_enteredKey, jsonEncode({'addressId': addressId, 'at': at.toUtc().toIso8601String()}));

  /// The location entered and not yet registered or left, and when.
  Future<({int addressId, DateTime at})?> lastEntered() async {
    final stored = await _store.read(_enteredKey);
    if (stored == null) return null;
    final json = jsonDecode(stored) as Map<String, Object?>;
    return (addressId: json['addressId']! as int, at: DateTime.parse(json['at']! as String));
  }

  /// When the phone entered [addressId]; `null` if it did not see it.
  Future<DateTime?> enteredAt(int addressId) async {
    final entered = await lastEntered();
    return entered?.addressId == addressId ? entered!.at : null;
  }

  Future<void> clearEntered() => _store.delete(_enteredKey);

  Future<void> left(int addressId, DateTime at, {bool onBreak = false}) => _store.write(
    _awayKey,
    jsonEncode({'addressId': addressId, 'leftAt': at.toUtc().toIso8601String(), 'onBreak': onBreak}),
  );

  Future<AwayFromWorkplace?> away() async {
    final stored = await _store.read(_awayKey);
    if (stored == null) return null;
    final json = jsonDecode(stored) as Map<String, Object?>;
    final addressId = json['addressId']! as int;
    return AwayFromWorkplace(
      addressId: addressId,
      leftAt: DateTime.parse(json['leftAt']! as String),
      name: await nameOf(addressId),
      onBreak: json['onBreak'] == true,
    );
  }

  Future<void> clearAway() => _store.delete(_awayKey);

  /// Where the employee came from when they entered a new location. It is a
  /// trip once they stay there; driving past, they are simply still away.
  Future<void> rememberTripOrigin(AwayFromWorkplace away) => _store.write(
    _tripOriginKey,
    jsonEncode({'addressId': away.addressId, 'leftAt': away.leftAt.toUtc().toIso8601String()}),
  );

  Future<({int addressId, DateTime leftAt})?> tripOrigin() async {
    final stored = await _store.read(_tripOriginKey);
    if (stored == null) return null;
    final json = jsonDecode(stored) as Map<String, Object?>;
    return (addressId: json['addressId']! as int, leftAt: DateTime.parse(json['leftAt']! as String));
  }

  Future<void> clearTripOrigin() => _store.delete(_tripOriginKey);

  /// A trip the server hasn't confirmed yet. It never replaces another one
  /// (kilometres are paid); the same trip held twice is one.
  Future<void> holdTrip(TripRequest trip) => _store.write(_keyOf(trip), jsonEncode(trip.toJson()));

  /// The trips waiting, oldest first.
  Future<List<TripRequest>> heldTrips() async {
    await _moveOldTrips();
    final keys = (await _store.keysStartingWith(_tripPrefix))..sort();
    return [
      for (final key in keys)
        if (await _store.read(key) case final stored?) TripRequest.fromJson(jsonDecode(stored) as Map<String, Object?>),
    ];
  }

  /// The oldest trip waiting, or `null`.
  Future<TripRequest?> heldTrip() async => (await heldTrips()).firstOrNull;

  /// [trip] is done: the server confirmed or refused it. Only that trip.
  Future<void> clearHeldTrip(TripRequest trip) => _store.delete(_keyOf(trip));

  /// Zero-padded milliseconds since 1970 of the leaving and the arrival:
  /// sorts in time order, and one trip always has the same key.
  static String _keyOf(TripRequest trip) =>
      '$_tripPrefix${trip.leftAt.millisecondsSinceEpoch.toString().padLeft(15, '0')}'
      '.${trip.arrivedAt.millisecondsSinceEpoch.toString().padLeft(15, '0')}';

  Future<void> _moveOldTrips() async {
    final one = await _store.read(_oldTripKey);
    final list = await _store.read(_oldTripsKey);
    if (one == null && list == null) return;
    for (final json in [
      if (list != null) ...[for (final t in jsonDecode(list) as List<Object?>) t! as Map<String, Object?>],
      if (one != null) jsonDecode(one) as Map<String, Object?>,
    ]) {
      await holdTrip(TripRequest.fromJson(json));
    }
    await _store.delete(_oldTripKey);
    await _store.delete(_oldTripsKey);
  }

  /// The phone refused the geofences (Google Location Accuracy off, …).
  Future<bool> geofencesRefused() async => await _store.read(_refusedKey) != null;

  Future<void> setGeofencesRefused(bool refused) =>
      refused ? _store.write(_refusedKey, 'true') : _store.delete(_refusedKey);
}
