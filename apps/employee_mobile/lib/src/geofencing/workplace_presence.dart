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
  static const _tripsKey = 'presence.trips';

  /// One trip, as stored before 2026-11-16; read once into [_tripsKey].
  static const _oldTripKey = 'presence.trip';

  /// The employee code the remembered events belong to.
  static const _ownerKey = 'presence.owner';

  /// Called when [code] signs in: events remembered for someone else are
  /// dropped, never sent with this employee's session (review 2026-11-16).
  /// The same employee signing in again keeps theirs.
  Future<void> belongTo(String code) async {
    final owner = await _store.read(_ownerKey);
    if (owner != null && owner != code) {
      for (final key in [_enteredKey, _awayKey, _tripOriginKey, _tripsKey, _oldTripKey]) {
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

  /// A trip the server hasn't confirmed yet, after the ones already waiting:
  /// a new trip never replaces an unsent one (kilometres are paid).
  Future<void> holdTrip(TripRequest trip) async => _writeTrips([...await heldTrips(), trip.toJson()]);

  /// The trips waiting, oldest first.
  Future<List<Map<String, Object?>>> heldTrips() async {
    final old = await _store.read(_oldTripKey);
    if (old != null) {
      final stored = await _store.read(_tripsKey);
      final trips = [
        if (stored != null) ...[for (final t in jsonDecode(stored) as List<Object?>) t! as Map<String, Object?>],
        jsonDecode(old) as Map<String, Object?>,
      ];
      await _writeTrips(trips);
      await _store.delete(_oldTripKey);
      return trips;
    }
    final stored = await _store.read(_tripsKey);
    return stored == null ? [] : [for (final t in jsonDecode(stored) as List<Object?>) t! as Map<String, Object?>];
  }

  /// The oldest trip waiting, or `null`.
  Future<TripRequest?> heldTrip() async {
    final trips = await heldTrips();
    return trips.isEmpty ? null : TripRequest.fromJson(trips.first);
  }

  /// Removes the oldest trip waiting: the server confirmed or refused it.
  Future<void> clearHeldTrip() async {
    final trips = await heldTrips();
    if (trips.isNotEmpty) await _writeTrips(trips.sublist(1));
  }

  Future<void> _writeTrips(List<Map<String, Object?>> trips) =>
      trips.isEmpty ? _store.delete(_tripsKey) : _store.write(_tripsKey, jsonEncode(trips));

  /// The phone refused the geofences (Google Location Accuracy off, …).
  Future<bool> geofencesRefused() async => await _store.read(_refusedKey) != null;

  Future<void> setGeofencesRefused(bool refused) =>
      refused ? _store.write(_refusedKey, 'true') : _store.delete(_refusedKey);
}
