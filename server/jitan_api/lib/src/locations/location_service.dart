import 'package:jitan_models/jitan_models.dart';

import '../audit/audit_event.dart';
import '../audit/audit_log_repository.dart';
import '../database/database_exception.dart';
import '../database/sql_executor.dart';
import '../http/api_exception.dart';
import 'location_repository.dart';

/// HR/Admin managing locations (Figma `1465:2` … `1465:846`, D36). The ERD
/// has no link from an address to a company yet (GAP-03), so locations are
/// one shared list. Every change is audited in the same transaction; an
/// action that changes nothing is not.
class LocationService {
  LocationService({
    required this._locations,
    required this._audit,
    required this._transactions,
    required this._executor,
  });

  final LocationRepository _locations;
  final AuditLogRepository _audit;
  final TransactionRunner _transactions;
  final SqlExecutor _executor;

  Future<List<Location>> all() => _locations.all(_executor);

  /// The locations a phone watches: active, with a usable pin.
  Future<List<Location>> recognised() async => [
    for (final location in await all())
      if (location.isActive && location.point != null) location,
  ];

  Future<Location> create(int actorUserId, LocationRequest request) async {
    final location = validated(request);
    final keys = await _write(location, (tx) async {
      final keys = await _locations.insert(tx, location);
      await _record(tx, AuditEventType.locationCreated, actorUserId, keys);
      return keys;
    });
    return find(keys.addressId);
  }

  Future<Location> update(int actorUserId, int locationId, LocationRequest request) async {
    final location = validated(request);
    await _write(location, (tx) async {
      final (current, keys) = await _lock(tx, locationId);
      if (_same(current, location)) return;
      await _locations.update(tx, keys, location);
      await _record(tx, AuditEventType.locationChanged, actorUserId, keys);
    });
    return find(locationId);
  }

  Future<Location> setActive(int actorUserId, int locationId, {required bool active}) async {
    await _transactions.transaction((tx) async {
      final (current, keys) = await _lock(tx, locationId);
      if (current.isActive == active) return;
      await _locations.setActive(tx, locationId, active: active);
      await _record(
        tx,
        active ? AuditEventType.locationReactivated : AuditEventType.locationDeactivated,
        actorUserId,
        keys,
      );
    });
    return find(locationId);
  }

  Future<Location> find(int locationId) async =>
      await _locations.find(_executor, locationId) ?? (throw _notFound(locationId));

  Future<(Location, LocationKeys)> _lock(SqlExecutor tx, int locationId) async =>
      await _locations.lock(tx, locationId) ?? (throw _notFound(locationId));

  /// The name's unique key covers every address, so a name in use is only
  /// known from the insert or update itself.
  Future<T> _write<T>(LocationRequest location, Future<T> Function(SqlExecutor tx) action) async {
    try {
      return await _transactions.transaction(action);
    } on DatabaseQueryException catch (e) {
      if (e.isDuplicateKey) {
        throw ApiException(
          409,
          ApiErrorCode.duplicateLocationName,
          'A location named "${location.name}" already exists.',
          field: LocationRequest.fieldName,
        );
      }
      if (e.isValueTooLong) throw const ApiException.badRequest('A value is longer than allowed.');
      rethrow;
    }
  }

  Future<void> _record(SqlExecutor tx, AuditEventType type, int actorUserId, LocationKeys keys) => _audit.record(
    tx,
    AuditEvent(
      type: type,
      actorUserId: actorUserId,
      references: {
        EventLogReference.address: keys.addressId,
        EventLogReference.geofence: keys.geofenceId,
        EventLogReference.geofenceAddress: keys.geofenceAddressId,
      },
    ),
  );

  static bool _same(Location current, LocationRequest next) =>
      current.name == next.name &&
      current.street == next.street &&
      current.number == next.number &&
      current.box == next.box &&
      current.zipcode == next.zipcode &&
      current.city == next.city &&
      current.radiusMeters == next.radiusMeters &&
      current.point != null &&
      LocationRepository.formatCoordinates(current.point!) == LocationRepository.formatCoordinates(next.point);

  /// The request with trimmed texts and empty optional ones as `null`; 400
  /// naming the field otherwise.
  static LocationRequest validated(LocationRequest r) {
    final name = _required(r.name, LocationRequest.fieldName, LocationRequest.maxNameLength, 'a name');
    final street = _required(r.street, LocationRequest.fieldStreet, LocationRequest.maxStreetLength, 'a street');
    if (!r.point.isValid) {
      throw const ApiException.validation(LocationRequest.fieldPoint, 'Place the pin on the map.');
    }
    if (r.radiusMeters < LocationRequest.minRadiusMeters || r.radiusMeters > LocationRequest.maxRadiusMeters) {
      throw const ApiException.validation(
        LocationRequest.fieldRadius,
        'The area must be ${LocationRequest.minRadiusMeters} to ${LocationRequest.maxRadiusMeters} metres.',
      );
    }
    return LocationRequest(
      name: name,
      street: street,
      number: _optional(r.number, LocationRequest.fieldNumber, LocationRequest.maxNumberLength),
      box: _optional(r.box, LocationRequest.fieldBox, LocationRequest.maxBoxLength),
      zipcode: _optional(r.zipcode, LocationRequest.fieldZipcode, LocationRequest.maxZipcodeLength),
      city: _optional(r.city, LocationRequest.fieldCity, LocationRequest.maxCityLength),
      point: r.point,
      radiusMeters: r.radiusMeters,
    );
  }

  static String _required(String raw, String field, int max, String what) {
    final value = raw.trim();
    if (value.isEmpty) throw ApiException.validation(field, 'Enter $what.');
    return _short(value, field, max);
  }

  static String? _optional(String? raw, String field, int max) {
    final value = raw?.trim();
    if (value == null || value.isEmpty) return null;
    return _short(value, field, max);
  }

  static String _short(String value, String field, int max) {
    if (value.runes.length > max) throw ApiException.validation(field, 'Use at most $max characters.');
    return value;
  }

  static ApiException _notFound(int id) => ApiException.notFound('Location $id does not exist.');
}
