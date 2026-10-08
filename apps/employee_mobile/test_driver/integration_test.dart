import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

/// Runs an integration test with `flutter drive` and saves every
/// `binding.takeScreenshot(name)` to `build/visual_review/<name>.png`.
Future<void> main() => integrationDriver(
  onScreenshot: (name, bytes, [args]) async {
    final file = File('build/visual_review/$name.png');
    await file.create(recursive: true);
    await file.writeAsBytes(bytes);
    return true;
  },
);
