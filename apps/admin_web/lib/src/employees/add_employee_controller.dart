import 'package:flutter/foundation.dart';
import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:jitan_models/jitan_models.dart';

import '../l10n/admin_text_keys.dart';

/// The Add employee form's values.
typedef NewEmployeeInput = ({String firstName, String lastName, String code, int? groupId, String phone});

/// Loading state of the "Employee type" options.
sealed class GroupOptions {
  const GroupOptions();
}

class GroupOptionsLoading extends GroupOptions {
  const GroupOptionsLoading();
}

class GroupOptionsLoaded extends GroupOptions {
  const GroupOptionsLoaded(this.groups);

  final List<GroupSummary> groups;
}

/// Types could not be loaded. The employee can still be created without
/// one; the type is added later (EMP-05).
class GroupOptionsFailed extends GroupOptions {
  const GroupOptionsFailed();
}

/// State and submission of the Add employee form (EMP-02).
///
/// Client checks are only for quick feedback; the server validates again
/// and is the authority (ENGINEERING_RULES §19). Server errors are mapped
/// back onto the field they concern.
class AddEmployeeController extends ChangeNotifier {
  AddEmployeeController({required this._employeesApi, required this._groupsApi, required this.companyId});

  final EmployeesApi _employeesApi;
  final GroupsApi _groupsApi;
  final int companyId;

  GroupOptions _groups = const GroupOptionsLoading();
  GroupOptions get groups => _groups;

  bool _submitting = false;
  bool get submitting => _submitting;

  /// Field name (`CreateEmployeeRequest.field…`) → translation key.
  Map<String, String> _fieldErrors = const {};
  Map<String, String> get fieldErrors => _fieldErrors;

  /// A failure not tied to one field (network, server, …).
  ApiClientException? _formFailure;
  ApiClientException? get formFailure => _formFailure;

  bool _disposed = false;

  Future<void> loadGroups() async {
    _set(() => _groups = const GroupOptionsLoading());
    try {
      final groups = await _groupsApi.listGroups();
      _set(() => _groups = GroupOptionsLoaded(groups));
    } on ApiClientException {
      _set(() => _groups = const GroupOptionsFailed());
    }
  }

  /// Validates and creates the employee. Returns it once the server has
  /// confirmed; `null` when validation or the request failed (the errors are
  /// then in [fieldErrors] / [formFailure]).
  Future<EmployeeSummary?> submit(NewEmployeeInput input) async {
    if (_submitting) return null;

    final invalid = {
      CreateEmployeeRequest.fieldFirstName: ?_check(input.firstName, CreateEmployeeRequest.maxFirstNameLength),
      CreateEmployeeRequest.fieldLastName: ?_check(input.lastName, CreateEmployeeRequest.maxLastNameLength),
      CreateEmployeeRequest.fieldCode: ?_check(input.code, CreateEmployeeRequest.maxCodeLength),
      CreateEmployeeRequest.fieldPhone: ?_check(input.phone, CreateEmployeeRequest.maxPhoneLength, required: false),
    };
    _set(() {
      _fieldErrors = invalid;
      _formFailure = null;
    });
    if (invalid.isNotEmpty) return null;

    _set(() => _submitting = true);
    try {
      return await _employeesApi.create(
        companyId,
        CreateEmployeeRequest(
          firstName: input.firstName.trim(),
          lastName: input.lastName.trim(),
          code: input.code.trim(),
          groupIds: [?input.groupId],
          phone: input.phone.trim().isEmpty ? null : input.phone.trim(),
        ),
      );
    } on ApiClientException catch (failure) {
      final fieldError = _fieldErrorFor(failure, input);
      _set(() {
        if (fieldError != null) {
          _fieldErrors = {fieldError.$1: fieldError.$2};
        } else {
          _formFailure = failure;
        }
      });
      return null;
    } finally {
      _set(() => _submitting = false);
    }
  }

  /// The error key for one field, or `null` when it is fine. Lengths count
  /// characters as the server and MySQL do (code points).
  static String? _check(String value, int maxLength, {bool required = true}) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return required ? AdminTextKeys.employeeFieldErrorRequired : null;
    return trimmed.runes.length > maxLength ? AdminTextKeys.employeeFieldErrorTooLong : null;
  }

  /// (field, translation key) for a failure that concerns one field. The
  /// server names the field but not the reason: a value that was sent is
  /// too long, an empty one is missing.
  static (String, String)? _fieldErrorFor(ApiClientException failure, NewEmployeeInput input) {
    final error = failure.error;
    if (error == null) return null;
    if (error.code == ApiErrorCode.duplicateEmployeeCode) {
      return (CreateEmployeeRequest.fieldCode, AdminTextKeys.employeeFieldErrorDuplicateCode);
    }
    if (error.code == ApiErrorCode.validationFailed && error.field != null) {
      return (
        error.field!,
        switch (error.field) {
          CreateEmployeeRequest.fieldGroupIds => AdminTextKeys.employeeFieldErrorInvalidType,
          CreateEmployeeRequest.fieldFirstName when input.firstName.trim().isNotEmpty =>
            AdminTextKeys.employeeFieldErrorTooLong,
          CreateEmployeeRequest.fieldLastName when input.lastName.trim().isNotEmpty =>
            AdminTextKeys.employeeFieldErrorTooLong,
          CreateEmployeeRequest.fieldCode when input.code.trim().isNotEmpty => AdminTextKeys.employeeFieldErrorTooLong,
          CreateEmployeeRequest.fieldPhone when input.phone.trim().isNotEmpty => AdminTextKeys.employeeFieldErrorTooLong,
          _ => AdminTextKeys.employeeFieldErrorRequired,
        },
      );
    }
    return null;
  }

  void _set(VoidCallback change) {
    if (_disposed) return;
    change();
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
