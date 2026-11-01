import 'package:flutter/material.dart';
import 'package:jitan_core/jitan_core.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../l10n/admin_text_keys.dart';

/// The words of the Terminals page.
abstract final class TerminalText {
  static String status(BuildContext context, TerminalStatus status) => context.t(switch (status) {
    TerminalStatus.online => AdminTextKeys.terminalOnline,
    TerminalStatus.offline => AdminTextKeys.terminalOffline,
    TerminalStatus.notConnected => AdminTextKeys.terminalNotConnected,
    TerminalStatus.inactive => AdminTextKeys.terminalInactive,
  });

  /// "Now", "2 min ago", "Yesterday, 16:42", "28 Oct, 09:12", "—".
  static String lastSeen(BuildContext context, DateTime? seen, DateTime now) {
    if (seen == null) return '—';
    final local = seen.toLocal();
    final minutes = now.difference(local).inMinutes;
    if (minutes < 1) return context.t(AdminTextKeys.terminalSeenNow);
    if (minutes < 60) return context.t(AdminTextKeys.terminalSeenMinutes, args: {'minutes': minutes});
    final time = '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
    final days = DateUtils.dateOnly(now).difference(DateUtils.dateOnly(local)).inDays;
    if (days == 0) return time;
    if (days == 1) return context.t(AdminTextKeys.terminalSeenYesterday, args: {'time': time});
    return '${local.day} ${context.t(CommonTextKeys.monthLong[local.month - 1])}, $time';
  }
}

/// The status with its dot (Figma `1488:2`): the words stay ink while all is
/// well.
class TerminalStatusLabel extends StatelessWidget {
  const TerminalStatusLabel({super.key, required this.status});

  final TerminalStatus status;

  @override
  Widget build(BuildContext context) {
    final (dot, text) = switch (status) {
      TerminalStatus.online => (JitanColors.success, JitanColors.ink),
      TerminalStatus.offline => (JitanColors.warning, JitanColors.warning),
      TerminalStatus.notConnected || TerminalStatus.inactive => (JitanColors.inkMuted, JitanColors.inkMuted),
    };
    return Row(
      spacing: 8,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
        ),
        Flexible(
          child: Text(
            TerminalText.status(context, status),
            overflow: TextOverflow.ellipsis,
            style: JitanTextStyles.tableCell.copyWith(color: text),
          ),
        ),
      ],
    );
  }
}
