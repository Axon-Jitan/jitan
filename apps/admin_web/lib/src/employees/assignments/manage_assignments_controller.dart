import 'package:flutter/foundation.dart';
import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:jitan_models/jitan_models.dart';

/// One tab's options as last loaded, plus what the user ticked since.
class AssignmentTab {
  AssignmentTab(this.kind);

  final AssignmentKind kind;

  /// `null` while loading.
  List<AssignmentOption>? options;
  ApiClientException? loadFailure;

  /// Options ticked to be added on Save.
  final pending = <int>{};

  /// One choice that replaces the current one (language), instead of
  /// several that are added.
  bool get isSingleChoice => kind == AssignmentKind.language;

  bool isSelected(AssignmentOption option) => isSingleChoice && pending.isNotEmpty
      ? pending.contains(option.id)
      : option.isAssigned || pending.contains(option.id);

  /// The server decides what may be assigned ([AssignmentOption.isAssignable]).
  /// Existing assignments are locked: removal waits for IT (junction rows).
  /// For a single choice, the current option can be picked to undo a change.
  bool canToggle(AssignmentOption option) => option.isAssignable || (isSingleChoice && option.isAssigned);
}

/// State of "Manage employee assignments" (Figma Admin/HR Employees 04–07)
/// for one employee in one company. Save adds what was ticked, tab by tab.
class ManageAssignmentsController extends ChangeNotifier {
  ManageAssignmentsController({required this._api, required this.companyId, required this.userId}) {
    for (final tab in tabs) {
      _load(tab);
    }
  }

  final EmployeeAssignmentsApi _api;
  final int companyId;
  final int userId;

  final tabs = [
    AssignmentTab(AssignmentKind.companies),
    AssignmentTab(AssignmentKind.groups),
    AssignmentTab(AssignmentKind.language),
    AssignmentTab(AssignmentKind.credentialGroups),
  ];

  bool _saving = false;
  bool get saving => _saving;

  ApiClientException? _saveFailure;
  ApiClientException? get saveFailure => _saveFailure;

  bool get hasChanges => tabs.any((t) => t.pending.isNotEmpty);

  Future<void> _load(AssignmentTab tab) async {
    tab
      ..options = null
      ..loadFailure = null;
    notifyListeners();
    try {
      tab.options = (await _api.options(companyId, userId, tab.kind)).options;
    } on ApiClientException catch (e) {
      tab.loadFailure = e;
    }
    notifyListeners();
  }

  Future<void> retry(AssignmentTab tab) => _load(tab);

  void toggle(AssignmentTab tab, AssignmentOption option) {
    if (_saving || !tab.canToggle(option)) return;
    if (tab.isSingleChoice) {
      tab.pending.clear();
      if (!option.isAssigned) tab.pending.add(option.id);
    } else if (!tab.pending.remove(option.id)) {
      tab.pending.add(option.id);
    }
    _saveFailure = null;
    notifyListeners();
  }

  bool _removing = false;
  bool get removing => _removing;

  /// Removes [option] from [tab] at once (after HR/Admin confirmed): a soft
  /// delete on the server. Returns the failure, or `null` once the server
  /// confirmed; the tab then shows the server's list.
  Future<ApiClientException?> remove(AssignmentTab tab, AssignmentOption option) async {
    if (_removing || _saving || !option.isRemovable) return null;
    _removing = true;
    notifyListeners();
    try {
      tab.options = (await _api.remove(companyId, userId, tab.kind, option.id)).options;
      tab.pending.remove(option.id);
      return null;
    } on ApiClientException catch (e) {
      return e;
    } finally {
      _removing = false;
      notifyListeners();
    }
  }

  /// Picker tabs (Access): [optionId] becomes the one option to add, or
  /// none when `null`.
  void choose(AssignmentTab tab, int? optionId) {
    if (_saving) return;
    final option = tab.options?.where((o) => o.id == optionId).firstOrNull;
    tab.pending.clear();
    if (option != null && tab.canToggle(option)) tab.pending.add(option.id);
    _saveFailure = null;
    notifyListeners();
  }

  /// Sends the ticked options; returns `true` when everything was saved.
  /// A failed tab keeps its ticks, so Save can be retried.
  Future<bool> save() async {
    if (_saving || !hasChanges) return !hasChanges;
    _saving = true;
    _saveFailure = null;
    notifyListeners();
    try {
      for (final tab in tabs.where((t) => t.pending.isNotEmpty)) {
        tab.options = (tab.isSingleChoice
                ? await _api.setLanguage(companyId, userId, tab.pending.single)
                : await _api.add(companyId, userId, tab.kind, tab.pending.toList()..sort()))
            .options;
        tab.pending.clear();
      }
      return true;
    } on ApiClientException catch (e) {
      _saveFailure = e;
      return false;
    } finally {
      _saving = false;
      notifyListeners();
    }
  }
}
