import 'json_reading.dart';

/// A point on the map, in decimal degrees.
class GeoPoint {
  const GeoPoint({required this.latitude, required this.longitude});

  factory GeoPoint.fromJson(Map<String, Object?> json) =>
      GeoPoint(latitude: json.readDouble('latitude'), longitude: json.readDouble('longitude'));

  final double latitude;
  final double longitude;

  bool get isValid => latitude.abs() <= 90 && longitude.abs() <= 180;

  Map<String, Object?> toJson() => {'latitude': latitude, 'longitude': longitude};
}

/// A place where Jitan recognises employees: a `tblAddress` row with its
/// geofence (`tblGeofenceAddress`, `tblGeofence`).
class Location {
  const Location({
    required this.id,
    required this.name,
    required this.street,
    required this.radiusMeters,
    required this.isActive,
    this.number,
    this.box,
    this.zipcode,
    this.city,
    this.point,
  });

  factory Location.fromJson(Map<String, Object?> json) {
    final point = json['point'];
    return Location(
      id: json.readInt('id'),
      name: json.readString('name'),
      street: json.readString('street'),
      number: json.readOptionalString('number'),
      box: json.readOptionalString('box'),
      zipcode: json.readOptionalString('zipcode'),
      city: json.readOptionalString('city'),
      point: point == null ? null : GeoPoint.fromJson(json.readObject('point')),
      radiusMeters: json.readInt('radiusMeters'),
      isActive: json.readBool('isActive'),
    );
  }

  final int id;
  final String name;
  final String street;
  final String? number;
  final String? box;
  final String? zipcode;
  final String? city;

  /// `null` when the stored coordinates are missing or unreadable: the
  /// location is shown, and Jitan does not recognise it until HR sets the pin.
  final GeoPoint? point;
  final int radiusMeters;
  final bool isActive;

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'street': street,
    'number': number,
    'box': box,
    'zipcode': zipcode,
    'city': city,
    'point': point?.toJson(),
    'radiusMeters': radiusMeters,
    'isActive': isActive,
  };
}

/// Response body of `GET /locations`.
class LocationListResponse {
  const LocationListResponse({required this.locations});

  factory LocationListResponse.fromJson(Map<String, Object?> json) =>
      LocationListResponse(locations: json.readObjectList('locations').map(Location.fromJson).toList());

  final List<Location> locations;

  Map<String, Object?> toJson() => {
    'locations': [for (final location in locations) location.toJson()],
  };
}

/// Body of `POST /locations` and `PUT /locations/{id}`.
class LocationRequest {
  const LocationRequest({
    required this.name,
    required this.street,
    required this.point,
    required this.radiusMeters,
    this.number,
    this.box,
    this.zipcode,
    this.city,
  });

  factory LocationRequest.fromJson(Map<String, Object?> json) => LocationRequest(
    name: json.readString(fieldName),
    street: json.readString(fieldStreet),
    number: json.readOptionalString(fieldNumber),
    box: json.readOptionalString(fieldBox),
    zipcode: json.readOptionalString(fieldZipcode),
    city: json.readOptionalString(fieldCity),
    point: GeoPoint.fromJson(json.readObject(fieldPoint)),
    radiusMeters: json.readInt(fieldRadius),
  );

  final String name;
  final String street;
  final String? number;
  final String? box;
  final String? zipcode;
  final String? city;
  final GeoPoint point;
  final int radiusMeters;

  static const fieldName = 'name';
  static const fieldStreet = 'street';
  static const fieldNumber = 'number';
  static const fieldBox = 'box';
  static const fieldZipcode = 'zipcode';
  static const fieldCity = 'city';
  static const fieldPoint = 'point';
  static const fieldRadius = 'radiusMeters';

  /// Column sizes of `tblAddress`.
  static const maxNameLength = 100;
  static const maxStreetLength = 150;
  static const maxNumberLength = 20;
  static const maxBoxLength = 20;
  static const maxZipcodeLength = 20;
  static const maxCityLength = 100;

  /// The area HR can choose (roadmap §6).
  static const minRadiusMeters = 25;
  static const maxRadiusMeters = 200;

  Map<String, Object?> toJson() => {
    fieldName: name,
    fieldStreet: street,
    fieldNumber: number,
    fieldBox: box,
    fieldZipcode: zipcode,
    fieldCity: city,
    fieldPoint: point.toJson(),
    fieldRadius: radiusMeters,
  };
}
