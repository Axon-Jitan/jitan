import 'dart:convert';

import 'package:jitan_models/jitan_models.dart';

import '../device/secure_store.dart';

/// The employee has left a location and the day is still open (D32).
class AwayFromWorkplace {
  const AwayFromWorkplace({required this.addressId, required this.leftAt, this.name});

  final int addressId;
  final DateTime leftAt;

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

  /// When the phone entered [addressId]; `null` if it did not see it.
  Future<DateTime?> enteredAt(int addressId) async {
    final stored = await _store.read(_enteredKey);
    if (stored == null) return null;
    final json = jsonDecode(stored) as Map<String, Object?>;
    return json['addressId'] == addressId ? DateTime.parse(json['at']! as String) : null;
  }

  Future<void> clearEntered() => _store.delete(_enteredKey);

  Future<void> left(int addressId, DateTime at) =>
      _store.write(_awayKey, jsonEncode({'addressId': addressId, 'leftAt': at.toUtc().toIso8601String()}));

  Future<AwayFromWorkplace?> away() async {
    final stored = await _store.read(_awayKey);
    if (stored == null) return null;
    final json = jsonDecode(stored) as Map<String, Object?>;
    final addressId = json['addressId']! as int;
    return AwayFromWorkplace(
      addressId: addressId,
      leftAt: DateTime.parse(json['leftAt']! as String),
      name: await nameOf(addressId),
    );
  }

  Future<void> clearAway() => _store.delete(_awayKey);
}
