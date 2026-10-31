import 'package:admin_web/src/locations/address_geocoder.dart';
import 'package:admin_web/src/locations/location_map.dart';
import 'package:flutter/material.dart';
import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:jitan_models/jitan_models.dart';

Location location(int id, String name, {bool active = true, int radius = 50, String street = 'Rue du Progrès'}) => Location(
  id: id,
  name: name,
  street: street,
  number: '12',
  zipcode: '7700',
  city: 'Mouscron',
  point: const GeoPoint(latitude: 50.7, longitude: 3.2),
  radiusMeters: radius,
  isActive: active,
);

/// Stand-in for [LocationsApi]: an in-memory list; [failNext] makes the next
/// write fail.
class FakeLocationsApi implements LocationsApi {
  final locations = <Location>[];
  final calls = <String>[];
  LocationRequest? lastRequest;
  ApiClientException? failNext;
  ApiClientException? failList;

  @override
  Future<List<Location>> list() async {
    calls.add('list');
    if (failList case final failure?) throw failure;
    return [...locations];
  }

  @override
  Future<List<Location>> recognised() async => [...locations.where((l) => l.isActive)];

  Future<Location> _write(String call, Location Function() change) async {
    calls.add(call);
    if (failNext case final failure?) {
      failNext = null;
      throw failure;
    }
    return change();
  }

  Location _toLocation(int id, LocationRequest r, {bool active = true}) => Location(
    id: id,
    name: r.name,
    street: r.street,
    number: r.number,
    box: r.box,
    zipcode: r.zipcode,
    city: r.city,
    point: r.point,
    radiusMeters: r.radiusMeters,
    isActive: active,
  );

  @override
  Future<Location> create(LocationRequest request) => _write('create', () {
    lastRequest = request;
    final created = _toLocation(locations.length + 1, request);
    locations.add(created);
    return created;
  });

  @override
  Future<Location> update(int locationId, LocationRequest request) => _write('update $locationId', () {
    lastRequest = request;
    final i = locations.indexWhere((l) => l.id == locationId);
    return locations[i] = _toLocation(locationId, request, active: locations[i].isActive);
  });

  Location _setActive(int id, bool active) {
    final i = locations.indexWhere((l) => l.id == id);
    final l = locations[i];
    return locations[i] = location(l.id, l.name, active: active, radius: l.radiusMeters, street: l.street);
  }

  @override
  Future<Location> deactivate(int locationId) => _write('deactivate $locationId', () => _setActive(locationId, false));

  @override
  Future<Location> reactivate(int locationId) => _write('reactivate $locationId', () => _setActive(locationId, true));
}

class FakeGeocoder implements AddressGeocoder {
  GeoPoint? result = const GeoPoint(latitude: 50.74, longitude: 3.21);
  final searches = <String>[];

  @override
  Future<GeoPoint?> find(String address) async {
    searches.add(address);
    return result;
  }
}

/// A plain box for the map: tapping it places the pin.
LocationMaps fakeLocationMaps({AddressGeocoder? geocoder}) => LocationMaps(
  map: (point, radius, onChanged) => TextButton(
    key: const ValueKey('fake-map'),
    onPressed: () => onChanged(const GeoPoint(latitude: 50.75, longitude: 3.22)),
    child: const SizedBox.expand(),
  ),
  geocoder: geocoder ?? FakeGeocoder(),
);
