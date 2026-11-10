import 'package:flutter/material.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../l10n/employee_text_keys.dart';
import '../today/today_text.dart';
import '../today/today_widgets.dart';

/// "Today's breakdown" (Figma `1092:30`, D46 `1508:2`): how the worked time
/// has gone so far, shown once there is more than one kind of work, with only
/// the parts that have time in them. Travel is never part of the worked time,
/// so it sits under a line: its time, with the trips and their kilometres
/// (D23) once every trip's distance is known.
class TodayBreakdownCard extends StatelessWidget {
  const TodayBreakdownCard({super.key, required this.breakdown});

  final ActivityBreakdown breakdown;

  String _trips(BuildContext context) {
    final trips = context.tPlural(EmployeeTextKeys.activityTrips, breakdown.trips);
    if (breakdown.tripsWithoutDistance > 0 || breakdown.distanceMetres == 0) return trips;
    return '$trips · ${context.t(EmployeeTextKeys.activityKilometres, args: {'km': (breakdown.distanceMetres / 1000).round()})}';
  }

  @override
  Widget build(BuildContext context) {
    final parts = [
      (EmployeeTextKeys.activityClientWork, breakdown.clientMinutes, JitanColors.ink),
      (EmployeeTextKeys.activityInternal, breakdown.internalMinutes, JitanColors.inkMuted),
      (EmployeeTextKeys.activityOtherWork, breakdown.otherMinutes, JitanColors.chartAmber),
    ].where((part) => part.$2 > 0).toList();
    final value = JitanMobileTextStyles.cardText.copyWith(color: JitanColors.ink, fontWeight: FontWeight.w600);
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
                  Text(TodayText.duration(context, minutes), style: value),
                ],
              ),
            ),
          if (breakdown.transportMinutes > 0) ...[
            const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Divider(height: 1, color: JitanColors.inputBorder)),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  const Icon(Icons.north_east_rounded, size: 14, color: JitanColors.inkMuted),
                  const SizedBox(width: 6),
                  Text(context.t(EmployeeTextKeys.activityTravel), style: JitanMobileTextStyles.cardText),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _trips(context),
                      overflow: TextOverflow.ellipsis,
                      style: JitanMobileTextStyles.cardText.copyWith(color: JitanColors.inkMuted),
                    ),
                  ),
                  Text(TodayText.duration(context, breakdown.transportMinutes), style: value),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
