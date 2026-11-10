import 'package:jitan_models/jitan_models.dart';

import '../database/db_row.dart';
import '../database/sql_executor.dart';
import '../locations/location_type_names.dart';

/// A project as stored (D44): a `tblAddress` row linked to the "Project
/// location" kind. [hasArea]: a client site, with its own geofence.
typedef ProjectRow = ({
  int id,
  String fullName,
  String? city,
  String? coordinates,
  bool hasArea,
  bool isActive,
  DateTime? lastUsed,
});

/// Data access for projects on IT's tables (D43, D44): a project is an
/// address of the kind "Project location" (`tblAddressLocationType`). A client
/// site also has a geofence, written by `LocationRepository`; an internal
/// project is an address at a workshop's coordinates, with none. Nothing is
/// deleted: deactivating sets `addressActive = 0`.
class ProjectRepository {
  const ProjectRepository();

  /// The address is linked to the active "Project location" kind.
  static const _isProject =
      'EXISTS (SELECT 1 FROM tblAddressLocationType alt '
      'JOIN tblLocationType lt ON lt.locationTypeID = alt.locationTypeID AND lt.locationTypeName = :projectKind '
      'AND lt.locationTypeActive = 1 AND lt.locationTypeMFD = 0 '
      'WHERE alt.addressID = a.addressID AND alt.addressLocationTypeActive = 1 AND alt.addressLocationTypeMFD = 0)';

  static const _hasArea =
      'EXISTS (SELECT 1 FROM tblGeofenceAddress ga JOIN tblGeofence g ON g.geofenceID = ga.geofenceID '
      'AND g.geofenceActive = 1 AND g.geofenceMFD = 0 '
      'WHERE ga.addressID = a.addressID AND ga.geofenceAddressActive = 1 AND ga.geofenceAddressMFD = 0)';

  /// Every project, or only the active ones; "last used" by anyone, or by
  /// [userId] when given. Newest use first, then by name.
  Future<List<ProjectRow>> list(SqlExecutor executor, {bool activeOnly = false, int? userId}) async {
    final usedBy = userId == null ? '' : 'AND r.userID = :user ';
    final rows = await executor.query(
      'SELECT a.addressID, a.addressLogicalName, a.addressCity, a.addressCoordinates, a.addressActive, '
      '$_hasArea AS hasArea, '
      '(SELECT MAX(r.timeRegTimestamp) FROM tblTimeReg r WHERE r.addressID = a.addressID $usedBy'
      'AND r.timeRegActive = 1 AND r.timeRegMFD = 0) AS lastUsed '
      'FROM tblAddress a WHERE a.addressMFD = 0 AND $_isProject '
      '${activeOnly ? 'AND a.addressActive = 1 ' : ''}'
      'ORDER BY lastUsed IS NULL, lastUsed DESC, a.addressLogicalName, a.addressID',
      {'projectKind': LocationTypeNames.projectLocation, 'user': ?userId},
    );
    return rows.map(_toRow).toList();
  }

  /// One project; `null` when it doesn't exist or isn't a project.
  Future<ProjectRow?> find(SqlExecutor executor, int addressId) async {
    final rows = await executor.query(
      'SELECT a.addressID, a.addressLogicalName, a.addressCity, a.addressCoordinates, a.addressActive, '
      '$_hasArea AS hasArea, NULL AS lastUsed '
      'FROM tblAddress a WHERE a.addressMFD = 0 AND a.addressID = :id AND $_isProject',
      {'id': addressId, 'projectKind': LocationTypeNames.projectLocation},
    );
    return rows.isEmpty ? null : _toRow(rows.first);
  }

  /// Locks the project's address for the rest of the transaction.
  Future<bool> lock(SqlExecutor tx, int addressId) async => (await tx.query(
    'SELECT a.addressID FROM tblAddress a WHERE a.addressID = :id AND a.addressMFD = 0 AND $_isProject FOR UPDATE',
    {'id': addressId, 'projectKind': LocationTypeNames.projectLocation},
  )).isNotEmpty;

  /// The "Project location" kind HR added on the Lists page; `null` while it
  /// is missing.
  Future<int?> projectKindId(SqlExecutor executor) async {
    final rows = await executor.query(
      'SELECT locationTypeID FROM tblLocationType WHERE locationTypeName = :name '
      'AND locationTypeActive = 1 AND locationTypeMFD = 0 ORDER BY locationTypeID LIMIT 1',
      {'name': LocationTypeNames.projectLocation},
    );
    return rows.isEmpty ? null : rows.first.readInt('locationTypeID');
  }

  /// Marks [addressId] as a project; returns the link's id.
  Future<int> link(SqlExecutor tx, int addressId, int kindId) async => (await tx.execute(
    'INSERT INTO tblAddressLocationType (addressID, locationTypeID, addressLocationTypeActive, addressLocationTypeMFD) '
    'VALUES (:address, :kind, 1, 0)',
    {'address': addressId, 'kind': kindId},
  )).lastInsertId;

  /// An internal project: an address at [workshop], named [fullName].
  Future<int> insertInternal(SqlExecutor tx, String fullName, Location workshop) async => (await tx.execute(
    'INSERT INTO tblAddress (addressStreet, addressNumber, addressBoxNumber, addressZipcode, addressCity, '
    'addressLogicalName, addressCoordinates, addressActive, addressMFD) '
    'VALUES (:street, :number, :box, :zipcode, :city, :name, :coordinates, 1, 0)',
    _internalParameters(fullName, workshop),
  )).lastInsertId;

  Future<void> updateInternal(SqlExecutor tx, int addressId, String fullName, Location workshop) => tx.execute(
    'UPDATE tblAddress SET addressStreet = :street, addressNumber = :number, addressBoxNumber = :box, '
    'addressZipcode = :zipcode, addressCity = :city, addressLogicalName = :name, addressCoordinates = :coordinates '
    'WHERE addressID = :id',
    {..._internalParameters(fullName, workshop), 'id': addressId},
  );

  Future<void> setActive(SqlExecutor tx, int addressId, {required bool active}) => tx.execute(
    'UPDATE tblAddress SET addressActive = :active WHERE addressID = :id',
    {'id': addressId, 'active': active ? 1 : 0},
  );

  static Map<String, Object?> _internalParameters(String fullName, Location workshop) => {
    'street': workshop.street,
    'number': workshop.number,
    'box': workshop.box,
    'zipcode': workshop.zipcode,
    'city': workshop.city,
    'name': fullName,
    'coordinates': coordinatesOf(workshop.point),
  };

  /// `tblAddress.addressCoordinates` as Jitan writes it (`LocationRepository`).
  static String? coordinatesOf(GeoPoint? point) =>
      point == null ? null : '${point.latitude.toStringAsFixed(6)},${point.longitude.toStringAsFixed(6)}';

  static ProjectRow _toRow(DbRow row) => (
    id: row.readInt('addressID'),
    fullName: row.readString('addressLogicalName'),
    city: row.readOptionalString('addressCity'),
    coordinates: row.readOptionalString('addressCoordinates'),
    hasArea: row.readBool('hasArea'),
    isActive: row.readBool('addressActive'),
    lastUsed: row.readOptionalString('lastUsed') == null ? null : row.readUtcDateTime('lastUsed'),
  );
}
