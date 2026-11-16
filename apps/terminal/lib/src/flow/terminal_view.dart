import 'package:jitan_models/jitan_models.dart';

/// What the tablet is showing. One screen at a time; each comes back to
/// [Scanning] by itself, so a shared tablet is never left on someone's name.
sealed class TerminalView {
  const TerminalView();
}

class Starting extends TerminalView {
  const Starting();
}

/// Connect this tablet (Figma `1489:94`), with what went wrong (`1494:101`).
class Connecting extends TerminalView {
  const Connecting({this.problem = ConnectProblem.none});

  final ConnectProblem problem;
}

enum ConnectProblem { none, expired, unreadable, noConnection }

/// This tablet is ready (Figma `1494:51`).
class TabletReady extends TerminalView {
  const TabletReady(this.terminal);

  final TerminalInfo terminal;
}

/// The camera is the home screen (Figma `1489:2`), with a note when a code
/// wasn't read (`1489:51`).
class Scanning extends TerminalView {
  const Scanning({this.unreadable = false});

  final bool unreadable;
}

/// Checked in, checked out, or the same scan again (Figma `1489:28`,
/// `1494:2`, `1494:18`). [qrCode] proves who changes the project; it stays in
/// memory only as long as this screen does.
class Registered extends TerminalView {
  const Registered(this.result, this.qrCode);

  final TerminalScanResult result;
  final String qrCode;
}

/// What are you working on? (Figma `1494:65`).
class ChoosingProject extends TerminalView {
  const ChoosingProject(this.result, this.qrCode, {this.failed = false});

  final TerminalScanResult result;
  final String qrCode;
  final bool failed;
}

/// Ask HR (Figma `1489:77`). [outsideHours]: the scan was outside
/// 05:00–19:00, which Jitan doesn't register (D52).
class SeeHr extends TerminalView {
  const SeeHr({this.outsideHours = false});

  final bool outsideHours;
}

/// Jitan can't be reached, even after sending the scan once more (Figma
/// `1494:34`, D42). The scan may have been stored, so the text doesn't say
/// that nothing was registered (review M11).
class NoConnection extends TerminalView {
  const NoConnection();
}
