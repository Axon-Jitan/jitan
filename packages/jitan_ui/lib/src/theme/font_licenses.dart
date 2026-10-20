import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Adds the bundled Inter and Inter Display fonts' SIL Open Font License to the app's licence
/// page, as the OFL requires. Call once from `main()`.
void registerJitanFontLicenses() {
  LicenseRegistry.addLicense(() async* {
    final text = await rootBundle.loadString('packages/jitan_ui/fonts/inter/OFL.txt');
    yield LicenseEntryWithLineBreaks(['Inter', 'Inter Display'], text);
  });
}
