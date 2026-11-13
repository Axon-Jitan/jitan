import 'package:flutter/widgets.dart';
import 'package:qr/qr.dart';

import '../theme/jitan_colors.dart';

/// A scannable QR code for [data], drawn in ink on white inside the rounded,
/// outlined frame from Figma (`Onboarding QR modal` 153:448).
///
/// Medium error correction (~15%) and a quiet zone of four modules, as the
/// QR specification requires for reliable scanning.
class JitanQrCode extends StatelessWidget {
  const JitanQrCode({super.key, required this.data, required this.semanticLabel, this.size = 320, this.framed = true, this.filled = true});

  final String data;

  /// Read by screen readers instead of the (meaningless) pattern.
  final String semanticLabel;
  final double size;

  /// `false` when it already sits in a card of its own (Figma `1532:181`):
  /// no outline, the quiet zone stays.
  final bool framed;

  /// A white square behind the code; without it the code sits on the page
  /// (light enough for its quiet zone), as on the employee's QR tab.
  final bool filled;

  static const _frameRadius = 14.0;
  static const _quietZoneModules = 4;

  @override
  Widget build(BuildContext context) {
    final image = QrImage(QrCode(payload: QrPayload.fromString(data)));
    return Semantics(
      image: true,
      label: semanticLabel,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: filled ? JitanColors.surface : null,
          borderRadius: BorderRadius.circular(_frameRadius),
          border: framed ? Border.all(color: JitanColors.inputBorder) : null,
        ),
        child: CustomPaint(painter: _QrPainter(image, quietZone: _quietZoneModules)),
      ),
    );
  }
}

class _QrPainter extends CustomPainter {
  _QrPainter(this._image, {required this.quietZone});

  final QrImage _image;
  final int quietZone;

  @override
  void paint(Canvas canvas, Size size) {
    final count = _image.moduleCount;
    // Whole-pixel modules keep edges crisp for camera scanning.
    final module = (size.shortestSide / (count + quietZone * 2)).floorToDouble();
    // Whole-pixel offset too: a half-pixel start blurs module edges into seams.
    final offset = ((size.shortestSide - module * count) / 2).roundToDouble();
    final paint = Paint()
      ..color = JitanColors.ink
      ..isAntiAlias = false;
    for (var row = 0; row < count; row++) {
      for (var col = 0; col < count; col++) {
        if (_image.isDark(row, col)) {
          canvas.drawRect(Rect.fromLTWH(offset + col * module, offset + row * module, module, module), paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(_QrPainter oldDelegate) => !identical(oldDelegate._image, _image);
}
