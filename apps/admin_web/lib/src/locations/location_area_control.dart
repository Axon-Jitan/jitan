import 'package:flutter/material.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../l10n/admin_text_keys.dart';
import 'location_form_controller.dart';

/// The floating card on the map: the area and its slider (Figma `Area
/// control` in 1465:301). [onChanged] `null` disables it.
class LocationAreaControl extends StatelessWidget {
  const LocationAreaControl({super.key, required this.meters, required this.onChanged});

  final int meters;
  final ValueChanged<int>? onChanged;

  static const _range = LocationRequest.maxRadiusMeters - LocationRequest.minRadiusMeters;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(20, 14, 12, 14),
    decoration: BoxDecoration(
      color: JitanColors.surface.withValues(alpha: 0.96),
      borderRadius: BorderRadius.circular(18),
      boxShadow: const [BoxShadow(color: Color(0x14182021), blurRadius: 24, offset: Offset(0, 8))],
    ),
    child: Row(
      children: [
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(context.t(AdminTextKeys.locationArea), style: JitanTextStyles.stateMessage.copyWith(fontSize: 12)),
            Text(
              context.t(AdminTextKeys.locationAreaValue, args: {'meters': meters}),
              style: JitanTextStyles.modalTitle.copyWith(fontSize: 22),
            ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SliderTheme(
                data: SliderThemeData(
                  trackHeight: 4,
                  activeTrackColor: JitanColors.ink,
                  inactiveTrackColor: JitanColors.inputBorder,
                  thumbColor: JitanColors.surface,
                  overlayShape: SliderComponentShape.noOverlay,
                  tickMarkShape: SliderTickMarkShape.noTickMark,
                  showValueIndicator: ShowValueIndicator.never,
                ),
                child: Slider(
                  value: meters.toDouble(),
                  min: LocationRequest.minRadiusMeters.toDouble(),
                  max: LocationRequest.maxRadiusMeters.toDouble(),
                  divisions: _range ~/ LocationFormController.radiusStepMeters,
                  semanticFormatterCallback: (v) => context.t(AdminTextKeys.locationAreaValue, args: {'meters': v.round()}),
                  onChanged: onChanged == null ? null : (v) => onChanged!(v.round()),
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Text(
                  context.t(AdminTextKeys.locationAreaHint),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: JitanTextStyles.stateMessage.copyWith(fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
