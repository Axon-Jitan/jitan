import 'package:flutter/material.dart';
import 'package:jitan_core/jitan_core.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../l10n/admin_text_keys.dart';
import 'terminal_text.dart';

/// What HR chose in a terminal's pop-up; the page does it and says so.
enum TerminalAction { edit, connect, deactivate, reactivate }

/// Opens [terminal]'s pop-up.
Future<TerminalAction?> showManageTerminalDialog(
  BuildContext context, {
  required Terminal terminal,
  required DateTime now,
}) => showJitanModal<TerminalAction>(
  context,
  builder: (_) => _ManageTerminalDialog(terminal: terminal, now: now),
);

/// Figma a terminal (`1545:261`) and an inactive one (`1545:408`): the kind,
/// the serial number and the last scan; one quiet action, Deactivate in red
/// or Reactivate in ink.
class _ManageTerminalDialog extends StatelessWidget {
  const _ManageTerminalDialog({required this.terminal, required this.now});

  final Terminal terminal;
  final DateTime now;

  bool get _isInactive => terminal.status == TerminalStatus.inactive;
  bool get _isConnected => terminal.status == TerminalStatus.online || terminal.status == TerminalStatus.offline;

  String _statusLine(BuildContext context) {
    final status = TerminalText.status(context, terminal.status);
    if (!_isConnected) return status;
    return context.t(
      AdminTextKeys.terminalStatusSeen,
      args: {'status': status, 'seen': TerminalText.lastSeen(context, terminal.lastSeen, now)},
    );
  }

  Widget _row(String label, Widget value) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
    child: Row(
      spacing: 16,
      children: [
        Expanded(
          child: Text(label, overflow: TextOverflow.ellipsis, style: JitanTextStyles.tableCell.copyWith(color: JitanColors.inkMuted)),
        ),
        Flexible(child: value),
      ],
    ),
  );

  Widget _value(String text) => Text(
    text,
    overflow: TextOverflow.ellipsis,
    style: JitanTextStyles.tableCell.copyWith(fontWeight: FontWeight.w500),
  );

  Widget _details(BuildContext context) {
    final rows = [
      _row(context.t(AdminTextKeys.terminalColumnType), _value(terminal.type.name)),
      _row(context.t(AdminTextKeys.terminalSerial), _value(terminal.serialNumber)),
      _row(context.t(AdminTextKeys.terminalLastScan), _value(TerminalText.lastSeen(context, terminal.lastScan, now))),
    ];
    return Container(
      decoration: BoxDecoration(color: JitanColors.tableHeader, borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, row) in rows.indexed) ...[
            if (i > 0) const Divider(height: 1, color: JitanColors.inputBorder),
            row,
          ],
        ],
      ),
    );
  }

  /// Deactivate in red, Reactivate in ink (as on a location).
  Widget _quiet(BuildContext context) {
    final color = _isInactive ? JitanColors.ink : JitanColors.errorStrong;
    return TextButton(
      onPressed: () => Navigator.of(context).pop(_isInactive ? TerminalAction.reactivate : TerminalAction.deactivate),
      style: TextButton.styleFrom(
        foregroundColor: color,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        minimumSize: Size.zero,
      ),
      child: Text(
        context.t(_isInactive ? AdminTextKeys.terminalReactivate : AdminTextKeys.terminalDeactivate),
        style: JitanTextStyles.tableCellStrong.copyWith(color: color),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < JitanDimensions.phoneBreakpoint;
    return JitanModal(
      width: 480,
      title: terminal.name,
      subtitle: _statusLine(context),
      onClose: () => Navigator.of(context).pop(),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 16,
        children: [
          _details(context),
          if (_isInactive)
            Text(
              context.t(AdminTextKeys.terminalInactiveNote),
              style: JitanTextStyles.tableCell.copyWith(color: JitanColors.inkMuted),
            ),
          // On a phone it gets a line of its own, under the details.
          if (narrow) Align(alignment: Alignment.centerLeft, child: _quiet(context)),
        ],
      ),
      leadingActions: narrow ? const [] : [_quiet(context)],
      actions: [
        Wrap(
          alignment: WrapAlignment.end,
          spacing: 10,
          runSpacing: 10,
          children: [
            if (!_isInactive)
              JitanSecondaryButton(
                label: context.t(_isConnected ? AdminTextKeys.terminalReconnect : AdminTextKeys.terminalConnect),
                onPressed: () => Navigator.of(context).pop(TerminalAction.connect),
              ),
            JitanPrimaryButton(
              label: context.t(AdminTextKeys.terminalEdit),
              color: JitanColors.ink,
              onPressed: () => Navigator.of(context).pop(TerminalAction.edit),
            ),
          ],
        ),
      ],
    );
  }
}

/// Figma "Deactivate?" (`1545:556`): one plain question; `true` to go ahead.
Future<bool> confirmTerminalDeactivate(BuildContext context, Terminal terminal) async =>
    await showJitanModal<bool>(
      context,
      builder: (dialog) => JitanModal(
        width: 440,
        title: dialog.t(AdminTextKeys.terminalDeactivateTitle, args: {'terminal': terminal.name}),
        subtitle: dialog.t(AdminTextKeys.terminalDeactivateText),
        actions: [
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 12,
            runSpacing: 10,
            children: [
              JitanSecondaryButton(label: dialog.t(CommonTextKeys.cancel), onPressed: () => Navigator.of(dialog).pop(false)),
              JitanPrimaryButton(
                label: dialog.t(AdminTextKeys.terminalDeactivate),
                color: JitanColors.errorStrong,
                onPressed: () => Navigator.of(dialog).pop(true),
              ),
            ],
          ),
        ],
      ),
    ) ??
    false;
