import 'package:flutter/material.dart';
import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:jitan_core/jitan_core.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../common/api_failure_text.dart';
import '../l10n/admin_text_keys.dart';

/// Adds a terminal, or changes [terminal]. Returns what the server saved.
Future<Terminal?> showTerminalDialog(
  BuildContext context, {
  required TerminalsApi api,
  required CompaniesApi companiesApi,
  required LocationsApi locationsApi,
  Terminal? terminal,
}) => showJitanModal<Terminal>(
  context,
  barrierDismissible: false,
  builder: (_) => _TerminalDialog(api: api, companiesApi: companiesApi, locationsApi: locationsApi, terminal: terminal),
);

/// Figma `HR / Terminals V2 — Add terminal` (`1488:270`), vehicle (`1494:119`)
/// and Edit (`1494:272`). An office has a location, a vehicle a number plate.
class _TerminalDialog extends StatefulWidget {
  const _TerminalDialog({required this.api, required this.companiesApi, required this.locationsApi, this.terminal});

  final TerminalsApi api;
  final CompaniesApi companiesApi;
  final LocationsApi locationsApi;
  final Terminal? terminal;

  @override
  State<_TerminalDialog> createState() => _TerminalDialogState();
}

class _TerminalDialogState extends State<_TerminalDialog> {
  late final _name = TextEditingController(text: widget.terminal?.name);
  late final _plate = TextEditingController(text: widget.terminal?.plateNumber);
  late int? _typeId = widget.terminal?.type.id;
  late int? _companyId = widget.terminal?.companyId;
  late int? _addressId = widget.terminal?.addressId;

  TerminalOptions? _options;
  List<CompanySummary> _companies = const [];
  List<Location> _locations = const [];
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
    _plate.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _failure = null);
    try {
      final options = await widget.api.options();
      final companies = await widget.companiesApi.listCompanies();
      final locations = await widget.locationsApi.list();
      if (!mounted) return;
      setState(() {
        _options = options;
        _typeId ??= options.types.firstOrNull?.id;
        _companies = [
          for (final company in companies)
            if (company.isActive) company,
        ];
        _companyId ??= _companies.length == 1 ? _companies.single.id : null;
        _locations = [
          for (final location in locations)
            if (location.isActive) location,
        ];
      });
    } on ApiClientException catch (e) {
      if (mounted) setState(() => _failure = e);
    }
  }

  /// Fills what the form can check itself; the server checks everything.
  bool _check() {
    _errors.clear();
    if (_name.text.trim().isEmpty) _errors[TerminalRequest.fieldName] = AdminTextKeys.terminalErrorName;
    if (_companyId == null) _errors[TerminalRequest.fieldCompany] = AdminTextKeys.terminalErrorCompany;
    if (_isVehicle && _plate.text.trim().isEmpty) _errors[TerminalRequest.fieldPlate] = AdminTextKeys.terminalErrorPlate;
    if (!_isVehicle && _addressId == null) _errors[TerminalRequest.fieldAddress] = AdminTextKeys.terminalErrorLocation;
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
    final request = TerminalRequest(
      name: _name.text,
      typeId: _typeId!,
      companyId: _companyId!,
      addressId: _isVehicle ? null : _addressId,
      plateNumber: _isVehicle ? _plate.text : null,
    );
    try {
      final current = widget.terminal;
      final saved = current == null
          ? await widget.api.create(request)
          : await widget.api.update(current.companyId, current.id, request);
      if (mounted) Navigator.of(context).pop(saved);
    } on ApiClientException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _failure = e;
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

  Widget _form(TerminalOptions options) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    spacing: 16,
    children: [
      _TypeSwitch(types: options.types, selected: _typeId, onChanged: (id) => setState(() => _typeId = id)),
      JitanTextField(
        label: context.t(AdminTextKeys.terminalName),
        controller: _name,
        maxLength: TerminalRequest.maxNameLength,
        errorText: _error(TerminalRequest.fieldName),
      ),
      JitanSelectField<int>(
        label: context.t(AdminTextKeys.terminalCompany),
        value: _companyId,
        errorText: _error(TerminalRequest.fieldCompany),
        hintText: context.t(AdminTextKeys.projectChoose),
        options: [for (final c in _companies) JitanSelectOption(value: c.id, label: c.name)],
        onChanged: (id) => setState(() => _companyId = id),
      ),
      if (_isVehicle)
        JitanTextField(
          label: context.t(AdminTextKeys.terminalPlate),
          controller: _plate,
          maxLength: TerminalRequest.maxPlateLength,
          errorText: _error(TerminalRequest.fieldPlate),
        )
      else
        JitanSelectField<int>(
          label: context.t(AdminTextKeys.terminalLocation),
          value: _addressId,
          errorText: _error(TerminalRequest.fieldAddress),
          hintText: context.t(AdminTextKeys.projectChoose),
          options: [for (final l in _locations) JitanSelectOption(value: l.id, label: l.name)],
          onChanged: (id) => setState(() => _addressId = id),
        ),
      if (_failure case final failure?) _failureNote(failure),
    ],
  );

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
