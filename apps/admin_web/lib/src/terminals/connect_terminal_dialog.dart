import 'dart:async';

import 'package:flutter/material.dart';
import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../common/api_failure_text.dart';
import '../l10n/admin_text_keys.dart';

/// Generates a QR for [terminal] straight away and waits for the tablet.
Future<void> showConnectTerminalDialog(
  BuildContext context, {
  required TerminalsApi api,
  required Terminal terminal,
  DateTime Function()? clock,
}) => showJitanModal<void>(
  context,
  builder: (_) => ConnectTerminalDialog(api: api, terminal: terminal, clock: clock),
);

/// Figma `HR / Terminals V2 — Connect tablet` (`1488:567`), Code expired
/// (`1494:884`) and Connected (`1494:425`). The QR is a credential: it stays
/// a picture, and is gone once it expires.
class ConnectTerminalDialog extends StatefulWidget {
  const ConnectTerminalDialog({super.key, required this.api, required this.terminal, this.clock});

  final TerminalsApi api;
  final Terminal terminal;
  final DateTime Function()? clock;

  @override
  State<ConnectTerminalDialog> createState() => _ConnectTerminalDialogState();
}

class _ConnectTerminalDialogState extends State<ConnectTerminalDialog> {
  static const _checkEvery = Duration(seconds: 3);
  static const _qrSize = 250.0;

  TemporaryQrResponse? _qr;
  ApiClientException? _failure;
  bool _connected = false;
  Timer? _clockTimer;
  Timer? _checkTimer;

  DateTime get _now => (widget.clock ?? DateTime.now)();

  Duration get _left => _qr == null ? Duration.zero : _qr!.expiresAt.difference(_now.toUtc());
  bool get _expired => _qr != null && _left <= Duration.zero;

  @override
  void initState() {
    super.initState();
    _generate();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
    _checkTimer = Timer.periodic(_checkEvery, (_) => _check());
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _checkTimer?.cancel();
    super.dispose();
  }

  Future<void> _generate() async {
    setState(() {
      _qr = null;
      _failure = null;
    });
    try {
      final qr = await widget.api.pairingQr(widget.terminal);
      if (mounted) setState(() => _qr = qr);
    } on ApiClientException catch (e) {
      if (mounted) setState(() => _failure = e);
    }
  }

  /// A connection of its own: an already connected tablet checking in
  /// mustn't look like this one.
  Future<void> _check() async {
    if (_qr == null || _expired || _connected) return;
    try {
      final now = await widget.api.find(widget.terminal.id);
      if (!mounted || now.connectionTag == null || now.connectionTag == widget.terminal.connectionTag) return;
      _checkTimer?.cancel();
      setState(() => _connected = true);
    } on ApiClientException {
      // Asked again in a moment; the QR stays.
    }
  }

  static String _clockText(Duration left) => '${left.inMinutes}:${(left.inSeconds % 60).toString().padLeft(2, '0')}';

  void _close() => Navigator.of(context).pop();

  @override
  Widget build(BuildContext context) => _connected ? _ready(context) : _connecting(context);

  Widget _ready(BuildContext context) => JitanSuccessModal(
    title: context.t(AdminTextKeys.terminalReadyTitle, args: {'terminal': widget.terminal.name}),
    message: context.t(AdminTextKeys.terminalReadyText),
    buttonLabel: context.t(AdminTextKeys.terminalDone),
    onDone: _close,
  );

  Widget _connecting(BuildContext context) {
    final qr = _qr;
    final failure = _failure;
    return JitanModal(
      width: 440,
      title: context.t(AdminTextKeys.terminalConnectTitle),
      subtitle: context.t(AdminTextKeys.terminalConnectText),
      onClose: _close,
      body: SizedBox(
        width: double.infinity,
        child: failure != null
            ? _error(context, failure)
            : qr == null
            ? SizedBox(height: _qrSize, child: JitanLoadingState(label: context.t(AdminTextKeys.terminalsLoading)))
            : Column(
                spacing: 16,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: JitanColors.surface,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: JitanColors.inputBorder),
                    ),
                    child: _expired
                        ? Icon(Icons.qr_code_2, size: _qrSize, color: JitanColors.ink.withValues(alpha: 0.12))
                        : JitanQrCode(data: qr.qrCode, size: _qrSize, semanticLabel: context.t(AdminTextKeys.terminalConnectTitle)),
                  ),
                  _note(context),
                ],
              ),
      ),
      actions: [
        JitanSecondaryButton(label: context.t(AdminTextKeys.terminalFinishLater), onPressed: _close),
        if (_expired) JitanPrimaryButton(label: context.t(AdminTextKeys.terminalNewCode), onPressed: _generate),
      ],
    );
  }

  Widget _note(BuildContext context) {
    final color = _expired ? JitanColors.warning : JitanColors.inkMuted;
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 8,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        Flexible(
          child: _expired
              ? Text(context.t(AdminTextKeys.terminalCodeExpired), style: JitanTextStyles.tableCell.copyWith(color: color))
              : Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(text: context.t(AdminTextKeys.terminalWaiting), style: JitanTextStyles.tableCellStrong),
                      TextSpan(
                        text: ' ${context.t(AdminTextKeys.terminalTimeLeft, args: {'time': _clockText(_left)})}',
                        style: JitanTextStyles.tableCell.copyWith(color: JitanColors.inkMuted),
                      ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }

  Widget _error(BuildContext context, ApiClientException failure) {
    final keys = failureTextKeysFor(failure);
    return JitanInlineError(title: context.t(keys.title), message: context.t(keys.message));
  }
}
