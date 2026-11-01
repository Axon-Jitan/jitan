import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:jitan_core/jitan_core.dart';
import 'package:jitan_ui/jitan_ui.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'src/app/terminal_app.dart';
import 'src/config/terminal_config.dart';
import 'src/device/terminal_store.dart';
import 'src/flow/terminal_controller.dart';
import 'src/l10n/terminal_text_keys.dart';
import 'src/widgets/camera_panel.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  registerJitanFontLicenses();
  // A tablet on a wall: landscape, full screen, and never asleep.
  SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  WakelockPlus.enable();

  final config = TerminalConfig.fromEnvironment();
  if (config == null) {
    runApp(const _ConfigurationErrorApp());
    return;
  }

  String? token;
  final transport = ApiTransport(baseUri: config.apiBaseUri, accessToken: () => token);
  final languagesApi = LanguagesApi(transport);
  runApp(
    TerminalApp(
      controller: TerminalController(
        api: TerminalDeviceApi(transport),
        store: const PlatformTerminalStore(),
        setToken: (value) => token = value,
      ),
      languagesApi: languagesApi,
      translations: TranslationService(languagesApi),
      camera: frontCamera,
    ),
  );
}

/// A build without `JITAN_API_BASE_URL`.
class _ConfigurationErrorApp extends StatelessWidget {
  const _ConfigurationErrorApp();

  @override
  Widget build(BuildContext context) => TranslationScope(
    translations: Translations.english(),
    child: MaterialApp(
      theme: JitanTheme.light(),
      home: Builder(
        builder: (context) => Scaffold(body: Center(child: Text(context.t(TerminalTextKeys.configError)))),
      ),
    ),
  );
}
