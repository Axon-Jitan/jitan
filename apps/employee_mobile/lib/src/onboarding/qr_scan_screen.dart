import 'package:flutter/material.dart';
import 'package:jitan_core/jitan_core.dart';
import 'package:jitan_ui/jitan_ui.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../l10n/employee_text_keys.dart';

/// Opens the camera and returns the first QR value read, or `null` when the
/// employee closes the scanner. The value is a credential: it is never shown
/// or logged.
typedef QrScanner = Future<String?> Function(BuildContext context);

Future<String?> scanQrWithCamera(BuildContext context) =>
    Navigator.of(context).push<String>(MaterialPageRoute(builder: (_) => const QrScanScreen()));

class QrScanScreen extends StatefulWidget {
  const QrScanScreen({super.key});

  @override
  State<QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends State<QrScanScreen> {
  final _scanner = MobileScannerController(formats: const [BarcodeFormat.qrCode]);
  bool _done = false;

  @override
  void dispose() {
    _scanner.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_done) return;
    final value = capture.barcodes.map((b) => b.rawValue).whereType<String>().where((v) => v.isNotEmpty).firstOrNull;
    if (value == null) return;
    _done = true;
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: JitanColors.ink,
    appBar: AppBar(
      backgroundColor: JitanColors.ink,
      foregroundColor: JitanColors.warmWhite,
      title: Text(context.t(EmployeeTextKeys.scanTitle)),
      leading: IconButton(
        tooltip: context.t(CommonTextKeys.cancel),
        icon: const Icon(Icons.close),
        onPressed: () => Navigator.of(context).pop(),
      ),
    ),
    body: Stack(
      fit: StackFit.expand,
      children: [
        MobileScanner(
          controller: _scanner,
          onDetect: _onDetect,
          errorBuilder: (context, error) => Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text(
                context.t(EmployeeTextKeys.scanCameraUnavailable),
                textAlign: TextAlign.center,
                style: JitanMobileTextStyles.body.copyWith(color: JitanColors.warmWhite),
              ),
            ),
          ),
        ),
        // Viewfinder.
        IgnorePointer(
          child: Center(
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                border: Border.all(color: JitanColors.warmWhite, width: 3),
                borderRadius: BorderRadius.circular(22),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
