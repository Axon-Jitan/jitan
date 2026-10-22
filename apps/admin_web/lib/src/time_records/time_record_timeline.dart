import 'package:flutter/material.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../l10n/admin_text_keys.dart';
import 'time_record_text.dart';

/// "View detailed registration timeline" in the day detail (160:94): every
/// registration and correction of the day in time order, including the ones
/// that no longer count (D8: switched off, never deleted).
class TimeRecordTimeline extends StatelessWidget {
  const TimeRecordTimeline({super.key, required this.events});

  final List<TimeRecordEvent> events;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final (i, event) in events.indexed) ...[
        if (i > 0) const Divider(height: 1, color: JitanColors.inputBorder),
        _row(context, event),
      ],
    ],
  );

  Widget _row(BuildContext context, TimeRecordEvent event) {
    final replaced = !event.active &&
        (event.kind == TimeRecordEventKind.registered || event.kind == TimeRecordEventKind.corrected);
    final color = event.active ? JitanColors.ink : JitanColors.inkMuted;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 56,
            child: Text(event.atLocal, style: JitanTextStyles.tableCellStrong.copyWith(color: color)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(TimeRecordText.event(context, event), style: JitanTextStyles.tableCell.copyWith(color: color)),
                if (event.reason case final reason? when reason.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(reason, style: JitanTextStyles.stateMessage.copyWith(fontSize: 12)),
                ],
              ],
            ),
          ),
          if (replaced) ...[
            const SizedBox(width: 12),
            Text(context.t(AdminTextKeys.timeRecordEventReplaced), style: JitanTextStyles.stateMessage.copyWith(fontSize: 12)),
          ],
        ],
      ),
    );
  }
}
