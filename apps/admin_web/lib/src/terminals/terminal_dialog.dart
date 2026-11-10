import 'package:flutter/material.dart';
import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:jitan_core/jitan_core.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../common/api_failure_text.dart';
import '../l10n/admin_text_keys.dart';

/// Adds a terminal, or changes [terminal]. Returns what the server saved.
Future<Terminal?> showTerminalDialog(BuildContext context, {required TerminalsApi api, Terminal? terminal}) =>
    showJitanModal<Terminal>(
      context,
      barrierDismissible: false,
      builder: (_) => _TerminalDialog(api: api, terminal: terminal),
    );

/// Figma `HR / Terminals V3 — Add terminal` (`1507:126`), vehicle (`1507:280`)
/// and Edit (`1507:595`): the kind, a name and the tablet's serial number. A
/// terminal is shared by every company, so it has no company; a van's number
/// plate goes in its name.
class _TerminalDialog extends StatefulWidget {
  const _TerminalDialog({required this.api, this.terminal});

  final TerminalsApi api;
  final Terminal? terminal;

  @override
  State<_TerminalDialog> createState() => _TerminalDialogState();
}

class _TerminalDialogState extends State<_TerminalDialog> {
  late final _name = TextEditingController(text: widget.terminal?.name);
  late final _serial = TextEditingController(text: widget.terminal?.serialNumber);
  late int? _typeId = widget.terminal?.type.id;

  TerminalOptions? _options;
  ApiClientException? _failure;
  bool _busy = false;
  final _errors = <String, String>{};

  bool get _editing => widget.terminal != null;
  bool get _isVehicle => _options?.vehicleTypeIds.contains(_typeId) ?? false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _name.dispose();
    _serial.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _failure = null);
    try {
      final options = await widget.api.options();
      if (!mounted) return;
      setState(() {
        _options = options;
        _typeId ??= options.types.firstOrNull?.id;
      });
    } on ApiClientException catch (e) {
      if (mounted) setState(() => _failure = e);
    }
  }

  /// Fills what the form can check itself; the server checks everything.
  bool _check() {
    _errors.clear();
    if (_name.text.trim().isEmpty) _errors[TerminalRequest.fieldName] = AdminTextKeys.terminalErrorName;
    if (_serial.text.trim().isEmpty) _errors[TerminalRequest.fieldSerialNumber] = AdminTextKeys.terminalErrorSerial;
    return _errors.isEmpty;
  }

  Future<void> _save() async {
    final valid = _check();
    setState(() {});
    if (!valid) return;
    setState(() {
      _busy = true;
      _failure = null;
    });
    final request = TerminalRequest(name: _name.text, typeId: _typeId!, serialNumber: _serial.text);
    try {
      final current = widget.terminal;
      final saved = current == null ? await widget.api.create(request) : await widget.api.update(current.id, request);
      if (mounted) Navigator.of(context).pop(saved);
    } on ApiClientException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        // A serial number in use belongs under its field.
        if (e.error?.code == ApiErrorCode.duplicateSerialNumber) {
          _errors[TerminalRequest.fieldSerialNumber] = AdminTextKeys.terminalSerialTaken;
        } else {
          _failure = e;
        }
      });
    }
  }

  String? _error(String field) {
    final key = _errors[field];
    return key == null ? null : context.t(key);
  }

  Widget _failureNote(ApiClientException failure) {
    final keys = failureTextKeysFor(failure);
    return JitanInlineError(title: context.t(keys.title), message: context.t(keys.message));
  }

  /// A field with a quiet line under it (Figma `1507:126`).
  Widget _withNote(Widget field, String note) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    spacing: 6,
    children: [
      field,
      Text(note, style: JitanTextStyles.stateMessage.copyWith(fontSize: 12)),
    ],
  );

  Widget _form(TerminalOptions options) {
    final name = JitanTextField(
      label: context.t(AdminTextKeys.terminalName),
      controller: _name,
      maxLength: TerminalRequest.maxNameLength,
      errorText: _error(TerminalRequest.fieldName),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 16,
      children: [
        _TypeSwitch(types: options.types, selected: _typeId, onChanged: (id) => setState(() => _typeId = id)),
        if (_isVehicle) _withNote(name, context.t(AdminTextKeys.terminalVehicleNameHint)) else name,
        _withNote(
          JitanTextField(
            label: context.t(AdminTextKeys.terminalSerial),
            controller: _serial,
            maxLength: TerminalRequest.maxSerialNumberLength,
            errorText: _error(TerminalRequest.fieldSerialNumber),
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _busy ? null : _save(),
          ),
          context.t(AdminTextKeys.terminalSerialHint),
        ),
        if (_failure case final failure?) _failureNote(failure),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final options = _options;
    return JitanModal(
      width: 480,
      title: context.t(_editing ? AdminTextKeys.terminalEditTitle : AdminTextKeys.terminalAddTitle),
      onClose: () => Navigator.of(context).pop(),
      body: options != null
          ? _form(options)
          : _failure != null
          ? _failureNote(_failure!)
          : JitanLoadingState(label: context.t(AdminTextKeys.terminalsLoading)),
      actions: [
        JitanSecondaryButton(label: context.t(CommonTextKeys.cancel), onPressed: () => Navigator.of(context).pop()),
        JitanPrimaryButton(
          label: context.t(_editing ? AdminTextKeys.terminalSave : AdminTextKeys.terminalContinue),
          busy: _busy,
          onPressed: options == null || _busy ? null : _save,
        ),
      ],
    );
  }
}

/// Office or Vehicle: the types come from the database.
class _TypeSwitch extends StatelessWidget {
  const _TypeSwitch({required this.types, required this.selected, required this.onChanged});

  final List<TerminalTypeChoice> types;
  final int? selected;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(3),
    decoration: BoxDecoration(color: JitanColors.inputFill, borderRadius: BorderRadius.circular(12)),
    child: Row(
      spacing: 3,
      children: [
        for (final type in types)
          Expanded(
            child: Semantics(
              button: true,
              selected: type.id == selected,
              child: InkWell(
                borderRadius: BorderRadius.circular(9),
                onTap: () => onChanged(type.id),
                child: Container(
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: type.id == selected ? JitanColors.surface : null,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Text(
                    type.name,
                    style: type.id == selected
                        ? JitanTextStyles.tableCellStrong
                        : JitanTextStyles.tableCell.copyWith(color: JitanColors.inkMuted),
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}
