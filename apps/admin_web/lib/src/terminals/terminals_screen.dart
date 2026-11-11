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

/// HR/Admin "Terminals" (Figma `1545:111`; no results `1545:830`, nothing
/// yet `1545:955`): the shared tablets, used by employees of every company.
class TerminalsScreen extends StatefulWidget {
  const TerminalsScreen({super.key, required this.api, this.clock});

  final TerminalsApi api;
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

  void _say(String text, {bool failed = false}) => showJitanToast(context, text, failed: failed);

  Future<Terminal?> _edit([Terminal? terminal]) => showTerminalDialog(context, api: widget.api, terminal: terminal);

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
    final action = await showManageTerminalDialog(context, terminal: terminal, now: _now);
    if (action == null || !mounted) return;
    switch (action) {
      case TerminalAction.edit:
        final saved = await _edit(terminal);
        if (saved != null && mounted) _say(context.t(AdminTextKeys.terminalSaved, args: {'terminal': saved.name}));
        await _controller.load();
      case TerminalAction.connect:
        await _connect(terminal);
      case TerminalAction.deactivate:
        final sure = await confirmTerminalDeactivate(context, terminal);
        if (sure) await _change(() => widget.api.deactivate(terminal), AdminTextKeys.terminalDeactivated);
      case TerminalAction.reactivate:
        await _change(() => widget.api.reactivate(terminal), AdminTextKeys.terminalReactivated);
    }
  }

  /// Runs [change]; the toast follows the server's answer, never before it.
  Future<void> _change(Future<Terminal> Function() change, String doneKey) async {
    try {
      final done = await change();
      if (mounted) _say(context.t(doneKey, args: {'terminal': done.name}));
    } on ApiClientException {
      if (mounted) _say(context.t(AdminTextKeys.terminalChangeFailed), failed: true);
    }
    await _controller.load();
  }

  bool get _isEmpty => switch (_controller.state) {
    TerminalsLoaded(terminals: []) => true,
    _ => false,
  };

  @override
  Widget build(BuildContext context) => JitanListPage(
    top: ListenableBuilder(
      listenable: _controller,
      builder: (context, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          JitanPageHeader(
            title: context.t(AdminTextKeys.terminalsTitle),
            subtitle: switch (_controller.state) {
              TerminalsLoaded(:final terminals) when terminals.isNotEmpty =>
                context.tPlural(AdminTextKeys.terminalCount, terminals.length),
              _ => context.t(AdminTextKeys.terminalsSubtitle),
            },
            action: _isEmpty
                ? null
                : JitanPrimaryButton(
                    label: context.t(AdminTextKeys.terminalAdd),
                    icon: Icons.add,
                    height: JitanDimensions.controlHeight,
                    onPressed: _add,
                  ),
          ),
          const SizedBox(height: JitanDimensions.headerToToolbar),
          if (!_isEmpty) ...[_toolbar(context), const SizedBox(height: JitanDimensions.toolbarToTable)],
        ],
      ),
    ),
    list: [ListenableBuilder(listenable: _controller, builder: (context, _) => _content(context))],
  );

  /// A search box and All · Active · Inactive, as on Locations.
  Widget _toolbar(BuildContext context) {
    final search = JitanSearchField(
      clearTooltip: context.t(CommonTextKeys.searchClear),
      outlined: true,
      hintText: context.t(AdminTextKeys.terminalsSearch),
      onChanged: _controller.updateSearch,
    );
    final status = JitanPillSwitch<TerminalStatusFilter?>(
      options: [
        (null, context.t(AdminTextKeys.terminalsFilterAll)),
        (TerminalStatusFilter.active, context.t(CommonTextKeys.statusActive)),
        (TerminalStatusFilter.inactive, context.t(CommonTextKeys.statusInactive)),
      ],
      value: _controller.status,
      onChanged: _controller.updateStatus,
    );
    return LayoutBuilder(
      builder: (context, constraints) => constraints.maxWidth < JitanDimensions.phoneBreakpoint
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 12,
              children: [search, status],
            )
          : Row(
              spacing: 12,
              children: [SizedBox(width: 320, child: search), status],
            ),
    );
  }

  Widget _content(BuildContext context) => switch (_controller.state) {
    TerminalsLoading() => _centered(JitanLoadingState(label: context.t(AdminTextKeys.terminalsLoading))),
    TerminalsFailed() => SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.only(top: 20),
        child: GroupStateText(context.t(AdminTextKeys.terminalsLoadFailed), onRetry: _controller.load),
      ),
    ),
    TerminalsLoaded(terminals: []) => SliverToBoxAdapter(
      child: JitanEmptyPage(
        title: context.t(AdminTextKeys.terminalsEmptyTitle),
        message: context.t(AdminTextKeys.terminalsEmptyText),
        actionLabel: context.t(AdminTextKeys.terminalAdd),
        onAction: _add,
      ),
    ),
    TerminalsLoaded() => switch (_controller.visible) {
      [] => SliverToBoxAdapter(child: _nothingShown(context)),
      final terminals => TerminalsTable(terminals: terminals, now: _now, onOpen: _open),
    },
  };

  /// Nothing to show, said for what HR did: a search or a status (`1545:830`).
  Widget _nothingShown(BuildContext context) {
    final (title, message) = switch ((_controller.search, _controller.status)) {
      ('', TerminalStatusFilter.inactive) => (AdminTextKeys.terminalsNoInactiveTitle, AdminTextKeys.terminalsNoInactiveText),
      ('', TerminalStatusFilter.active) => (AdminTextKeys.terminalsNoActiveTitle, AdminTextKeys.terminalsNoActiveText),
      _ => (AdminTextKeys.terminalsNoMatchTitle, AdminTextKeys.terminalsNoMatchText),
    };
    return JitanNoResults(title: context.t(title), message: context.t(message));
  }

  static Widget _centered(Widget child) => JitanTableStateSliver(child: child);
}
