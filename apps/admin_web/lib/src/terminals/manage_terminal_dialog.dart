import 'package:flutter/material.dart';
import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:jitan_core/jitan_core.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../common/api_failure_text.dart';
import '../l10n/admin_text_keys.dart';
import 'terminal_text.dart';

enum TerminalAction { edit, connect, deactivate, remove }

/// Opens Manage for [terminal]. Scanning and turning it back on are saved
/// here; the rest comes back as a [TerminalAction].
Future<TerminalAction?> showManageTerminalDialog(
  BuildContext context, {
  required TerminalsApi api,
  required Terminal terminal,
  required DateTime now,
}) => showJitanModal<TerminalAction>(
  context,
  builder: (_) => _ManageTerminalDialog(api: api, terminal: terminal, now: now),
);

/// Figma `HR / Terminals V2 — Manage` (`1488:1164`): one calm window instead
/// of Terminal details and Manage terminal.
class _ManageTerminalDialog extends StatefulWidget {
  const _ManageTerminalDialog({required this.api, required this.terminal, required this.now});

  final TerminalsApi api;
  final Terminal terminal;
  final DateTime now;

  @override
  State<_ManageTerminalDialog> createState() => _ManageTerminalDialogState();
}

class _ManageTerminalDialogState extends State<_ManageTerminalDialog> {
  late Terminal _terminal = widget.terminal;
  ApiClientException? _failure;
  bool _busy = false;

  bool get _isVehicle => _terminal.plateNumber != null;
  bool get _isInactive => _terminal.status == TerminalStatus.inactive;
  bool get _isConnected => _terminal.status == TerminalStatus.online || _terminal.status == TerminalStatus.offline;

  Future<void> _save(Future<Terminal> Function() change) async {
    setState(() {
      _busy = true;
      _failure = null;
    });
    try {
      final saved = await change();
      if (mounted) setState(() => _terminal = saved);
    } on ApiClientException catch (e) {
      if (mounted) setState(() => _failure = e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String get _statusLine {
    final status = TerminalText.status(context, _terminal.status);
    if (!_isConnected) return status;
    return context.t(
      AdminTextKeys.terminalStatusSeen,
      args: {'status': status, 'seen': TerminalText.lastSeen(context, _terminal.lastSeen, widget.now)},
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

  Widget _details() {
    final rows = [
      _row(context.t(AdminTextKeys.terminalColumnType), _value(_terminal.type.name)),
      _row(context.t(AdminTextKeys.terminalColumnCompany), _value(_terminal.companyName)),
      if (_isVehicle)
        _row(context.t(AdminTextKeys.terminalPlate), _value(_terminal.plateNumber!))
      else
        _row(context.t(AdminTextKeys.terminalLocation), _value(_terminal.addressName ?? '—')),
      if (_terminal.deviceName case final device?) _row(context.t(AdminTextKeys.terminalTablet), _value(device)),
      _row(
        context.t(AdminTextKeys.terminalCanScan),
        SizedBox(
          height: 24,
          child: Transform.scale(
            scale: 0.7,
            alignment: Alignment.centerRight,
            child: Switch(
              value: _terminal.scanningEnabled,
              activeThumbColor: JitanColors.surface,
              activeTrackColor: JitanColors.ink,
              inactiveTrackColor: JitanColors.inputBorder,
              inactiveThumbColor: JitanColors.surface,
              trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
              onChanged: _busy || _isInactive
                  ? null
                  : (enabled) => _save(() => widget.api.setScanning(_terminal, enabled: enabled)),
            ),
          ),
        ),
      ),
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

  Widget _quiet(String label, VoidCallback? onPressed) => TextButton(
    onPressed: onPressed,
    style: TextButton.styleFrom(
      foregroundColor: JitanColors.inkMuted,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      minimumSize: Size.zero,
      textStyle: JitanTextStyles.tableCell.copyWith(fontWeight: FontWeight.w500),
    ),
    child: Text(label),
  );

  void _done(TerminalAction action) => Navigator.of(context).pop(action);

  @override
  Widget build(BuildContext context) {
    final failure = _failure;
    final keys = failure == null ? null : failureTextKeysFor(failure);
    final narrow = MediaQuery.sizeOf(context).width < JitanDimensions.phoneBreakpoint;
    final quiet = [
      if (_isInactive)
        _quiet(context.t(AdminTextKeys.terminalReactivate), _busy ? null : () => _save(() => widget.api.reactivate(_terminal)))
      else
        _quiet(context.t(AdminTextKeys.terminalDeactivate), () => _done(TerminalAction.deactivate)),
      _quiet(context.t(AdminTextKeys.terminalRemove), () => _done(TerminalAction.remove)),
    ];
    return JitanModal(
      width: 480,
      title: _terminal.name,
      subtitle: _statusLine,
      onClose: () => Navigator.of(context).pop(),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 16,
        children: [
          _details(),
          if (keys != null) JitanInlineError(title: context.t(keys.title), message: context.t(keys.message)),
          // On a phone they get a line of their own, under the details.
          if (narrow) Row(spacing: 10, children: quiet),
        ],
      ),
      leadingActions: narrow ? const [] : quiet,
      actions: [
        if (!_isInactive)
          JitanSecondaryButton(
            label: context.t(_isConnected ? AdminTextKeys.terminalReconnect : AdminTextKeys.terminalConnect),
            onPressed: () => _done(TerminalAction.connect),
          ),
        JitanPrimaryButton(
          label: context.t(AdminTextKeys.terminalEdit),
          color: JitanColors.ink,
          onPressed: () => _done(TerminalAction.edit),
        ),
      ],
    );
  }
}

/// Figma `1494:1339` and `1494:1493`: asks once; returns `true` to go ahead.
Future<bool> confirmTerminalAction(
  BuildContext context, {
  required String title,
  required String text,
  required String action,
  bool destructive = false,
}) async =>
    await showJitanModal<bool>(
      context,
      builder: (dialog) => JitanModal(
        width: 480,
        title: title,
        subtitle: text,
        body: const SizedBox.shrink(),
        actions: [
          JitanSecondaryButton(label: dialog.t(CommonTextKeys.cancel), onPressed: () => Navigator.of(dialog).pop(false)),
          JitanPrimaryButton(
            label: action,
            color: destructive ? JitanColors.vermilion : JitanColors.ink,
            onPressed: () => Navigator.of(dialog).pop(true),
          ),
        ],
      ),
    ) ??
    false;
