import 'package:flutter/material.dart';
import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../home/home_page.dart';
import '../l10n/employee_text_keys.dart';

/// "My QR" (Figma `1600:428`, 2026-11-13): the employee's permanent Terminal
/// QR (`tblUser.userQRcode`) on the page itself, to show at a Jitan
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
      return HomePage(navBar: navBar, onRefresh: _load, title: context.t(EmployeeTextKeys.qrNoneTitle), subtitle: context.t(EmployeeTextKeys.qrNoneText));
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
      fill: _code(context),
      children: [if (widget.account case final account?) _holder(context, account)],
    );
  }

  /// Whose QR it is: the name and the employee code.
  Widget _holder(BuildContext context, EmployeeAccount account) {
    final name = [account.firstName, account.lastName].whereType<String>().where((n) => n.isNotEmpty).join(' ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 3,
      children: [
        Text(name.isEmpty ? account.code : name, style: JitanMobileTextStyles.rowTitle.copyWith(fontSize: 17)),
        Text(context.t(EmployeeTextKeys.qrCode, args: {'code': account.code}), style: JitanMobileTextStyles.detail),
      ],
    );
  }

  /// The QR (a grey square while it loads), centred so the space above it,
  /// under the employee code, is the space below it, above the tab bar
  /// (user, 2026-11-13). The page adds 12 above the tab bar, so the bottom
  /// padding is 12 less than the top.
  Widget _code(BuildContext context) {
    const top = 36.0, bottom = 24.0;
    return LayoutBuilder(
      builder: (context, room) {
        // As wide as the page allows (at most 280), and smaller on a short
        // phone, so the whole code shows without scrolling.
        final size = [room.maxWidth, 280.0, room.maxHeight - top - bottom].reduce((a, b) => a < b ? a : b).clamp(0.0, 280.0);
        return Padding(
          padding: const EdgeInsets.only(top: top, bottom: bottom),
          child: Center(
            child: _loading || _qr == null
                ? Container(
                    width: size,
                    height: size,
                    decoration: BoxDecoration(color: JitanColors.inputFill, borderRadius: BorderRadius.circular(12)),
                  )
                : JitanQrCode(data: _qr!, semanticLabel: context.t(EmployeeTextKeys.qrSemantics), size: size, framed: false, filled: false),
          ),
        );
      },
    );
  }
}
