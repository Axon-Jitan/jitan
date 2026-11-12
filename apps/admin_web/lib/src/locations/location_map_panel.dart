import 'package:flutter/material.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../l10n/admin_text_keys.dart';
import 'location_area_control.dart';
import 'location_form_controller.dart';
import 'location_map.dart';

/// The map side of Add location (Figma `1465:301`) and of Add project for a
/// client site (`1512:114`): the pin, its area, a hint and the close button.
class LocationMapPanel extends StatelessWidget {
  const LocationMapPanel({super.key, required this.form, required this.maps, required this.busy, this.showClose = true});

  final LocationFormController form;
  final LocationMaps? maps;
  final bool busy;

  /// The ✕ in the corner; off where the form has Cancel (Figma `1542:153`).
  final bool showClose;

  /// Required by Mapbox, in every language.
  static const _attribution = '© Mapbox © OpenStreetMap';

  @override
  Widget build(BuildContext context) {
    final maps = this.maps;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (maps == null)
          ColoredBox(
            color: JitanColors.warmWhite,
            child: Center(
              child: Text(context.t(AdminTextKeys.locationMapNotSetUp), style: JitanTextStyles.stateMessage),
            ),
          )
        else
          maps.map(form.point, form.radiusMeters, form.placePin),
        Positioned(
          top: 20,
          left: 20,
          child: LocationMapHint(context.t(form.point == null ? AdminTextKeys.locationMapPlace : AdminTextKeys.locationMapDrag)),
        ),
        if (showClose)
          Positioned(
            top: 20,
            right: 20,
            child: Material(
              color: JitanColors.surface,
              shape: const CircleBorder(),
              child: IconButton(
                tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                iconSize: 16,
                constraints: const BoxConstraints.tightFor(width: 36, height: 36),
                padding: EdgeInsets.zero,
                onPressed: busy ? null : () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close, color: JitanColors.ink),
              ),
            ),
          ),
        Positioned(
          left: 20,
          right: 20,
          bottom: 28,
          child: LocationAreaControl(meters: form.radiusMeters, onChanged: busy ? null : form.setRadius),
        ),
        const Positioned(left: 22, bottom: 8, child: Text(_attribution, style: TextStyle(fontSize: 9, color: JitanColors.inkMuted))),
      ],
    );
  }
}

/// A small white chip over the map ("Drag the pin to the entrance").
class LocationMapHint extends StatelessWidget {
  const LocationMapHint(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
    decoration: BoxDecoration(color: JitanColors.surface.withValues(alpha: 0.94), borderRadius: BorderRadius.circular(999)),
    child: Text(text, style: JitanTextStyles.tableCellStrong.copyWith(fontSize: 12)),
  );
}
