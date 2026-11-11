import 'package:flutter/material.dart';
import 'package:jitan_core/jitan_core.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../l10n/admin_text_keys.dart';
import 'location_mark.dart';

/// The Locations table (Figma `1542:2`): a pin before each name; a row opens
/// the location, with a › while hovered.
class LocationsTable extends StatelessWidget {
  const LocationsTable({super.key, required this.locations, required this.onOpen});

  final List<Location> locations;
  final ValueChanged<Location> onOpen;

  /// Column widths proportional to Figma.
  static const _flexLocation = 380;
  static const _flexAddress = 372;
  static const _flexArea = 110;
  static const _flexStatus = 160;

  /// "Rue du Progrès 12 box 3, 7700 Mouscron".
  static String address(Location l) => [
    [l.street, l.number, l.box].whereType<String>().where((t) => t.isNotEmpty).join(' '),
    [l.zipcode, l.city].whereType<String>().where((t) => t.isNotEmpty).join(' '),
  ].where((t) => t.isNotEmpty).join(', ');

  @override
  Widget build(BuildContext context) {
    final t = TranslationScope.of(context);
    return JitanSliverTable(
      onRowTap: (i) => onOpen(locations[i]),
      hoverChevron: true,
      columns: [
        JitanTableColumn(label: t.t(AdminTextKeys.locationsColumnLocation), flex: _flexLocation),
        JitanTableColumn(label: t.t(AdminTextKeys.locationsColumnAddress), flex: _flexAddress),
        JitanTableColumn(label: t.t(AdminTextKeys.locationsColumnArea), flex: _flexArea),
        JitanTableColumn(label: t.t(AdminTextKeys.locationsColumnStatus), flex: _flexStatus),
      ],
      rowCount: locations.length,
      cells: (i) {
        final location = locations[i];
        final style = location.isActive ? JitanTextStyles.tableCell : JitanTextStyles.tableCell.copyWith(color: JitanColors.inkMuted);
        return [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                LocationMark(active: location.isActive),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    location.name,
                    overflow: TextOverflow.ellipsis,
                    style: location.isActive
                        ? JitanTextStyles.tableCellStrong
                        : JitanTextStyles.tableCellStrong.copyWith(color: JitanColors.inkMuted),
                  ),
                ),
              ],
            ),
          ),
          Text(address(location), style: style),
          Text(t.t(AdminTextKeys.locationAreaValue, args: {'meters': location.radiusMeters}), style: style),
          JitanStatusLabel(
            label: t.t(location.isActive ? CommonTextKeys.statusActive : CommonTextKeys.statusInactive),
            isPositive: location.isActive,
          ),
        ];
      },
    );
  }
}
