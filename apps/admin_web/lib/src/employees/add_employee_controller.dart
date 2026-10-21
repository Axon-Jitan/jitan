import 'package:flutter/foundation.dart';
import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:jitan_models/jitan_models.dart';

import '../l10n/admin_text_keys.dart';

/// The steps of Add employee, in order.
enum AddEmployeeStep { information, assignments, activation }

/// Step 1's values, as typed.
typedef NewEmployeeInput = ({String firstName, String lastName, String code, String phone, String email});

/// Step 2's choices, loaded from the server.
sealed class AssignmentOptions {
  const AssignmentOptions();
}

class AssignmentOptionsLoading extends AssignmentOptions {
  const AssignmentOptionsLoading();
}

class AssignmentOptionsLoaded extends AssignmentOptions {
  const AssignmentOptionsLoaded({required this.companies, required this.groups, required this.schedules});

  final List<CompanySummary> companies;
  final List<GroupSummary> groups;

  /// Each group's schedule, by group ID (only groups that have hours).
  final Map<int, GroupSchedule> schedules;
}

class AssignmentOptionsFailed extends AssignmentOptions {
  const AssignmentOptionsFailed(this.failure);

  final ApiClientException failure;
}

/// Add employee (Figma `153:970` → `985:2` → `1233:2`): the employee's
/// details, their companies, groups and work schedule, then the onboarding
/// QR. The employee is created when HR leaves step 2 (`POST
/// /companies/{id}/employees`, one transaction); step 3 shows a temporary
/// onboarding QR for them.
///
/// Client checks are only for quick feedback; the server validates again
/// and is the authority (ENGINEERING_RULES §19). Server errors land on the
/// field, and the step, they concern.
class AddEmployeeController extends ChangeNotifier {
  AddEmployeeController({
    required this._employeesApi,
    required this._groupsApi,
    required this._companiesApi,
    required this._schedulesApi,
  });

  final EmployeesApi _employeesApi;
  final GroupsApi _groupsApi;
  final CompaniesApi _companiesApi;
  final SchedulesApi _schedulesApi;

  /// The company the employee was created through (the first chosen; they
  /// are added to every chosen company alike).
  int? _createdIn;

  static final _emailShape = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  AddEmployeeStep _step = AddEmployeeStep.information;
  AddEmployeeStep get step => _step;

  NewEmployeeInput? _input;

  AssignmentOptions _options = const AssignmentOptionsLoading();
  AssignmentOptions get options => _options;
  bool _optionsRequested = false;

  /// The employee's companies: HR's choice in step 2, starting empty. The
  /// Employees "Current company" only filters the list and never chooses
  /// for Add employee (product owner, 2026-10-21).
  List<int> _companyIds = const [];
  List<int> get companyIds => _companyIds;

  List<int> _groupIds = const [];
  List<int> get groupIds => _groupIds;

  int? _scheduleGroupId;

  bool _submitting = false;
  bool get submitting => _submitting;

  /// Field name (`CreateEmployeeRequest.field…`) → translation key.
  Map<String, String> _fieldErrors = const {};
  Map<String, String> get fieldErrors => _fieldErrors;

  /// A failure not tied to one field (network, server, …).
  ApiClientException? _formFailure;
  ApiClientException? get formFailure => _formFailure;

  EmployeeSummary? _created;
  EmployeeSummary? get created => _created;

  TemporaryQrResponse? _qr;
  TemporaryQrResponse? get qr => _qr;
  ApiClientException? _qrFailure;
  ApiClientException? get qrFailure => _qrFailure;

  bool _disposed = false;

  /// The groups chosen in step 2 that have work hours: the "Work schedule"
  /// choices (product owner, 2026-10-21: only the employee's own groups).
  List<GroupSchedule> get scheduleChoices => switch (_options) {
    AssignmentOptionsLoaded(:final schedules) => [for (final id in _groupIds) ?schedules[id]],
    _ => const [],
  };

  /// The chosen work schedule's group: HR's choice, or the only choice.
  int? get scheduleGroupId {
    final choices = scheduleChoices;
    if (choices.any((s) => s.group.id == _scheduleGroupId)) return _scheduleGroupId;
    return choices.length == 1 ? choices.single.group.id : null;
  }

  /// Step 1: checks the details, then shows step 2.
  void next(NewEmployeeInput input) {
    if (_step != AddEmployeeStep.information) return;
    final invalid = {
      CreateEmployeeRequest.fieldFirstName: ?_check(input.firstName, CreateEmployeeRequest.maxFirstNameLength),
      CreateEmployeeRequest.fieldLastName: ?_check(input.lastName, CreateEmployeeRequest.maxLastNameLength),
      CreateEmployeeRequest.fieldCode: ?_check(input.code, CreateEmployeeRequest.maxCodeLength),
      CreateEmployeeRequest.fieldPhone: ?_checkPhone(input.phone),
      CreateEmployeeRequest.fieldEmail: ?_checkEmail(input.email),
    };
    _input = input;
    _fieldErrors = invalid;
    _formFailure = null;
    if (invalid.isEmpty) {
      _step = AddEmployeeStep.assignments;
      if (!_optionsRequested) loadOptions();
    }
    _notify();
  }

  void back() {
    if (_submitting || _step != AddEmployeeStep.assignments) return;
    _step = AddEmployeeStep.information;
    _formFailure = null;
    _notify();
  }

  /// Companies, groups and the groups' schedules for step 2.
  Future<void> loadOptions() async {
    _optionsRequested = true;
    _options = const AssignmentOptionsLoading();
    _notify();
    try {
      final companies = await _companiesApi.listCompanies();
      final groups = await _groupsApi.listGroups();
      final schedules = await _schedulesApi.groupSchedules();
      _options = AssignmentOptionsLoaded(
        companies: companies,
        groups: groups,
        schedules: {
          for (final s in schedules)
            if (s.status == GroupScheduleStatus.configured && s.variants.length == 1) s.group.id: s,
        },
      );
    } on ApiClientException catch (failure) {
      _options = AssignmentOptionsFailed(failure);
    }
    _notify();
  }

  void setCompanies(List<int> ids) => _change(() => _companyIds = List.unmodifiable(ids));

  void setGroups(List<int> ids) => _change(() => _groupIds = List.unmodifiable(ids));

  void setScheduleGroup(int? groupId) => _change(() => _scheduleGroupId = groupId);

  /// Step 2: creates the employee, then asks for their onboarding QR.
  Future<void> create() async {
    final input = _input;
    if (input == null || _submitting || _step != AddEmployeeStep.assignments) return;
    if (_companyIds.isEmpty) {
      _fieldErrors = {CreateEmployeeRequest.fieldCompanyIds: AdminTextKeys.employeeFieldErrorRequired};
      _notify();
      return;
    }
    final [through, ...] = _companyIds;
    _submitting = true;
    _fieldErrors = const {};
    _formFailure = null;
    _notify();
    try {
      _created = await _employeesApi.create(
        through,
        CreateEmployeeRequest(
          firstName: input.firstName.trim(),
          lastName: input.lastName.trim(),
          code: input.code.trim(),
          phone: _blankToNull(input.phone) == null ? null : PhoneNumbers.check(input.phone).formatted,
          email: _blankToNull(input.email),
          companyIds: _companyIds,
          groupIds: _groupIds,
          scheduleGroupId: scheduleGroupId,
        ),
      );
      _createdIn = through;
      _step = AddEmployeeStep.activation;
    } on ApiClientException catch (failure) {
      _refused(input, failure);
    } finally {
      _submitting = false;
      _notify();
    }
    if (_created != null) await requestQr();
  }

  /// Step 3: the temporary onboarding QR of the new employee.
  Future<void> requestQr() async {
    final created = _created;
    final company = _createdIn;
    if (created == null || company == null) return;
    _qr = null;
    _qrFailure = null;
    _notify();
    try {
      _qr = await _employeesApi.temporaryQr(company, created.id, TemporaryQrPurpose.onboarding);
    } on ApiClientException catch (failure) {
      _qrFailure = failure;
    }
    _notify();
  }

  /// Takes HR back to the step a refusal is about.
  void _refused(NewEmployeeInput input, ApiClientException failure) {
    final error = failure.error;
    final field = error?.field;
    if (error?.code == ApiErrorCode.duplicateEmployeeCode) {
      _step = AddEmployeeStep.information;
      _fieldErrors = {CreateEmployeeRequest.fieldCode: AdminTextKeys.employeeFieldErrorDuplicateCode};
    } else if (error?.code == ApiErrorCode.validationFailed && field != null) {
      final onStep1 = const {
        CreateEmployeeRequest.fieldFirstName,
        CreateEmployeeRequest.fieldLastName,
        CreateEmployeeRequest.fieldCode,
        CreateEmployeeRequest.fieldPhone,
        CreateEmployeeRequest.fieldEmail,
      }.contains(field);
      if (onStep1) _step = AddEmployeeStep.information;
      _fieldErrors = {
        field: switch (field) {
          CreateEmployeeRequest.fieldEmail => AdminTextKeys.employeeFieldErrorEmail,
          CreateEmployeeRequest.fieldPhone => AdminTextKeys.employeeFieldErrorPhoneInvalid,
          CreateEmployeeRequest.fieldCompanyIds ||
          CreateEmployeeRequest.fieldGroupIds ||
          CreateEmployeeRequest.fieldScheduleGroupId => AdminTextKeys.employeeFieldErrorUnavailable,
          _ when onStep1 && _isBlank(input, field) => AdminTextKeys.employeeFieldErrorRequired,
          _ => AdminTextKeys.employeeFieldErrorTooLong,
        },
      };
    } else {
      _formFailure = failure;
    }
  }

  static bool _isBlank(NewEmployeeInput input, String field) => switch (field) {
    CreateEmployeeRequest.fieldFirstName => input.firstName.trim().isEmpty,
    CreateEmployeeRequest.fieldLastName => input.lastName.trim().isEmpty,
    CreateEmployeeRequest.fieldCode => input.code.trim().isEmpty,
    _ => false,
  };

  static String? _blankToNull(String value) => value.trim().isEmpty ? null : value.trim();

  /// A translation key when [value] is blank (if [required]) or longer than
  /// [maxLength] characters as MySQL counts them.
  static String? _check(String value, int maxLength, {bool required = true}) {
    final trimmed = value.trim();
    if (required && trimmed.isEmpty) return AdminTextKeys.employeeFieldErrorRequired;
    if (trimmed.runes.length > maxLength) return AdminTextKeys.employeeFieldErrorTooLong;
    return null;
  }

  /// The phone rule shared with the server ([PhoneNumbers]): optional, but
  /// when given, an international number with `+` and its country code.
  static String? _checkPhone(String value) {
    if (value.trim().isEmpty) return null;
    return switch (PhoneNumbers.check(value).problem) {
      null => null,
      PhoneNumberProblem.notANumber => AdminTextKeys.employeeFieldErrorPhoneLetters,
      PhoneNumberProblem.missingCountryCode => AdminTextKeys.employeeFieldErrorPhoneCountryCode,
      PhoneNumberProblem.invalid => AdminTextKeys.employeeFieldErrorPhoneInvalid,
    };
  }

  static String? _checkEmail(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    if (trimmed.runes.length > CreateEmployeeRequest.maxEmailLength) return AdminTextKeys.employeeFieldErrorTooLong;
    return _emailShape.hasMatch(trimmed) ? null : AdminTextKeys.employeeFieldErrorEmail;
  }

  void _change(VoidCallback update) {
    update();
    _fieldErrors = const {};
    _formFailure = null;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
