import 'package:flutter/material.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../l10n/admin_text_keys.dart';
import 'terminal_text.dart';

/// The Terminals table (Figma `1545:111`): a row opens the terminal, with a ›
/// while hovered. Terminals are
/// shared by every company, so there is no company column. A phone keeps the
/// name and the status.
class TerminalsTable extends StatelessWidget {
  const TerminalsTable({super.key, required this.terminals, required this.now, required this.onOpen});

  final List<Terminal> terminals;
  final DateTime now;
  final ValueChanged<Terminal> onOpen;

  // Column widths proportional to Figma.
  static const _flexTerminal = 480;
  static const _flexType = 150;
  static const _flexStatus = 190;
  static const _flexSeen = 226;
  static const _flexPhoneTerminal = 190;
  static const _flexPhoneStatus = 130;

  @override
  Widget build(BuildContext context) {
    final t = TranslationScope.of(context);
    final phone = MediaQuery.sizeOf(context).width < JitanDimensions.phoneBreakpoint;
    return JitanSliverTable(
      minWidth: phone ? 0 : 760,
      onRowTap: (i) => onOpen(terminals[i]),
      hoverChevron: true,
      columns: [
        JitanTableColumn(label: t.t(AdminTextKeys.terminalColumnTerminal), flex: phone ? _flexPhoneTerminal : _flexTerminal),
        if (!phone) ...[
          JitanTableColumn(label: t.t(AdminTextKeys.terminalColumnType), flex: _flexType),
        ],
        JitanTableColumn(label: t.t(AdminTextKeys.terminalColumnStatus), flex: phone ? _flexPhoneStatus : _flexStatus),
        if (!phone) JitanTableColumn(label: t.t(AdminTextKeys.terminalColumnSeen), flex: _flexSeen),
      ],
      rowCount: terminals.length,
      cells: (i) {
        final terminal = terminals[i];
        final muted = terminal.status == TerminalStatus.inactive ? JitanColors.inkMuted : null;
        return [
          Text(terminal.name, overflow: TextOverflow.ellipsis, style: JitanTextStyles.tableCellStrong.copyWith(color: muted)),
          if (!phone) ...[
            Text(terminal.type.name, overflow: TextOverflow.ellipsis, style: JitanTextStyles.tableCell.copyWith(color: muted)),
          ],
          TerminalStatusLabel(status: terminal.status),
          if (!phone)
            Text(
              TerminalText.lastSeen(context, terminal.lastSeen, now),
              overflow: TextOverflow.ellipsis,
              style: JitanTextStyles.tableCell.copyWith(color: JitanColors.inkMuted),
            ),
        ];
      },
    );
  }
}
