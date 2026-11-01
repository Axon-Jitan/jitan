import 'package:flutter/material.dart';
import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:jitan_core/jitan_core.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../flow/terminal_controller.dart';
import '../flow/terminal_view.dart';
import '../l10n/terminal_text_keys.dart';
import '../screens/choose_project_screen.dart';
import '../screens/connect_screen.dart';
import '../screens/message_screen.dart';
import '../screens/registered_screen.dart';
import '../screens/scan_home_screen.dart';
import '../widgets/camera_panel.dart';
import '../widgets/terminal_page.dart';

/// Jitan Terminal: one screen at a time, chosen by [TerminalController].
class TerminalApp extends StatefulWidget {
  const TerminalApp({
    super.key,
    required this.controller,
    required this.languagesApi,
    required this.translations,
    required this.camera,
    this.clock,
  });

  final TerminalController controller;
  final LanguagesApi languagesApi;
  final TranslationService translations;
  final QrCamera camera;
  final DateTime Function()? clock;

  @override
  State<TerminalApp> createState() => _TerminalAppState();
}

class _TerminalAppState extends State<TerminalApp> {
  Translations _text = Translations.english();
  Map<String, String> _languages = const {};

  DateTime get _now => (widget.clock ?? DateTime.now)();

  @override
  void initState() {
    super.initState();
    widget.controller.start();
    _loadLanguages();
  }

  @override
  void dispose() {
    widget.controller.dispose();
    super.dispose();
  }

  /// English needs nothing: a failure here only hides the menu.
  Future<void> _loadLanguages() async {
    try {
      final languages = await widget.languagesApi.listLanguages();
      if (mounted) setState(() => _languages = {for (final l in languages) l.code: l.name});
    } on ApiClientException {
      // Stays on English.
    }
  }

  Future<void> _language(String code) async {
    final text = await widget.translations.load(code);
    if (mounted) setState(() => _text = text);
  }

  @override
  Widget build(BuildContext context) => TranslationScope(
    translations: _text,
    child: MaterialApp(
      title: 'Jitan Terminal',
      debugShowCheckedModeBanner: false,
      theme: JitanTheme.light(),
      home: ListenableBuilder(
        listenable: widget.controller,
        builder: (context, _) => TerminalPage(
          place: _place(context),
          languages: _languages,
          languageCode: _text.languageCode,
          onLanguage: _language,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: KeyedSubtree(key: ValueKey(widget.controller.view.runtimeType), child: _screen(context)),
          ),
        ),
      ),
    ),
  );

  String _place(BuildContext context) => widget.controller.terminal?.name ?? context.t(TerminalTextKeys.newTablet);

  Widget _screen(BuildContext context) {
    final controller = widget.controller;
    return switch (controller.view) {
      Starting() => const SizedBox.shrink(),
      Connecting(:final problem) => ConnectScreen(camera: widget.camera, onRead: controller.scanned, problem: problem),
      TabletReady(:final terminal) => MessageScreen(
        tone: MessageTone.good,
        title: context.t(TerminalTextKeys.readyTitle),
        text: context.t(
          TerminalTextKeys.readyPlace,
          args: {'terminal': terminal.name, 'company': terminal.companyName},
        ),
      ),
      Scanning(:final unreadable) => ScanHomeScreen(
        camera: widget.camera,
        onRead: controller.scanned,
        unreadable: unreadable,
        canScan: controller.terminal?.canScan ?? true,
        clock: () => _now,
      ),
      Registered(:final result) => RegisteredScreen(result: result, hour: _now.hour, onChange: controller.chooseProject),
      ChoosingProject(:final result, :final failed) => ChooseProjectScreen(
        result: result,
        busy: controller.busy,
        failed: failed,
        onChoose: (kind, projectId) => controller.switchTo(kind, projectId: projectId),
        onKeep: controller.backToCamera,
      ),
      SeeHr() => MessageScreen(
        tone: MessageTone.attention,
        title: context.t(TerminalTextKeys.seeHrTitle),
        text: context.t(TerminalTextKeys.seeHrText),
        below: [
          const SizedBox(height: 36),
          TerminalButton(large: true, label: context.t(TerminalTextKeys.back), onPressed: controller.backToCamera),
        ],
      ),
      NoConnection() => MessageScreen(
        tone: MessageTone.attention,
        title: context.t(TerminalTextKeys.noConnectionTitle),
        text: context.t(TerminalTextKeys.noConnectionText),
        below: [
          const SizedBox(height: 36),
          TerminalButton(large: true, label: context.t(TerminalTextKeys.tryAgain), onPressed: controller.backToCamera),
        ],
      ),
    };
  }
}
