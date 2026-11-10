import 'package:flutter/material.dart';
import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../groups/group_state_text.dart';
import '../l10n/admin_text_keys.dart';
import 'list_dialog.dart';
import 'lists_controller.dart';

/// HR/Admin "Lists" (Figma `1510:2`, ready `1510:387`): the fixed lists Jitan
/// reads by name, what each misses, and one button that adds exactly that.
class ListsScreen extends StatefulWidget {
  const ListsScreen({super.key, required this.api});

  final FixedListsApi api;

  @override
  State<ListsScreen> createState() => _ListsScreenState();
}

class _ListsScreenState extends State<ListsScreen> {
  late final _controller = ListsController(widget.api)..load();

  // Column widths proportional to Figma.
  static const _flexList = 600;
  static const _flexEntries = 160;
  static const _flexStatus = 260;
  static const _flexOpen = 36;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _open(FixedListKind kind) async {
    final added = await showListDialog(context, api: widget.api, kind: kind);
    if (added) await _controller.load();
  }

  @override
  Widget build(BuildContext context) => JitanListPage(
    top: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        JitanPageHeader(title: context.t(AdminTextKeys.listsTitle), subtitle: context.t(AdminTextKeys.listsSubtitle)),
        const SizedBox(height: JitanDimensions.headerToToolbar),
        ListenableBuilder(listenable: _controller, builder: (context, _) => _setupCard(context)),
      ],
    ),
    list: [ListenableBuilder(listenable: _controller, builder: (context, _) => _content(context))],
  );

  /// Only while something is missing (Figma `1510:2`); gone once ready.
  Widget _setupCard(BuildContext context) {
    final state = _controller.state;
    if (state is! ListsLoaded || state.overview.listsMissing == 0) return const SizedBox.shrink();
    final phone = MediaQuery.sizeOf(context).width < JitanDimensions.phoneBreakpoint;
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 6,
      children: [
        Text(
          context.tPlural(AdminTextKeys.listsMissingTitle, state.overview.listsMissing),
          style: JitanTextStyles.stateTitle.copyWith(fontSize: 16),
        ),
        Text(context.t(AdminTextKeys.listsMissingText), style: JitanTextStyles.stateMessage.copyWith(fontSize: 13)),
        if (_controller.addFailed) Text(context.t(AdminTextKeys.listsAddFailed), style: JitanTextStyles.fieldError),
      ],
    );
    final button = JitanPrimaryButton(
      label: context.t(AdminTextKeys.listsAddMissing),
      busy: _controller.adding,
      onPressed: _controller.adding ? null : _controller.addAllMissing,
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: JitanDimensions.toolbarToTable),
      child: JitanSurfaceCard(
        radius: JitanDimensions.tableCardRadius,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
          child: phone
              ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: 16, children: [text, button])
              : Row(spacing: 24, children: [Expanded(child: text), button]),
        ),
      ),
    );
  }

  Widget _content(BuildContext context) => switch (_controller.state) {
    ListsLoading() => _state(GroupStateText(context.t(AdminTextKeys.listsLoading))),
    ListsFailed() => _state(GroupStateText(context.t(AdminTextKeys.listsLoadFailed), onRetry: _controller.load)),
    ListsLoaded(:final overview) => _table(context, overview.lists),
  };

  Widget _table(BuildContext context, List<FixedListSummary> lists) {
    final t = TranslationScope.of(context);
    final phone = MediaQuery.sizeOf(context).width < JitanDimensions.phoneBreakpoint;
    return JitanSliverTable(
      onRowTap: (i) => _open(lists[i].kind),
      columns: [
        JitanTableColumn(label: t.t(AdminTextKeys.listsColumnList), flex: _flexList),
        if (!phone) JitanTableColumn(label: t.t(AdminTextKeys.listsColumnEntries), flex: _flexEntries),
        JitanTableColumn(label: t.t(AdminTextKeys.listsColumnStatus), flex: _flexStatus),
        const JitanTableColumn(label: '', flex: _flexOpen, align: JitanColumnAlign.end),
      ],
      rowCount: lists.length,
      cells: (i) {
        final list = lists[i];
        return [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            spacing: 3,
            children: [
              Text(
                context.t(AdminTextKeys.listName(list.kind.wireName)),
                overflow: TextOverflow.ellipsis,
                style: JitanTextStyles.tableCellStrong.copyWith(fontSize: 14),
              ),
              Text(
                context.t(AdminTextKeys.listText(list.kind.wireName)),
                overflow: TextOverflow.ellipsis,
                style: JitanTextStyles.tableCell.copyWith(color: JitanColors.inkMuted),
              ),
            ],
          ),
          if (!phone)
            Text(
              list.required == 0
                  ? '${list.entries}'
                  : context.t(AdminTextKeys.listsEntriesOf, args: {'entries': list.required - list.missing, 'required': list.required}),
              style: JitanTextStyles.tableCell,
            ),
          _status(context, list),
          const Icon(Icons.chevron_right, size: 18, color: JitanColors.inkMuted),
        ];
      },
      footer: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(context.t(AdminTextKeys.listsNote), style: JitanTextStyles.stateMessage.copyWith(fontSize: 12)),
      ),
    );
  }

  static Widget _status(BuildContext context, FixedListSummary list) {
    final color = list.isReady ? JitanColors.success : JitanColors.warning;
    return Row(
      spacing: 8,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        Flexible(
          child: Text(
            list.isReady ? context.t(AdminTextKeys.listsReady) : context.tPlural(AdminTextKeys.listsMissingCount, list.missing),
            overflow: TextOverflow.ellipsis,
            style: JitanTextStyles.tableCell.copyWith(color: list.isReady ? JitanColors.ink : JitanColors.warning),
          ),
        ),
      ],
    );
  }

  static Widget _state(Widget child) => SliverToBoxAdapter(child: child);
}
