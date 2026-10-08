import 'json_reading.dart';

/// One choice on a "Manage employee assignments" tab (a company, group,
/// language or credential group) and whether the employee already has it.
class AssignmentOption {
  /// [isAssignable] defaults to "active and not yet assigned"; the server
  /// narrows it where a business rule forbids more (no access beyond the
  /// actor's own). [isRemovable] is set by the server where removal exists
  /// (companies and groups, soft delete).
  const AssignmentOption({
    required this.id,
    required this.name,
    required this.isActive,
    required this.isAssigned,
    bool? isAssignable,
    this.isRemovable = false,
    this.code,
  }) : isAssignable = isAssignable ?? (isActive && !isAssigned);

  factory AssignmentOption.fromJson(Map<String, Object?> json) => AssignmentOption(
        id: json.readInt('id'),
        name: json.readString('name'),
        isActive: json.readBool('isActive'),
        isAssigned: json.readBool('isAssigned'),
        isAssignable: json.readBool('isAssignable'),
        isRemovable: json.readBool('isRemovable'),
        code: json.readOptionalString('code'),
      );

  final int id;
  final String name;

  /// Only active options can be newly assigned. An inactive one is listed
  /// only when the employee already has it.
  final bool isActive;
  final bool isAssigned;

  /// Whether the actor may assign it now. Decided by the server; clients
  /// only display it.
  final bool isAssignable;

  /// Whether HR/Admin may remove this current assignment here (soft delete).
  final bool isRemovable;

  /// A language's `tblLanguage.languageCode`; `null` for other kinds.
  final String? code;

  AssignmentOption copyWith({bool? isAssignable, bool? isRemovable}) => AssignmentOption(
        id: id,
        name: name,
        isActive: isActive,
        isAssigned: isAssigned,
        isAssignable: isAssignable ?? this.isAssignable,
        isRemovable: isRemovable ?? this.isRemovable,
        code: code,
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'isActive': isActive,
        'isAssigned': isAssigned,
        'isAssignable': isAssignable,
        'isRemovable': isRemovable,
        if (code != null) 'code': code,
      };
}

/// Response of the assignment endpoints: every option, assigned or not.
class AssignmentOptions {
  const AssignmentOptions({required this.options});

  factory AssignmentOptions.fromJson(Map<String, Object?> json) =>
      AssignmentOptions(options: [for (final o in json.readObjectList('options')) AssignmentOption.fromJson(o)]);

  final List<AssignmentOption> options;

  Map<String, Object?> toJson() => {'options': [for (final o in options) o.toJson()]};
}

/// Body of `POST …/assignments/<kind>`: options to **add**. Assignments are
/// never removed through Jitan until IT confirms how junction rows may be
/// deleted.
class AddAssignmentsRequest {
  const AddAssignmentsRequest({required this.ids});

  factory AddAssignmentsRequest.fromJson(Map<String, Object?> json) =>
      AddAssignmentsRequest(ids: json.readIntList('ids'));

  final List<int> ids;

  static const fieldIds = 'ids';

  Map<String, Object?> toJson() => {'ids': ids};
}

/// Body of `PUT …/assignments/language`: the employee's one preferred
/// language (`tblLanguage.languageID`), replacing the current one.
class SetLanguageRequest {
  const SetLanguageRequest({required this.languageId});

  factory SetLanguageRequest.fromJson(Map<String, Object?> json) =>
      SetLanguageRequest(languageId: json.readInt(fieldLanguageId));

  final int languageId;

  static const fieldLanguageId = 'languageId';

  Map<String, Object?> toJson() => {fieldLanguageId: languageId};
}

/// Body of `PUT /me/language`: the signed-in user's own preferred language,
/// by `tblLanguage.languageCode` (as `GET /me/language` returns it).
class SetUserLanguageRequest {
  const SetUserLanguageRequest({required this.languageCode});

  factory SetUserLanguageRequest.fromJson(Map<String, Object?> json) =>
      SetUserLanguageRequest(languageCode: json.readString(fieldLanguageCode));

  final String languageCode;

  static const fieldLanguageCode = 'languageCode';

  Map<String, Object?> toJson() => {fieldLanguageCode: languageCode};
}
