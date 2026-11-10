import 'package:flutter/material.dart';
import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:jitan_core/jitan_core.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../l10n/admin_text_keys.dart';

/// Opens one list. Returns `true` when something was added.
Future<bool> showListDialog(BuildContext context, {required FixedListsApi api, required FixedListKind kind}) async =>
    await showJitanModal<bool>(context, builder: (_) => _ListDialog(api: api, kind: kind)) ?? false;

/// Figma `HR / Lists — Terminal kinds` (`1510:221`): the list's entries, the
/// missing ones in amber, and one button that adds exactly those.
class _ListDialog extends StatefulWidget {
  const _ListDialog({required this.api, required this.kind});

  final FixedListsApi api;
  final FixedListKind kind;

  @override
  State<_ListDialog> createState() => _ListDialogState();
}

class _ListDialogState extends State<_ListDialog> {
  FixedListDetail? _detail;
  bool _failed = false;
  bool _busy = false;
  bool _added = false;

  /// Access roles and languages are added where they belong.
  bool get _free => widget.kind == FixedListKind.accessRoles || widget.kind == FixedListKind.languages;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final detail = await widget.api.detail(widget.kind);
      if (mounted) setState(() => _detail = detail);
    } on ApiClientException {
      if (mounted) setState(() => _failed = true);
    }
  }

  Future<void> _add() async {
    setState(() {
      _busy = true;
      _failed = false;
    });
    try {
      final detail = await widget.api.addMissing(widget.kind);
      if (mounted) {
        setState(() {
          _detail = detail;
          _added = true;
        });
      }
    } on ApiClientException {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _addLabel(int missing) => switch (missing) {
    1 => context.t(AdminTextKeys.listsAddIt),
    2 => context.t(AdminTextKeys.listsAddBoth),
    _ => context.t(AdminTextKeys.listsAddAll, args: {'n': missing}),
  };

  String get _subtitle {
    final text = context.t(AdminTextKeys.listText(widget.kind.wireName));
    final missing = _detail?.missing ?? 0;
    return missing == 0 ? text : '${context.tPlural(AdminTextKeys.listsMissingCount, missing)} · $text';
  }

  Widget _entries(FixedListDetail detail) => Container(
    constraints: const BoxConstraints(maxHeight: 360),
    decoration: BoxDecoration(color: JitanColors.tableHeader, borderRadius: BorderRadius.circular(14)),
    child: ListView.separated(
      shrinkWrap: true,
      itemCount: detail.entries.length,
      separatorBuilder: (_, _) => const Divider(height: 1, color: JitanColors.inputBorder),
      itemBuilder: (context, i) {
        final entry = detail.entries[i];
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          child: Row(
            spacing: 16,
            children: [
              Expanded(
                child: Text(
                  entry.name,
                  overflow: TextOverflow.ellipsis,
                  style: JitanTextStyles.tableCell.copyWith(color: entry.present ? JitanColors.ink : JitanColors.inkMuted),
                ),
              ),
              Text(
                context.t(entry.present ? AdminTextKeys.listsEntryAdded : AdminTextKeys.listsEntryMissing),
                style: JitanTextStyles.tableCell.copyWith(color: entry.present ? JitanColors.inkMuted : JitanColors.warning),
              ),
            ],
          ),
        );
      },
    ),
  );

  void _close() => Navigator.of(context).pop(_added);

  @override
  Widget build(BuildContext context) {
    final detail = _detail;
    final missing = detail?.missing ?? 0;
    final note = Text(
      context.t(_free ? AdminTextKeys.listsFree : AdminTextKeys.listsReadsByName),
      style: JitanTextStyles.stateMessage.copyWith(fontSize: 13),
    );
    return JitanModal(
      width: 480,
      title: context.t(AdminTextKeys.listName(widget.kind.wireName)),
      subtitle: detail == null ? null : _subtitle,
      onClose: _close,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 16,
        children: [
          if (detail != null)
            _entries(detail)
          else if (!_failed)
            JitanLoadingState(label: context.t(AdminTextKeys.listsLoading)),
          if (_failed)
            Text(
              context.t(detail == null ? AdminTextKeys.listsLoadFailed : AdminTextKeys.listsAddFailed),
              style: JitanTextStyles.fieldError,
            ),
        ],
      ),
      leadingActions: [note],
      actions: [
        if (missing > 0 && !_free) ...[
          JitanSecondaryButton(label: context.t(CommonTextKeys.cancel), onPressed: _close),
          JitanPrimaryButton(label: _addLabel(missing), busy: _busy, onPressed: _busy ? null : _add),
        ] else
          JitanSecondaryButton(label: context.t(AdminTextKeys.listsClose), onPressed: _close),
      ],
    );
  }
}
