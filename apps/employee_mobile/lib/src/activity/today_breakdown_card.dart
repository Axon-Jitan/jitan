import 'package:flutter/material.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../l10n/employee_text_keys.dart';
import '../today/today_text.dart';
import '../today/today_widgets.dart';

/// "Today's breakdown" (Figma `1092:30`): how the day has gone so far, shown
/// once there is more than one kind of work, with only the parts that have
/// time in them. Transport says its kilometres (D23); while a trip's distance
/// isn't known they would be too low, so it says its time.
class TodayBreakdownCard extends StatelessWidget {
  const TodayBreakdownCard({super.key, required this.breakdown});

  final ActivityBreakdown breakdown;

  String _transport(BuildContext context, int minutes) => breakdown.tripsWithoutDistance == 0
      ? context.t(EmployeeTextKeys.activityKilometres, args: {'km': (breakdown.distanceMetres / 1000).round()})
      : TodayText.duration(context, minutes);

  @override
  Widget build(BuildContext context) {
    final parts = [
      (EmployeeTextKeys.activityClientWork, breakdown.clientMinutes, JitanColors.ink),
      (EmployeeTextKeys.activityInternal, breakdown.internalMinutes, JitanColors.inkMuted),
      (EmployeeTextKeys.activityOtherWork, breakdown.otherMinutes, JitanColors.inkMuted),
      (EmployeeTextKeys.activityTransport, breakdown.transportMinutes, JitanColors.chartAmber),
    ].where((part) => part.$2 > 0).toList();
    return TodayCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(context.t(EmployeeTextKeys.activityBreakdown), style: JitanMobileTextStyles.cardTitle),
          const SizedBox(height: 14),
          Row(
            spacing: 3,
            children: [
              for (final (_, minutes, color) in parts)
                Expanded(
                  flex: minutes,
                  child: Container(
                    height: 10,
                    decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(5)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          for (final (key, minutes, color) in parts)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(context.t(key), style: JitanMobileTextStyles.cardText)),
                  Text(
                    key == EmployeeTextKeys.activityTransport
                        ? '${context.tPlural(EmployeeTextKeys.activityTrips, breakdown.trips)} · ${_transport(context, minutes)}'
                        : TodayText.duration(context, minutes),
                    style: JitanMobileTextStyles.cardText.copyWith(color: JitanColors.ink),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
