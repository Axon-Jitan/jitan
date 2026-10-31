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
/// anywhere; a leaving is only stored on the server once it is a finish.
class WorkplacePresence {
  const WorkplacePresence(this._store);

  final SecureStore _store;

  static const _enteredKey = 'presence.entered';
  static const _awayKey = 'presence.away';
  static const _namesKey = 'presence.names';
  static const _refusedKey = 'presence.refused';

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

  /// The phone refused the geofences (Google Location Accuracy off, …).
  Future<bool> geofencesRefused() async => await _store.read(_refusedKey) != null;

  Future<void> setGeofencesRefused(bool refused) =>
      refused ? _store.write(_refusedKey, 'true') : _store.delete(_refusedKey);
}
