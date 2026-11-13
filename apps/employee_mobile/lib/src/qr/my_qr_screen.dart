import 'package:flutter/material.dart';
import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../home/home_page.dart';
import '../l10n/employee_text_keys.dart';

/// "My QR" (Figma `1600:428`, 2026-11-13): the employee's permanent Terminal
/// QR (`tblUser.userQRcode`) on one white pass, to show at a Jitan
/// Terminal. A credential: it is fetched each time, shown only as a QR, and
/// never logged or stored on the phone. It never onboards or recovers an
/// account.
class MyQrScreen extends StatefulWidget {
  const MyQrScreen({super.key, required this.meApi, required this.account, required this.onSessionEnded, this.bottomBar});

  final MeApi meApi;

  /// The name and code on the pass; `null` while unknown.
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
    final navBar = widget.bottomBar ?? const SizedBox.shrink();
    final failure = _failure;
    if (failure != null && failure.statusCode == 404) {
      return HomePage(
        navBar: navBar,
        onRefresh: _load,
        title: context.t(EmployeeTextKeys.qrNoneTitle),
        subtitle: context.t(EmployeeTextKeys.qrNoneText),
      );
    }
    if (failure != null) {
      return HomePage(
        navBar: navBar,
        onRefresh: _load,
        title: context.t(EmployeeTextKeys.qrFailedTitle),
        subtitle: context.t(EmployeeTextKeys.todayCheckConnection),
        action: JitanMobileButton(label: context.t(EmployeeTextKeys.todayTryAgain), size: JitanMobileButtonSize.phone, onPressed: _load),
      );
    }
    return HomePage(
      navBar: navBar,
      onRefresh: _load,
      title: context.t(EmployeeTextKeys.qrTitle),
      subtitle: context.t(EmployeeTextKeys.qrText),
      children: [_pass(context)],
    );
  }

  /// The white pass: name, employee code and the QR (a grey square while it
  /// loads).
  Widget _pass(BuildContext context) {
    final account = widget.account;
    final name = [account?.firstName, account?.lastName].whereType<String>().where((n) => n.isNotEmpty).join(' ');
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: JitanColors.surface, borderRadius: BorderRadius.circular(24)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (account != null) ...[
            Text(name.isEmpty ? account.code : name, style: JitanMobileTextStyles.rowTitle.copyWith(fontSize: 17)),
            const SizedBox(height: 3),
            Text(context.t(EmployeeTextKeys.qrCode, args: {'code': account.code}), style: JitanMobileTextStyles.detail),
            const SizedBox(height: 24),
          ],
          LayoutBuilder(
            builder: (context, constraints) {
              final size = constraints.maxWidth.clamp(160.0, 280.0);
              return Center(
                child: _loading || _qr == null
                    ? Container(
                        width: size,
                        height: size,
                        decoration: BoxDecoration(color: JitanColors.inputFill, borderRadius: BorderRadius.circular(12)),
                      )
                    : JitanQrCode(data: _qr!, semanticLabel: context.t(EmployeeTextKeys.qrSemantics), size: size, framed: false),
              );
            },
          ),
        ],
      ),
    );
  }
}
