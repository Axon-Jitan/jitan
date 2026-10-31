import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:jitan_models/jitan_models.dart';

import '../l10n/admin_text_keys.dart';
import 'address_geocoder.dart';

/// The fields of the location dialog. Checks only what the form needs for
/// quick feedback; the server validates everything.
class LocationFormController extends ChangeNotifier {
  LocationFormController({required this._api, required this.location, this._geocoder}) {
    name.text = location?.name ?? '';
    street.text = location?.street ?? '';
    number.text = location?.number ?? '';
    box.text = location?.box ?? '';
    zipcode.text = location?.zipcode ?? '';
    city.text = location?.city ?? '';
    _point = location?.point;
    _radius = location?.radiusMeters ?? defaultRadiusMeters;
    _pinPlaced = _point != null;
    for (final field in [street, number, zipcode, city]) {
      field.addListener(_addressChanged);
    }
    name.addListener(notifyListeners);
  }

  /// A new location's area: the low end of the recommended 50–100 m.
  static const defaultRadiusMeters = 50;
  static const radiusStepMeters = 5;
  static const _searchDelay = Duration(milliseconds: 700);

  final LocationsApi _api;
  final AddressGeocoder? _geocoder;

  /// `null` when adding.
  final Location? location;

  final name = TextEditingController();
  final street = TextEditingController();
  final number = TextEditingController();
  final box = TextEditingController();
  final zipcode = TextEditingController();
  final city = TextEditingController();

  GeoPoint? _point;
  GeoPoint? get point => _point;

  late int _radius;
  int get radiusMeters => _radius;

  /// HR set the pin (or it was stored), so the address no longer moves it.
  late bool _pinPlaced;
  Timer? _search;
  String _lastAddress = '';

  bool _busy = false;
  bool get busy => _busy;

  /// Text keys of errors per field.
  String? nameError;
  String? streetError;
  ApiClientException? failure;

  bool get canSave =>
      !_busy && name.text.trim().isNotEmpty && street.text.trim().isNotEmpty && _point != null;

  void placePin(GeoPoint point) {
    _pinPlaced = true;
    _search?.cancel();
    _point = point;
    notifyListeners();
  }

  void setRadius(int meters) {
    _radius = meters;
    notifyListeners();
  }

  void _addressChanged() {
    notifyListeners();
    final geocoder = _geocoder;
    if (geocoder == null || _pinPlaced) return;
    final address = [
      [street.text.trim(), number.text.trim()].where((t) => t.isNotEmpty).join(' '),
      [zipcode.text.trim(), city.text.trim()].where((t) => t.isNotEmpty).join(' '),
    ].where((t) => t.isNotEmpty).join(', ');
    if (address == _lastAddress || street.text.trim().isEmpty) return;
    _search?.cancel();
    _search = Timer(_searchDelay, () async {
      _lastAddress = address;
      final found = await geocoder.find(address);
      if (found != null && !_pinPlaced && !_disposed) {
        _point = found;
        notifyListeners();
      }
    });
  }

  /// The saved location, or `null` with [nameError] or [failure] set.
  Future<Location?> save() async {
    final point = _point;
    if (point == null) return null;
    _busy = true;
    nameError = streetError = null;
    failure = null;
    notifyListeners();
    final request = LocationRequest(
      name: name.text,
      street: street.text,
      number: number.text,
      box: box.text,
      zipcode: zipcode.text,
      city: city.text,
      point: point,
      radiusMeters: _radius,
    );
    try {
      final current = location;
      return current == null ? await _api.create(request) : await _api.update(current.id, request);
    } on ApiClientException catch (e) {
      switch (e.error) {
        case ApiError(code: ApiErrorCode.duplicateLocationName):
          nameError = AdminTextKeys.locationErrorNameDuplicate;
        case ApiError(code: ApiErrorCode.validationFailed, field: LocationRequest.fieldName):
          nameError = AdminTextKeys.locationErrorName;
        case ApiError(code: ApiErrorCode.validationFailed, field: LocationRequest.fieldStreet):
          streetError = AdminTextKeys.locationErrorStreet;
        default:
          failure = e;
      }
      return null;
    } finally {
      _busy = false;
      if (!_disposed) notifyListeners();
    }
  }

  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    _search?.cancel();
    for (final field in [name, street, number, box, zipcode, city]) {
      field.dispose();
    }
    super.dispose();
  }
}
