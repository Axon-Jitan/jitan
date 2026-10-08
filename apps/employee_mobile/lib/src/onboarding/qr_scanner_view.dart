import 'package:flutter/material.dart';
import 'package:jitan_ui/jitan_ui.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../l10n/employee_text_keys.dart';

/// A live camera view that reports each QR value it reads, for the screens
/// with an embedded scanner ("Onboarding / 02B", "Auth / 06"). Values are
/// credentials: never shown or logged.
typedef QrScannerView = Widget Function(ValueChanged<String> onDetected);

Widget cameraQrScannerView(ValueChanged<String> onDetected) => _EmbeddedQrScanner(onDetected: onDetected);

class _EmbeddedQrScanner extends StatefulWidget {
  const _EmbeddedQrScanner({required this.onDetected});

  final ValueChanged<String> onDetected;

  @override
  State<_EmbeddedQrScanner> createState() => _EmbeddedQrScannerState();
}

class _EmbeddedQrScannerState extends State<_EmbeddedQrScanner> {
  final _scanner = MobileScannerController(formats: const [BarcodeFormat.qrCode]);

  @override
  void dispose() {
    _scanner.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MobileScanner(
    controller: _scanner,
    onDetect: (capture) {
      final value = capture.barcodes.map((b) => b.rawValue).whereType<String>().where((v) => v.isNotEmpty).firstOrNull;
      if (value != null) widget.onDetected(value);
    },
    errorBuilder: (context, error) => Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          context.t(EmployeeTextKeys.scanCameraUnavailable),
          textAlign: TextAlign.center,
          style: JitanMobileTextStyles.caption.copyWith(color: JitanColors.warmWhite),
        ),
      ),
    ),
  );
}
