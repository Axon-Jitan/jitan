import 'package:flutter/material.dart';
import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../l10n/employee_text_keys.dart';
import '../widgets/mobile_widgets.dart';

/// "My QR" (Figma 50:67): the employee's permanent Terminal QR
/// (`tblUser.userQRcode`) to present at a Jitan Terminal. A credential: it
/// is fetched each time, shown only as a QR, and never logged or stored on
/// the phone. It never onboards or recovers an account.
class MyQrScreen extends StatefulWidget {
  const MyQrScreen({super.key, required this.meApi, required this.account, required this.onSessionEnded, this.bottomBar});

  final MeApi meApi;

  /// The name on the card; `null` while unknown.
  final EmployeeAccount? account;
  final VoidCallback onSessionEnded;
  final Widget? bottomBar;

  @override
  State<MyQrScreen> createState() => _MyQrScreenState();
}

class _MyQrScreenState extends State<MyQrScreen> {
  String? _qr;
  ApiClientException? _failure;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failure = null;
    });
    try {
      final qr = await widget.meApi.terminalQr();
      if (mounted) {
        setState(() {
          _qr = qr.qrCode;
          _loading = false;
        });
      }
    } on ApiClientException catch (e) {
      if (e.statusCode == 401) return widget.onSessionEnded();
      if (mounted) {
        setState(() {
          _failure = e;
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final account = widget.account;
    final name = [account?.firstName, account?.lastName].whereType<String>().where((n) => n.isNotEmpty).join(' ');
    return Scaffold(
      backgroundColor: JitanColors.warmWhite,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 10, 24, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Align(alignment: Alignment.centerLeft, child: JitanWordmark()),
                      const SizedBox(height: 40),
                      Semantics(header: true, child: Text(context.t(EmployeeTextKeys.qrTitle), style: JitanMobileTextStyles.title)),
                      const SizedBox(height: 8),
                      Text(context.t(EmployeeTextKeys.qrText), style: JitanMobileTextStyles.body),
                      const SizedBox(height: 32),
                      Container(
                        padding: const EdgeInsets.fromLTRB(22, 22, 22, 26),
                        decoration: BoxDecoration(
                          color: JitanColors.surface,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: JitanColors.inputBorder),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (name.isNotEmpty || account != null) ...[
                              Text(name.isEmpty ? account!.code : name, style: JitanMobileTextStyles.identityName),
                              const SizedBox(height: 6),
                            ],
                            Text(context.t(EmployeeTextKeys.qrCaption), style: JitanMobileTextStyles.identityDetail),
                            const SizedBox(height: 28),
                            Center(child: _code(context)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (widget.bottomBar case final bar?) ...[const SizedBox(height: 16), bar],
            ],
          ),
        ),
      ),
    );
  }

  Widget _code(BuildContext context) {
    if (_loading) {
      return const SizedBox(height: 240, child: Center(child: CircularProgressIndicator(color: JitanColors.ink, strokeWidth: 2)));
    }
    final failure = _failure;
    if (failure != null) {
      return Column(
        children: [
          const SizedBox(height: 30),
          Text(
            context.t(failure.statusCode == 404 ? EmployeeTextKeys.qrNone : EmployeeTextKeys.qrLoadFailed),
            textAlign: TextAlign.center,
            style: JitanMobileTextStyles.cardTitleSmall,
          ),
          if (failure.statusCode != 404) ...[
            const SizedBox(height: 16),
            JitanMobileButton(label: context.t(EmployeeTextKeys.todayTryAgain), onPressed: _load),
          ],
          const SizedBox(height: 30),
        ],
      );
    }
    return Column(
      children: [
        LayoutBuilder(
          builder: (context, constraints) => JitanQrCode(
            data: _qr!,
            semanticLabel: context.t(EmployeeTextKeys.qrSemantics),
            size: constraints.maxWidth.clamp(160.0, 240.0),
          ),
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.qr_code_scanner, size: 16, color: JitanColors.inkMuted),
            const SizedBox(width: 8),
            Text(context.t(EmployeeTextKeys.qrReady), style: JitanMobileTextStyles.identityDetail),
          ],
        ),
      ],
    );
  }
}
