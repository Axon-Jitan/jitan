import 'package:jitan_models/jitan_models.dart';

import '../companies/company_repository.dart';
import '../database/database_exception.dart';
import '../database/sql_executor.dart';
import '../groups/group_repository.dart';
import '../http/api_exception.dart';
import 'employee_repository.dart';
import 'employee_service.dart';

/// Import employees (Figma `1419:2` … `1419:404`): many employees of one
/// company at once, from the rows of an Excel or CSV file the HR/Admin web
/// has read.
///
/// Every row is checked as Add employee checks one employee; a row with a
/// problem is skipped, never half-imported. The ready rows are created in
/// one transaction, each exactly as Add employee creates one (audited the
/// same way), so the import adds all of them or none.
class EmployeeImportService {
  EmployeeImportService({
    required this._employees,
    required this._creator,
    required this._companies,
    required this._groups,
    required this._transactions,
  });

  final EmployeeRepository _employees;
  final EmployeeService _creator;
  final CompanyRepository _companies;
  final GroupRepository _groups;
  final TransactionRunner _transactions;

  /// The rows of [request] that can't be imported into [companyId], and
  /// why. 404 when the company does not exist; 400 for no rows, too many
  /// rows or a row number used twice.
  Future<EmployeeImportCheck> check(int companyId, EmployeeImportRequest request) async {
    await _requireCompany(companyId);
    _requireRows(request);
    final groups = await _groupIdsByName();
    final rows = _checked(request.rows, groups, await _employees.existingCodes(_codes(request)));
    return EmployeeImportCheck(problems: [for (final row in rows) ?row.problem]);
  }

  /// Adds the ready rows of [request] to [companyId] on behalf of
  /// [actorUserId] and reports the skipped ones. The rows are checked again
  /// here: the server never trusts an earlier check.
  ///
  /// 409 `duplicate_employee_code` (nothing added) when another request
  /// takes a code while this one runs.
  Future<EmployeeImportResult> import(int actorUserId, int companyId, EmployeeImportRequest request) async {
    await _requireCompany(companyId);
    _requireRows(request);
    final groups = await _groupIdsByName();
    try {
      return await _transactions.transaction((tx) async {
        final rows = _checked(request.rows, groups, await _employees.existingCodes(_codes(request), executor: tx));
        var added = 0;
        for (final row in rows) {
          final ready = row.ready;
          if (ready == null) continue;
          await _creator.createIn(
            tx,
            actorUserId,
            companyId,
            firstName: ready.firstName,
            lastName: ready.lastName,
            code: ready.code,
            phone: ready.phone,
            email: ready.email,
            groupIds: ready.groupIds,
          );
          added++;
        }
        return EmployeeImportResult(added: added, skipped: [for (final row in rows) ?row.problem]);
      });
    } on DatabaseQueryException catch (e) {
      if (e.isDuplicateKey) {
        throw const ApiException(
          409,
          ApiErrorCode.duplicateEmployeeCode,
          'An employee code in the file was taken while importing. Nothing was added; check the file again.',
        );
      }
      if (e.isValueTooLong) throw const ApiException.badRequest('A value is longer than allowed.');
      rethrow;
    }
  }

  Future<void> _requireCompany(int companyId) async {
    if (!await _companies.exists(companyId)) {
      throw ApiException.notFound('Company $companyId does not exist.');
    }
  }

  static void _requireRows(EmployeeImportRequest request) {
    final rows = request.rows;
    if (rows.isEmpty) {
      throw const ApiException.validation(EmployeeImportRequest.fieldRows, 'The file has no employees.');
    }
    if (rows.length > EmployeeImportRequest.maxRows) {
      throw const ApiException.validation(
        EmployeeImportRequest.fieldRows,
        'A file can hold at most ${EmployeeImportRequest.maxRows} employees.',
      );
    }
    if ({for (final row in rows) row.row}.length != rows.length) {
      throw const ApiException.validation(EmployeeImportRequest.fieldRows, 'Each row number may appear only once.');
    }
  }

  static List<String> _codes(EmployeeImportRequest request) => {
        for (final row in request.rows)
          if (row.code.trim().isNotEmpty) row.code.trim(),
      }.toList();

  /// Active groups by lower-case name; a name shared by several groups maps
  /// to all of them, so it is reported instead of one being picked.
  Future<Map<String, List<int>>> _groupIdsByName() async {
    final byName = <String, List<int>>{};
    for (final group in await _groups.listActive()) {
      byName.putIfAbsent(_key(group.name), () => []).add(group.id);
    }
    return byName;
  }

  /// Each row with its problem, or its checked values. Codes compare
  /// without regard to case, as MySQL does.
  static List<_CheckedRow> _checked(List<EmployeeImportRow> rows, Map<String, List<int>> groups, List<String> takenCodes) {
    final taken = {for (final code in takenCodes) _key(code)};
    final firstRowOfCode = <String, int>{};
    return [for (final row in rows) _check(row, groups, taken, firstRowOfCode)];
  }

  static _CheckedRow _check(
    EmployeeImportRow row,
    Map<String, List<int>> groups,
    Set<String> taken,
    Map<String, int> firstRowOfCode,
  ) {
    _CheckedRow problem(EmployeeImportProblemKind kind, [String? detail]) =>
        _CheckedRow(problem: EmployeeImportProblem(row: row.row, kind: kind, detail: detail));

    final firstName = row.firstName.trim();
    final lastName = row.lastName.trim();
    final code = row.code.trim();
    final phone = _blankToNull(row.phone);
    final email = _blankToNull(row.email);
    if (firstName.isEmpty) return problem(EmployeeImportProblemKind.firstNameMissing);
    if (lastName.isEmpty) return problem(EmployeeImportProblemKind.lastNameMissing);
    if (code.isEmpty) return problem(EmployeeImportProblemKind.codeMissing);

    // A repeated code is reported on every later row that has it.
    final earlier = firstRowOfCode.putIfAbsent(_key(code), () => row.row);
    if (earlier != row.row) return problem(EmployeeImportProblemKind.codeRepeated, '$earlier');
    if (taken.contains(_key(code))) return problem(EmployeeImportProblemKind.codeUsed, code);

    for (final (value, field, max) in [
      (firstName, EmployeeImportRow.fieldFirstName, CreateEmployeeRequest.maxFirstNameLength),
      (lastName, EmployeeImportRow.fieldLastName, CreateEmployeeRequest.maxLastNameLength),
      (code, EmployeeImportRow.fieldCode, CreateEmployeeRequest.maxCodeLength),
      (phone ?? '', EmployeeImportRow.fieldPhone, CreateEmployeeRequest.maxPhoneLength),
      (email ?? '', EmployeeImportRow.fieldEmail, CreateEmployeeRequest.maxEmailLength),
    ]) {
      // Characters as MySQL counts them.
      if (value.runes.length > max) return problem(EmployeeImportProblemKind.tooLong, field);
    }
    if (email != null && !EmployeeService.emailShape.hasMatch(email)) {
      return problem(EmployeeImportProblemKind.emailInvalid);
    }

    final groupIds = <int>{};
    for (final name in row.groups.map((g) => g.trim()).where((g) => g.isNotEmpty)) {
      switch (groups[_key(name)]) {
        case null:
          return problem(EmployeeImportProblemKind.groupUnknown, name);
        case [final id]:
          groupIds.add(id);
        case _:
          return problem(EmployeeImportProblemKind.groupAmbiguous, name);
      }
    }
    return _CheckedRow(
      ready: _ReadyRow(
        firstName: firstName,
        lastName: lastName,
        code: code,
        phone: phone,
        email: email,
        groupIds: groupIds.toList()..sort(),
      ),
    );
  }

  static String? _blankToNull(String? value) {
    final trimmed = value?.trim() ?? '';
    return trimmed.isEmpty ? null : trimmed;
  }

  static String _key(String value) => value.trim().toLowerCase();
}

/// A row with either its problem or its checked values.
class _CheckedRow {
  const _CheckedRow({this.problem, this.ready});

  final EmployeeImportProblem? problem;
  final _ReadyRow? ready;
}

/// A row's values, trimmed and checked, groups resolved to ids.
class _ReadyRow {
  const _ReadyRow({
    required this.firstName,
    required this.lastName,
    required this.code,
    required this.phone,
    required this.email,
    required this.groupIds,
  });

  final String firstName;
  final String lastName;
  final String code;
  final String? phone;
  final String? email;
  final List<int> groupIds;
}
