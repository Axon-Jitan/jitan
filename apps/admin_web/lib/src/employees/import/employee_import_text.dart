import 'package:flutter/widgets.dart';
import 'package:jitan_core/jitan_core.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../../common/api_failure_text.dart';
import '../../l10n/admin_text_keys.dart';
import 'employee_import_controller.dart';
import 'employee_import_file.dart';

/// The words of the Import employees page that depend on data: column
/// names, row problems, file sizes and why a file can't be used.
abstract final class EmployeeImportText {
  static String columnKey(ImportColumn column) => switch (column) {
    ImportColumn.firstName => AdminTextKeys.employeeImportColumnFirstName,
    ImportColumn.lastName => AdminTextKeys.employeeImportColumnLastName,
    ImportColumn.code => AdminTextKeys.employeeImportColumnCode,
    ImportColumn.phone => AdminTextKeys.employeeImportColumnPhone,
    ImportColumn.email => AdminTextKeys.employeeImportColumnEmail,
    ImportColumn.groups => AdminTextKeys.employeeImportColumnGroups,
  };

  /// The names a file's column may have: its name in the current language
  /// and in built-in English (the template's language may differ from the
  /// reader's).
  static Map<ImportColumn, Set<String>> columnNames(BuildContext context) => {
    for (final column in ImportColumn.values)
      column: {context.t(columnKey(column)), ?builtInEnglish[columnKey(column)]},
  };

  /// The Status cell of a row with [problem].
  static String problem(BuildContext context, EmployeeImportProblem problem) {
    final detail = problem.detail ?? '';
    return switch (problem.kind) {
      EmployeeImportProblemKind.firstNameMissing => context.t(AdminTextKeys.employeeImportProblemFirstNameMissing),
      EmployeeImportProblemKind.lastNameMissing => context.t(AdminTextKeys.employeeImportProblemLastNameMissing),
      EmployeeImportProblemKind.codeMissing => context.t(AdminTextKeys.employeeImportProblemCodeMissing),
      EmployeeImportProblemKind.codeUsed => context.t(AdminTextKeys.employeeImportProblemCodeUsed, args: {'code': detail}),
      EmployeeImportProblemKind.codeRepeated =>
        context.t(AdminTextKeys.employeeImportProblemCodeRepeated, args: {'row': detail}),
      EmployeeImportProblemKind.tooLong => context.t(
        AdminTextKeys.employeeImportProblemTooLong,
        args: {'column': context.t(columnKey(_columnOfField(detail)))},
      ),
      EmployeeImportProblemKind.emailInvalid => context.t(AdminTextKeys.employeeImportProblemEmailInvalid),
      EmployeeImportProblemKind.phoneInvalid => context.t(
        detail == PhoneNumberProblem.missingCountryCode.name
            ? AdminTextKeys.employeeImportProblemPhoneCountryCode
            : AdminTextKeys.employeeImportProblemPhoneInvalid,
      ),
      EmployeeImportProblemKind.groupUnknown =>
        context.t(AdminTextKeys.employeeImportProblemGroupUnknown, args: {'group': detail}),
      EmployeeImportProblemKind.groupAmbiguous =>
        context.t(AdminTextKeys.employeeImportProblemGroupAmbiguous, args: {'group': detail}),
    };
  }

  static ImportColumn _columnOfField(String field) => switch (field) {
    EmployeeImportRow.fieldFirstName => ImportColumn.firstName,
    EmployeeImportRow.fieldLastName => ImportColumn.lastName,
    EmployeeImportRow.fieldPhone => ImportColumn.phone,
    EmployeeImportRow.fieldEmail => ImportColumn.email,
    _ => ImportColumn.code,
  };

  /// "18 KB", "1.2 MB".
  static String size(BuildContext context, int bytes) {
    const kb = 1024;
    if (bytes < kb * kb) {
      return context.t(AdminTextKeys.employeeImportFileKb, args: {'size': (bytes / kb).ceil().clamp(1, kb)});
    }
    return context.t(AdminTextKeys.employeeImportFileMb, args: {'size': (bytes / (kb * kb)).toStringAsFixed(1)});
  }

  /// The line under "This file can't be used".
  static String unusable(BuildContext context, ImportUnusable state) {
    final failure = state.failure;
    if (failure != null) return context.t(failureTextKeysFor(failure).message);
    final problem = state.problem!;
    return switch (problem.kind) {
      ImportFileProblemKind.notExcelOrCsv => context.t(AdminTextKeys.employeeImportUnusableType),
      ImportFileProblemKind.unreadable => context.t(AdminTextKeys.employeeImportUnusableUnreadable),
      ImportFileProblemKind.missingColumn => context.t(
        AdminTextKeys.employeeImportUnusableMissingColumn,
        args: {'column': context.t(columnKey(problem.column!))},
      ),
      ImportFileProblemKind.noEmployees => context.t(AdminTextKeys.employeeImportUnusableEmpty),
      ImportFileProblemKind.tooManyEmployees => context.t(
        AdminTextKeys.employeeImportUnusableTooMany,
        args: {'count': problem.count ?? 0, 'max': EmployeeImportRequest.maxRows},
      ),
    };
  }
}
