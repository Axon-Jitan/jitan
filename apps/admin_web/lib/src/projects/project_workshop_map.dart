import 'package:flutter/material.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../l10n/admin_text_keys.dart';
import '../locations/location_map.dart';
import '../locations/location_map_panel.dart';

/// The right half of a project for our workshop (Figma `HR / Projects V2 —
/// add project, our workshop` `1562:350`): the chosen workshop's pin and
/// area, read-only, so the pop-up keeps its size when HR switches kind. The
/// workshop is changed on the Locations page, not here.
class ProjectWorkshopMap extends StatelessWidget {
  const ProjectWorkshopMap({super.key, required this.workshop, required this.maps});

  /// `null` until HR chooses one.
  final Location? workshop;
  final LocationMaps? maps;

  static const _attribution = '© Mapbox © OpenStreetMap';

  @override
  Widget build(BuildContext context) {
    final maps = this.maps;
    final workshop = this.workshop;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (maps == null)
          ColoredBox(
            color: JitanColors.warmWhite,
            child: Center(child: Text(context.t(AdminTextKeys.locationMapNotSetUp), style: JitanTextStyles.stateMessage)),
          )
        else
          // Looking only: a tap does not move the workshop's pin.
          IgnorePointer(child: maps.map(workshop?.point, workshop?.radiusMeters ?? 100, (_) {})),
        Positioned(
          top: 20,
          left: 20,
          child: LocationMapHint(
            workshop == null
                ? context.t(AdminTextKeys.projectWorkshopMapChoose)
                : context.t(AdminTextKeys.projectWorkshopMapArea, args: {'workshop': workshop.name}),
          ),
        ),
        if (maps != null)
          const Positioned(left: 22, bottom: 8, child: Text(_attribution, style: TextStyle(fontSize: 9, color: JitanColors.inkMuted))),
      ],
    );
  }
}
