import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:jitan_ui/jitan_ui.dart';
import 'package:latlong2/latlong.dart';

import 'address_geocoder.dart';

/// Builds the map of the location dialog.
typedef LocationMapBuilder =
    Widget Function(GeoPoint? point, int radiusMeters, ValueChanged<GeoPoint> onPointChanged);

/// The map and address search; `null` in [AdminServices] when the build has
/// no Mapbox token.
class LocationMaps {
  const LocationMaps({required this.map, required this.geocoder});

  factory LocationMaps.mapbox(String token) => LocationMaps(
    map: (point, radius, onChanged) =>
        LocationMap(token: token, point: point, radiusMeters: radius, onPointChanged: onChanged),
    geocoder: AddressGeocoder(token),
  );

  final LocationMapBuilder map;
  final AddressGeocoder geocoder;
}

/// A Mapbox map with the area and its pin. Dragging the pin or clicking the
/// map moves it; a new [point] from outside (the address) moves the map.
class LocationMap extends StatefulWidget {
  const LocationMap({
    super.key,
    required this.token,
    required this.point,
    required this.radiusMeters,
    required this.onPointChanged,
  });

  final String token;
  final GeoPoint? point;
  final int radiusMeters;
  final ValueChanged<GeoPoint> onPointChanged;

  @override
  State<LocationMap> createState() => _LocationMapState();
}

class _LocationMapState extends State<LocationMap> {
  /// Before any pin: the whole of Belgium, where the first companies are.
  static const _startCentre = LatLng(50.6, 4.6);
  static const _startZoom = 7.0;
  static const _pinZoom = 17.0;

  final _map = MapController();
  bool _ready = false;

  /// The pin's last position set here, so only an outside change moves the map.
  LatLng? _own;

  static LatLng? _toLatLng(GeoPoint? point) => point == null ? null : LatLng(point.latitude, point.longitude);

  void _place(LatLng at) {
    _own = at;
    widget.onPointChanged(GeoPoint(latitude: at.latitude, longitude: at.longitude));
  }

  @override
  void didUpdateWidget(LocationMap old) {
    super.didUpdateWidget(old);
    final point = _toLatLng(widget.point);
    if (point != null && point != _own && _ready) {
      _own = point;
      _map.move(point, _pinZoom);
    }
  }

  @override
  Widget build(BuildContext context) {
    final point = _toLatLng(widget.point);
    return FlutterMap(
      mapController: _map,
      options: MapOptions(
        initialCenter: point ?? _startCentre,
        initialZoom: point == null ? _startZoom : _pinZoom,
        backgroundColor: JitanColors.warmWhite,
        // The keyboard stays with the form: the map would take the focus on opening.
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
          keyboardOptions: KeyboardOptions.disabled(),
        ),
        onMapReady: () => _ready = true,
        onTap: (_, at) => _place(at),
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://api.mapbox.com/styles/v1/mapbox/light-v11/tiles/512/{z}/{x}/{y}{r}?access_token={token}',
          additionalOptions: {'token': widget.token},
          tileDimension: 512,
          zoomOffset: -1,
          retinaMode: RetinaMode.isHighDensity(context),
          userAgentPackageName: 'com.axongroup.jitan.admin_web',
        ),
        if (point != null) ...[
          CircleLayer(
            circles: [
              CircleMarker(
                point: point,
                radius: widget.radiusMeters.toDouble(),
                useRadiusInMeter: true,
                color: JitanColors.vermilion.withValues(alpha: 0.1),
                borderColor: JitanColors.vermilion,
                borderStrokeWidth: 1.5,
              ),
            ],
          ),
          MarkerLayer(
            markers: [
              Marker(
                point: point,
                width: 44,
                height: 44,
                child: _Pin(onDragged: _place),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

/// The draggable pin: a vermilion dot with a white ring.
class _Pin extends StatelessWidget {
  const _Pin({required this.onDragged});

  final ValueChanged<LatLng> onDragged;

  @override
  Widget build(BuildContext context) {
    final camera = MapCamera.of(context);
    return MouseRegion(
      cursor: SystemMouseCursors.grab,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanUpdate: (details) {
          final box = context.findRenderObject()! as RenderBox;
          final map = context.findAncestorRenderObjectOfType<RenderBox>();
          final origin = box.localToGlobal(box.size.center(Offset.zero), ancestor: map);
          onDragged(camera.screenOffsetToLatLng(origin + details.delta));
        },
        child: Center(
          child: Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: JitanColors.vermilion,
              shape: BoxShape.circle,
              border: Border.all(color: JitanColors.surface, width: 4),
              boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 6, offset: Offset(0, 2))],
            ),
          ),
        ),
      ),
    );
  }
}
