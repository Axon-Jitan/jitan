import 'package:flutter/material.dart';
import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:jitan_core/jitan_core.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../groups/group_state_text.dart';
import '../l10n/admin_text_keys.dart';
import 'connect_terminal_dialog.dart';
import 'manage_terminal_dialog.dart';
import 'terminal_dialog.dart';
import 'terminals_controller.dart';
import 'terminals_table.dart';

/// HR/Admin "Terminals" (Figma `1488:2`): the shared tablets of every company
/// the viewer may see.
class TerminalsScreen extends StatefulWidget {
  const TerminalsScreen({
    super.key,
    required this.api,
    required this.companiesApi,
    required this.locationsApi,
    this.clock,
  });

  final TerminalsApi api;
  final CompaniesApi companiesApi;
  final LocationsApi locationsApi;
  final DateTime Function()? clock;

  @override
  State<TerminalsScreen> createState() => _TerminalsScreenState();
}

class _TerminalsScreenState extends State<TerminalsScreen> {
  late final _controller = TerminalsController(widget.api)..load();

  DateTime get _now => (widget.clock ?? DateTime.now)();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _say(String text) => ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(text)));

  Future<Terminal?> _edit([Terminal? terminal]) => showTerminalDialog(
    context,
    api: widget.api,
    companiesApi: widget.companiesApi,
    locationsApi: widget.locationsApi,
    terminal: terminal,
  );

  Future<void> _connect(Terminal terminal) async {
    await showConnectTerminalDialog(context, api: widget.api, terminal: terminal);
    await _controller.load();
  }

  /// "Continue": the tablet is connected right after the terminal is saved.
  Future<void> _add() async {
    final created = await _edit();
    if (created == null || !mounted) return;
    await _controller.load();
    if (mounted) await _connect(created);
  }

  Future<void> _open(Terminal terminal) async {
    final action = await showManageTerminalDialog(context, api: widget.api, terminal: terminal, now: _now);
    await _controller.load();
    if (action == null || !mounted) return;
    final current = _controller.all.where((t) => t.id == terminal.id).firstOrNull ?? terminal;
    switch (action) {
      case TerminalAction.edit:
        await _edit(current);
        await _controller.load();
      case TerminalAction.connect:
        await _connect(current);
      case TerminalAction.deactivate:
        await _deactivate(current);
      case TerminalAction.remove:
        await _remove(current);
    }
  }

  Future<void> _deactivate(Terminal terminal) async {
    final sure = await confirmTerminalAction(
      context,
      title: context.t(AdminTextKeys.terminalDeactivateTitle, args: {'terminal': terminal.name}),
      text: context.t(AdminTextKeys.terminalDeactivateText),
      action: context.t(AdminTextKeys.terminalDeactivate),
    );
    if (sure) await _run(() => widget.api.deactivate(terminal));
  }

  Future<void> _remove(Terminal terminal) async {
    final sure = await confirmTerminalAction(
      context,
      title: context.t(AdminTextKeys.terminalRemoveTitle, args: {'terminal': terminal.name}),
      text: context.t(AdminTextKeys.terminalRemoveText),
      action: context.t(AdminTextKeys.terminalRemove),
      destructive: true,
    );
    if (sure) await _run(() => widget.api.remove(terminal));
  }

  Future<void> _run(Future<Object?> Function() change) async {
    try {
      await change();
    } on ApiClientException {
      if (mounted) _say(context.t(AdminTextKeys.terminalChangeFailed));
    }
    await _controller.load();
  }

  @override
  Widget build(BuildContext context) => JitanListPage(
    top: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        JitanPageHeader(
          title: context.t(AdminTextKeys.terminalsTitle),
          subtitle: context.t(AdminTextKeys.terminalsSubtitle),
          action: JitanPrimaryButton(
            label: context.t(AdminTextKeys.terminalAdd),
            height: JitanDimensions.controlHeight,
            onPressed: _add,
          ),
        ),
        const SizedBox(height: JitanDimensions.headerToToolbar),
        Align(
          alignment: Alignment.centerLeft,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 300),
            child: JitanSearchField(
              clearTooltip: context.t(CommonTextKeys.searchClear),
              outlined: true,
              hintText: context.t(AdminTextKeys.terminalsSearch),
              onChanged: _controller.updateSearch,
            ),
          ),
        ),
        const SizedBox(height: JitanDimensions.toolbarToTable),
      ],
    ),
    list: [ListenableBuilder(listenable: _controller, builder: (context, _) => _content(context))],
  );

  Widget _content(BuildContext context) => switch (_controller.state) {
    TerminalsLoading() => _state(GroupStateText(context.t(AdminTextKeys.terminalsLoading))),
    TerminalsFailed() => _state(GroupStateText(context.t(AdminTextKeys.terminalsLoadFailed), onRetry: _controller.load)),
    TerminalsLoaded(terminals: []) => _state(GroupStateText(context.t(AdminTextKeys.terminalsEmpty))),
    TerminalsLoaded() => switch (_controller.visible) {
      [] => _state(GroupStateText(context.t(AdminTextKeys.terminalsNoMatch))),
      final terminals => TerminalsTable(terminals: terminals, now: _now, onOpen: _open),
    },
  };

  static Widget _state(Widget child) => SliverToBoxAdapter(child: child);
}
