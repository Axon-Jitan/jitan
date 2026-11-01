import 'package:flutter/material.dart';
import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../l10n/employee_web_text_keys.dart';

Future<void> showMyQrDialog(BuildContext context, {required MeApi me}) =>
    showJitanModal<void>(context, builder: (_) => _MyQrDialog(me: me));

/// My QR (Figma `1499:82`). The code is a credential: asked for when opened,
/// only ever drawn, and gone with the window.
class _MyQrDialog extends StatefulWidget {
  const _MyQrDialog({required this.me});

  final MeApi me;

  @override
  State<_MyQrDialog> createState() => _MyQrDialogState();
}

class _MyQrDialogState extends State<_MyQrDialog> {
  String? _qr;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final qr = await widget.me.terminalQr();
      if (mounted) setState(() => _qr = qr.qrCode);
    } on ApiClientException {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final qr = _qr;
    final title = context.t(EmployeeWebTextKeys.qrTitle);
    return JitanModal(
      width: 420,
      title: title,
      subtitle: context.t(EmployeeWebTextKeys.qrText),
      body: Center(
        child: _failed
            ? Text(context.t(EmployeeWebTextKeys.qrMissing), textAlign: TextAlign.center, style: JitanTextStyles.stateMessage)
            : qr == null
            ? SizedBox(width: 275, height: 275, child: JitanLoadingState(label: context.t(EmployeeWebTextKeys.loading)))
            : LayoutBuilder(
                builder: (context, constraints) =>
                    JitanQrCode(data: qr, size: constraints.maxWidth < 275 ? constraints.maxWidth : 275, semanticLabel: title),
              ),
      ),
      actions: [
        JitanSecondaryButton(label: context.t(EmployeeWebTextKeys.close), onPressed: () => Navigator.of(context).pop()),
      ],
    );
  }
}
