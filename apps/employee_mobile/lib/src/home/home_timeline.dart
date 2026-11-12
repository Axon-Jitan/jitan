import 'package:flutter/material.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../widgets/phone_widgets.dart';

/// One moment of the day: "08:00 · Started · In the app".
class HomeMoment {
  const HomeMoment({required this.time, required this.title, this.detail, this.waiting = false});

  /// Workplace-local `HH:mm`.
  final String time;
  final String title;

  /// How or where ("In the app", "36 km", "Cooling towers").
  final String? detail;

  /// The detail waits for HR: shown in amber.
  final bool waiting;
}

/// What the day went on so far, oldest first (Figma `1585:2`): the times in
/// one column, so every row lines up.
class HomeTimeline extends StatelessWidget {
  const HomeTimeline({super.key, required this.moments});

  final List<HomeMoment> moments;

  @override
  Widget build(BuildContext context) => PhoneListCard(
    children: [
      for (final moment in moments)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Row(
            children: [
              SizedBox(width: 42, child: Text(moment.time, style: JitanMobileTextStyles.rowTime)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  moment.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: JitanMobileTextStyles.rowTitle.copyWith(fontSize: 14),
                ),
              ),
              if (moment.detail case final detail?) ...[
                const SizedBox(width: 12),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 150),
                  child: Text(
                    detail,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                    style: moment.waiting
                        ? JitanMobileTextStyles.detail.copyWith(color: JitanColors.warning, fontWeight: FontWeight.w500)
                        : JitanMobileTextStyles.detail,
                  ),
                ),
              ],
            ],
          ),
        ),
    ],
  );
}
