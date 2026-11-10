import 'package:flutter/material.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../l10n/admin_text_keys.dart';
import 'terminal_text.dart';

/// The Terminals table (Figma `1507:2`): a row opens Manage. Terminals are
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
  static const _flexOpen = 30;
  static const _flexPhoneTerminal = 190;
  static const _flexPhoneStatus = 130;
  static const _flexPhoneOpen = 30;

  @override
  Widget build(BuildContext context) {
    final t = TranslationScope.of(context);
    final phone = MediaQuery.sizeOf(context).width < JitanDimensions.phoneBreakpoint;
    return JitanSliverTable(
      minWidth: phone ? 0 : 760,
      onRowTap: (i) => onOpen(terminals[i]),
      columns: [
        JitanTableColumn(label: t.t(AdminTextKeys.terminalColumnTerminal), flex: phone ? _flexPhoneTerminal : _flexTerminal),
        if (!phone) ...[
          JitanTableColumn(label: t.t(AdminTextKeys.terminalColumnType), flex: _flexType),
        ],
        JitanTableColumn(label: t.t(AdminTextKeys.terminalColumnStatus), flex: phone ? _flexPhoneStatus : _flexStatus),
        if (!phone) JitanTableColumn(label: t.t(AdminTextKeys.terminalColumnSeen), flex: _flexSeen),
        JitanTableColumn(label: '', flex: phone ? _flexPhoneOpen : _flexOpen, align: JitanColumnAlign.end),
      ],
      rowCount: terminals.length,
      cells: (i) {
        final terminal = terminals[i];
        return [
          Text(terminal.name, overflow: TextOverflow.ellipsis, style: JitanTextStyles.tableCellStrong),
          if (!phone) ...[
            Text(terminal.type.name, overflow: TextOverflow.ellipsis, style: JitanTextStyles.tableCell),
          ],
          TerminalStatusLabel(status: terminal.status),
          if (!phone)
            Text(
              TerminalText.lastSeen(context, terminal.lastSeen, now),
              overflow: TextOverflow.ellipsis,
              style: JitanTextStyles.tableCell.copyWith(color: JitanColors.inkMuted),
            ),
          const Icon(Icons.chevron_right, size: 18, color: JitanColors.inkMuted),
        ];
      },
      footer: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          context.tPlural(AdminTextKeys.terminalCount, terminals.length),
          style: JitanTextStyles.stateMessage.copyWith(fontSize: 12),
        ),
      ),
    );
  }
}
