import 'package:flutter/foundation.dart';
import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:jitan_models/jitan_models.dart';

import 'employee_import_file.dart';

/// What the Import employees page shows (Figma `1419:2` … `1419:369`).
sealed class EmployeeImportState {
  const EmployeeImportState();
}

/// "Ready": waiting for a file.
class ImportWaitingForFile extends EmployeeImportState {
  const ImportWaitingForFile();
}

/// "Reading file": the file is read and its rows checked by the server.
class ImportReading extends EmployeeImportState {
  const ImportReading({required this.name, required this.sizeBytes});

  final String name;
  final int sizeBytes;
}

/// "File can't be used": the file itself, or the server check, failed.
/// Exactly one of [problem] and [failure] is set.
class ImportUnusable extends EmployeeImportState {
  const ImportUnusable({this.problem, this.failure});

  final ImportFileProblem? problem;
  final ApiClientException? failure;
}

/// "Preview" and "Importing": the rows, each ready or with its problem.
class ImportPreview extends EmployeeImportState {
  const ImportPreview({required this.file, required this.problems, this.importing = false, this.failure});

  final ImportFile file;

  /// Row number → its problem; rows not in it are ready.
  final Map<int, EmployeeImportProblem> problems;

  /// The import request is running ("Importing").
  final bool importing;

  /// Why the last import attempt failed (nothing was added).
  final ApiClientException? failure;

  int get readyCount => file.rows.length - problems.length;

  ImportPreview copyWith({required bool importing, ApiClientException? failure}) =>
      ImportPreview(file: file, problems: problems, importing: importing, failure: failure);
}

/// "Done": the server added [result.added] employees.
class ImportDone extends EmployeeImportState {
  const ImportDone(this.result);

  final EmployeeImportResult result;
}

/// Import employees into [companyId]: read a file, show the server's check
/// of each row, then import the ready rows. Nothing is reported as added
/// before the server confirms it.
class EmployeeImportController extends ChangeNotifier {
  EmployeeImportController(this._api, {required this.companyId, required this.columnNames});

  final EmployeesApi _api;
  final int companyId;

  /// The names each column may have in a file (see
  /// [EmployeeImportFileReader.read]).
  final Map<ImportColumn, Set<String>> columnNames;

  EmployeeImportState _state = const ImportWaitingForFile();
  EmployeeImportState get state => _state;

  /// Counts files opened, so a slow check of an earlier file is ignored.
  var _attempt = 0;
  var _disposed = false;

  /// Reads [bytes] (a file named [name]) and asks the server which rows can
  /// be imported.
  Future<void> open(String name, List<int> bytes) async {
    final attempt = ++_attempt;
    _set(ImportReading(name: name, sizeBytes: bytes.length));
    final ImportFile file;
    try {
      file = EmployeeImportFileReader.read(name, bytes, columnNames);
    } on ImportFileProblem catch (problem) {
      _set(ImportUnusable(problem: problem));
      return;
    }
    try {
      final check = await _api.checkImport(companyId, EmployeeImportRequest(rows: file.rows));
      if (attempt != _attempt) return;
      _set(ImportPreview(file: file, problems: {for (final p in check.problems) p.row: p}));
    } on ApiClientException catch (failure) {
      if (attempt != _attempt) return;
      _set(ImportUnusable(failure: failure));
    }
  }

  /// Imports the ready rows of the previewed file.
  Future<void> import() async {
    final preview = _state;
    if (preview is! ImportPreview || preview.importing || preview.readyCount == 0) return;
    final attempt = _attempt;
    _set(preview.copyWith(importing: true));
    try {
      final result = await _api.importEmployees(companyId, EmployeeImportRequest(rows: preview.file.rows));
      if (attempt != _attempt) return;
      _set(ImportDone(result));
    } on ApiClientException catch (failure) {
      if (attempt != _attempt) return;
      _set(preview.copyWith(importing: false, failure: failure));
    }
  }

  /// Back to "Ready" ("Choose another file", "Import another file").
  void reset() {
    _attempt++;
    _set(const ImportWaitingForFile());
  }

  void _set(EmployeeImportState state) {
    if (_disposed) return;
    _state = state;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
