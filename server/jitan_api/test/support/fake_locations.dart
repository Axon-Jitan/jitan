import 'package:jitan_api/src/database/database_exception.dart';
import 'package:jitan_api/src/database/sql_executor.dart';
import 'package:jitan_api/src/locations/location_repository.dart';
import 'package:jitan_models/jitan_models.dart';

/// Locations in memory. The name is unique, as in `tblAddress`.
class FakeLocationRepository implements LocationRepository {
  final locations = <int, Location>{};
  var _next = 1;

  LocationKeys _keys(int id) => (addressId: id, geofenceId: id + 100, geofenceAddressId: id + 200);

  void _checkName(String name, {int? except}) {
    if (locations.values.any((l) => l.id != except && l.name == name)) {
      throw const DatabaseQueryException('Duplicate entry', errorCode: 1062);
    }
  }

  Location _toLocation(int id, LocationRequest r, {required bool isActive}) => Location(
    id: id,
    name: r.name,
    street: r.street,
    number: r.number,
    box: r.box,
    zipcode: r.zipcode,
    city: r.city,
    point: r.point,
    radiusMeters: r.radiusMeters,
    isActive: isActive,
  );

  @override
  Future<List<Location>> all(SqlExecutor executor) async => locations.values.toList();

  @override
  Future<Location?> find(SqlExecutor executor, int addressId) async => locations[addressId];

  @override
  Future<(Location, LocationKeys)?> lock(SqlExecutor tx, int addressId) async {
    final location = locations[addressId];
    return location == null ? null : (location, _keys(addressId));
  }

  @override
  Future<LocationKeys> insert(SqlExecutor tx, LocationRequest location) async {
    _checkName(location.name);
    final id = _next++;
    locations[id] = _toLocation(id, location, isActive: true);
    return _keys(id);
  }

  @override
  Future<void> update(SqlExecutor tx, LocationKeys keys, LocationRequest location) async {
    final id = keys.addressId;
    _checkName(location.name, except: id);
    locations[id] = _toLocation(id, location, isActive: locations[id]!.isActive);
  }

  @override
  Future<void> setActive(SqlExecutor tx, int addressId, {required bool active}) async {
    final l = locations[addressId]!;
    locations[addressId] = Location(
      id: l.id,
      name: l.name,
      street: l.street,
      number: l.number,
      box: l.box,
      zipcode: l.zipcode,
      city: l.city,
      point: l.point,
      radiusMeters: l.radiusMeters,
      isActive: active,
    );
  }
}
