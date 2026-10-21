import 'json_reading.dart';

/// One employee read from an import file (Import employees, Figma
/// `1419:149`): the values of the columns of `CreateEmployeeRequest` that a
/// file can hold, as text. Groups are given by name.
class EmployeeImportRow {
  const EmployeeImportRow({
    required this.row,
    required this.firstName,
    required this.lastName,
    required this.code,
    this.phone,
    this.email,
    this.groups = const [],
  });

  factory EmployeeImportRow.fromJson(Map<String, Object?> json) => EmployeeImportRow(
        row: json.readInt(fieldRow),
        firstName: json.readString(fieldFirstName),
        lastName: json.readString(fieldLastName),
        code: json.readString(fieldCode),
        phone: json.readOptionalString(fieldPhone),
        email: json.readOptionalString(fieldEmail),
        groups: json[fieldGroups] == null ? const [] : json.readStringList(fieldGroups),
      );

  /// The row's number in the file (the column names are row 1), shown to HR.
  final int row;
  final String firstName;
  final String lastName;
  final String code;
  final String? phone;
  final String? email;

  /// Names of existing groups (`tblGroup.groupName`).
  final List<String> groups;

  static const fieldRow = 'row';
  static const fieldFirstName = 'firstName';
  static const fieldLastName = 'lastName';
  static const fieldCode = 'code';
  static const fieldPhone = 'phone';
  static const fieldEmail = 'email';
  static const fieldGroups = 'groups';

  Map<String, Object?> toJson() => {
        fieldRow: row,
        fieldFirstName: firstName,
        fieldLastName: lastName,
        fieldCode: code,
        fieldPhone: phone,
        fieldEmail: email,
        if (groups.isNotEmpty) fieldGroups: groups,
      };
}

/// Body of `POST /companies/{id}/employees/import/check` and
/// `…/employees/import`: the rows of one file, at most [maxRows].
class EmployeeImportRequest {
  const EmployeeImportRequest({required this.rows});

  factory EmployeeImportRequest.fromJson(Map<String, Object?> json) =>
      EmployeeImportRequest(rows: json.readObjectList(fieldRows).map(EmployeeImportRow.fromJson).toList());

  final List<EmployeeImportRow> rows;

  /// Most employees one file may hold ("up to 500 employees", Figma
  /// `1419:2`).
  static const maxRows = 500;

  static const fieldRows = 'rows';

  Map<String, Object?> toJson() => {fieldRows: [for (final row in rows) row.toJson()]};
}

/// Why a row can't be imported (the Status column, Figma `1419:149`).
enum EmployeeImportProblemKind {
  firstNameMissing('first_name_missing'),
  lastNameMissing('last_name_missing'),
  codeMissing('code_missing'),

  /// Another employee already has the code ([EmployeeImportProblem.detail]).
  codeUsed('code_used'),

  /// An earlier row of the file has the same code (detail: that row).
  codeRepeated('code_repeated'),

  /// A value is longer than the database stores (detail: the field name).
  tooLong('too_long'),
  emailInvalid('email_invalid'),

  /// No active group has this name (detail: the name).
  groupUnknown('group_unknown'),

  /// Several active groups have this name (detail: the name).
  groupAmbiguous('group_ambiguous');

  const EmployeeImportProblemKind(this.wireName);

  final String wireName;

  static EmployeeImportProblemKind fromWire(String value) => values.firstWhere(
        (kind) => kind.wireName == value,
        orElse: () => throw FormatException('Unknown import problem "$value".'),
      );
}

/// The problem of one row; a row has at most one (the first found).
class EmployeeImportProblem {
  const EmployeeImportProblem({required this.row, required this.kind, this.detail});

  factory EmployeeImportProblem.fromJson(Map<String, Object?> json) => EmployeeImportProblem(
        row: json.readInt('row'),
        kind: EmployeeImportProblemKind.fromWire(json.readString('kind')),
        detail: json.readOptionalString('detail'),
      );

  /// [EmployeeImportRow.row].
  final int row;
  final EmployeeImportProblemKind kind;
  final String? detail;

  Map<String, Object?> toJson() => {'row': row, 'kind': kind.wireName, 'detail': detail};
}

/// Response of `…/employees/import/check`: the rows that can't be imported.
/// Every other row is ready.
class EmployeeImportCheck {
  const EmployeeImportCheck({required this.problems});

  factory EmployeeImportCheck.fromJson(Map<String, Object?> json) =>
      EmployeeImportCheck(problems: json.readObjectList('problems').map(EmployeeImportProblem.fromJson).toList());

  final List<EmployeeImportProblem> problems;

  Map<String, Object?> toJson() => {'problems': [for (final p in problems) p.toJson()]};
}

/// Response of `…/employees/import`: how many employees were added, and the
/// rows skipped because of a problem.
class EmployeeImportResult {
  const EmployeeImportResult({required this.added, required this.skipped});

  factory EmployeeImportResult.fromJson(Map<String, Object?> json) => EmployeeImportResult(
        added: json.readInt('added'),
        skipped: json.readObjectList('skipped').map(EmployeeImportProblem.fromJson).toList(),
      );

  final int added;
  final List<EmployeeImportProblem> skipped;

  Map<String, Object?> toJson() => {'added': added, 'skipped': [for (final p in skipped) p.toJson()]};
}
