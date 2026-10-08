import 'package:flutter/material.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../onboarding/qr_scanner_view.dart';
import 'mobile_widgets.dart';

// Spacing measured from the Figma "Auth / 06" and "Onboarding / 02B" frames
// (390 × 844).

/// Logo, title and subtitle at the top of the auth and scanner screens
/// (Figma "Auth / …", "Onboarding / 02B").
class BrandedHeader extends StatelessWidget {
  const BrandedHeader({super.key, required this.title, required this.text});

  final String title;
  final String text;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      JitanWordmark(style: JitanMobileTextStyles.logo.copyWith(fontSize: 24)),
      const SizedBox(height: 28),
      Semantics(header: true, child: Text(title, style: JitanMobileTextStyles.formTitle)),
      const SizedBox(height: 10),
      Text(text, style: JitanMobileTextStyles.caption),
    ],
  );
}

/// The warm-white scrolling page of those screens.
class BrandedScaffold extends StatelessWidget {
  const BrandedScaffold({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: JitanColors.warmWhite,
    body: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(OnboardingPage.margin, 0, OnboardingPage.margin, 24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
      ),
    ),
  );
}

/// The square camera viewfinder of "Recover account" and "Scan your
/// onboarding QR": dark frame, live camera, white corners and a hint. While
/// a scanned QR is being verified ([busy]) the camera stops and a progress
/// indicator replaces the hint.
class QrCameraFrame extends StatelessWidget {
  const QrCameraFrame({
    super.key,
    required this.scannerView,
    required this.onDetected,
    required this.busy,
    required this.hint,
  });

  final QrScannerView scannerView;
  final ValueChanged<String> onDetected;
  final bool busy;
  final String hint;

  @override
  Widget build(BuildContext context) => AspectRatio(
    aspectRatio: 1,
    child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: JitanColors.ink, borderRadius: BorderRadius.circular(22)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(
          fit: StackFit.expand,
          children: [
            const ColoredBox(color: JitanColors.sidebarItemActive),
            if (!busy) scannerView(onDetected),
            const IgnorePointer(child: _ViewfinderCorners()),
            IgnorePointer(
              child: Center(
                child: busy
                    ? const CircularProgressIndicator(color: JitanColors.surface)
                    : Text(
                        hint,
                        textAlign: TextAlign.center,
                        style: JitanMobileTextStyles.noteTitle.copyWith(fontSize: 12, color: JitanColors.surface),
                      ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// The four white corner brackets (4 × 34 px, 12 px inside the preview).
class _ViewfinderCorners extends StatelessWidget {
  const _ViewfinderCorners();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(12),
    child: Stack(
      children: [
        for (final alignment in [Alignment.topLeft, Alignment.topRight, Alignment.bottomLeft, Alignment.bottomRight])
          Align(
            alignment: alignment,
            child: SizedBox.square(
              dimension: 34,
              child: CustomPaint(painter: _CornerPainter(alignment)),
            ),
          ),
      ],
    ),
  );
}

class _CornerPainter extends CustomPainter {
  const _CornerPainter(this.alignment);

  final Alignment alignment;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = JitanColors.surface;
    const t = 4.0;
    final left = alignment.x < 0;
    final top = alignment.y < 0;
    canvas
      ..drawRect(Rect.fromLTWH(0, top ? 0 : size.height - t, size.width, t), paint)
      ..drawRect(Rect.fromLTWH(left ? 0 : size.width - t, 0, t, size.height), paint);
  }

  @override
  bool shouldRepaint(_CornerPainter oldDelegate) => oldDelegate.alignment != alignment;
}

