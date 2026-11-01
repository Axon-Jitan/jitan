import 'package:flutter/material.dart';
import 'package:jitan_ui/jitan_ui.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../l10n/terminal_text_keys.dart';
import 'terminal_styles.dart';

/// A live camera that reports each QR value it reads. Values are credentials:
/// never shown or logged. Injected, so tests need no camera.
typedef QrCamera = Widget Function(ValueChanged<String> onRead);

Widget frontCamera(ValueChanged<String> onRead) => _FrontCamera(onRead: onRead);

class _FrontCamera extends StatefulWidget {
  const _FrontCamera({required this.onRead});

  final ValueChanged<String> onRead;

  @override
  State<_FrontCamera> createState() => _FrontCameraState();
}

class _FrontCameraState extends State<_FrontCamera> {
  // A tablet on a wall faces the person.
  final _scanner = MobileScannerController(formats: const [BarcodeFormat.qrCode], facing: CameraFacing.front);

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
      if (value != null) widget.onRead(value);
    },
    errorBuilder: (context, error) => Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          context.t(TerminalTextKeys.cameraUnavailable),
          textAlign: TextAlign.center,
          style: TerminalStyles.small.copyWith(color: JitanColors.warmWhite),
        ),
      ),
    ),
  );
}

/// The dark square with its corners (Figma `1489:2`).
class CameraPanel extends StatelessWidget {
  const CameraPanel({super.key, required this.camera, required this.onRead});

  final QrCamera camera;
  final ValueChanged<String> onRead;

  @override
  Widget build(BuildContext context) => AspectRatio(
    aspectRatio: 1,
    child: ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: ColoredBox(
        color: JitanColors.ink,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Semantics(label: context.t(TerminalTextKeys.camera), child: camera(onRead)),
            const IgnorePointer(child: CustomPaint(painter: _Corners())),
          ],
        ),
      ),
    ),
  );
}

class _Corners extends CustomPainter {
  const _Corners();

  static const _inset = 30.0;
  static const _length = 44.0;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = JitanColors.surface
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    for (final (x, y, dx, dy) in [
      (_inset, _inset, 1.0, 1.0),
      (size.width - _inset, _inset, -1.0, 1.0),
      (_inset, size.height - _inset, 1.0, -1.0),
      (size.width - _inset, size.height - _inset, -1.0, -1.0),
    ]) {
      canvas.drawPath(
        Path()
          ..moveTo(x + dx * _length, y)
          ..lineTo(x, y)
          ..lineTo(x, y + dy * _length),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_Corners oldDelegate) => false;
}
