import 'package:jitan_models/jitan_models.dart';

import '../database/db_row.dart';
import '../database/sql_executor.dart';

/// A location's row IDs: what its audit events reference.
typedef LocationKeys = ({int addressId, int geofenceId, int geofenceAddressId});

/// Data access for locations: a `tblAddress` row linked to one `tblGeofence`
/// through `tblGeofenceAddress`. An address with no active geofence is not a
/// location. Writes run in the caller's transaction, and nothing is deleted:
/// deactivating sets `addressActive = 0`, and the rows stay.
class LocationRepository {
  const LocationRepository();

  static const _select =
      'SELECT a.addressID, a.addressLogicalName, a.addressStreet, a.addressNumber, a.addressBoxNumber, '
      'a.addressZipcode, a.addressCity, a.addressCoordinates, a.addressActive, g.geofenceRadiusInMeter '
      'FROM tblAddress a '
      'JOIN tblGeofenceAddress ga ON ga.addressID = a.addressID AND ga.geofenceAddressActive = 1 '
      'AND ga.geofenceAddressMFD = 0 '
      'JOIN tblGeofence g ON g.geofenceID = ga.geofenceID AND g.geofenceActive = 1 AND g.geofenceMFD = 0 '
      'WHERE a.addressMFD = 0';

  /// Every location, active or not, by name.
  Future<List<Location>> all(SqlExecutor executor) async => [
    for (final row in await executor.query('$_select ORDER BY a.addressLogicalName, a.addressID')) _toLocation(row),
  ];

  /// One location; `null` when it does not exist or is marked for deletion.
  Future<Location?> find(SqlExecutor executor, int addressId) async {
    final rows = await executor.query('$_select AND a.addressID = :id', {'id': addressId});
    return rows.isEmpty ? null : _toLocation(rows.first);
  }

  /// The location, its rows locked for the rest of the transaction.
  Future<(Location, LocationKeys)?> lock(SqlExecutor tx, int addressId) async {
    final rows = await tx.query(
      '${_select.replaceFirst(' FROM tblAddress', ', g.geofenceID, ga.geofenceAddressID FROM tblAddress')} '
      'AND a.addressID = :id FOR UPDATE',
      {'id': addressId},
    );
    if (rows.isEmpty) return null;
    final row = rows.first;
    return (
      _toLocation(row),
      (addressId: addressId, geofenceId: row.readInt('geofenceID'), geofenceAddressId: row.readInt('geofenceAddressID')),
    );
  }

  /// Adds the address, its geofence and their link.
  Future<LocationKeys> insert(SqlExecutor tx, LocationRequest location) async {
    final addressId = (await tx.execute(
      'INSERT INTO tblAddress (addressStreet, addressNumber, addressBoxNumber, addressZipcode, addressCity, '
      'addressLogicalName, addressCoordinates, addressActive, addressMFD) '
      'VALUES (:street, :number, :box, :zipcode, :city, :name, :coordinates, 1, 0)',
      _addressParameters(location),
    )).lastInsertId;
    final geofenceId = (await tx.execute(
      'INSERT INTO tblGeofence (geofenceRadiusInMeter, geofenceActive, geofenceMFD) VALUES (:radius, 1, 0)',
      {'radius': location.radiusMeters},
    )).lastInsertId;
    final linkId = (await tx.execute(
      'INSERT INTO tblGeofenceAddress (geofenceID, addressID, geofenceAddressActive, geofenceAddressMFD) '
      'VALUES (:geofence, :address, 1, 0)',
      {'geofence': geofenceId, 'address': addressId},
    )).lastInsertId;
    return (addressId: addressId, geofenceId: geofenceId, geofenceAddressId: linkId);
  }

  Future<void> update(SqlExecutor tx, LocationKeys keys, LocationRequest location) async {
    await tx.execute(
      'UPDATE tblAddress SET addressStreet = :street, addressNumber = :number, addressBoxNumber = :box, '
      'addressZipcode = :zipcode, addressCity = :city, addressLogicalName = :name, '
      'addressCoordinates = :coordinates WHERE addressID = :id',
      {..._addressParameters(location), 'id': keys.addressId},
    );
    await tx.execute(
      'UPDATE tblGeofence SET geofenceRadiusInMeter = :radius WHERE geofenceID = :id',
      {'radius': location.radiusMeters, 'id': keys.geofenceId},
    );
  }

  Future<void> setActive(SqlExecutor tx, int addressId, {required bool active}) =>
      tx.execute('UPDATE tblAddress SET addressActive = :active WHERE addressID = :id', {'active': active, 'id': addressId});

  static Map<String, Object?> _addressParameters(LocationRequest location) => {
    'street': location.street,
    'number': location.number,
    'box': location.box,
    'zipcode': location.zipcode,
    'city': location.city,
    'name': location.name,
    'coordinates': formatCoordinates(location.point),
  };

  /// `addressCoordinates`: `"latitude,longitude"` in decimal degrees with a
  /// dot and one comma (CLARIFY-05). Six decimals are about 10 cm.
  static String formatCoordinates(GeoPoint point) =>
      '${point.latitude.toStringAsFixed(6)},${point.longitude.toStringAsFixed(6)}';

  /// `null` when [stored] is missing or not in that format.
  static GeoPoint? parseCoordinates(String? stored) {
    final parts = stored?.split(',');
    if (parts == null || parts.length != 2) return null;
    final latitude = double.tryParse(parts[0]), longitude = double.tryParse(parts[1]);
    if (latitude == null || longitude == null) return null;
    final point = GeoPoint(latitude: latitude, longitude: longitude);
    return point.isValid ? point : null;
  }

  static Location _toLocation(DbRow row) => Location(
    id: row.readInt('addressID'),
    name: row.readString('addressLogicalName'),
    street: row.readString('addressStreet'),
    number: row.readOptionalString('addressNumber'),
    box: row.readOptionalString('addressBoxNumber'),
    zipcode: row.readOptionalString('addressZipcode'),
    city: row.readOptionalString('addressCity'),
    point: parseCoordinates(row.readOptionalString('addressCoordinates')),
    radiusMeters: row.readDouble('geofenceRadiusInMeter').round(),
    isActive: row.readBool('addressActive'),
  );
}
