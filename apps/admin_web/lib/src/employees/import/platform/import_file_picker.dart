import 'package:file_picker/file_picker.dart';

import '../employee_import_file.dart';

/// A file HR chose or dropped: its name and contents.
class ChosenImportFile {
  const ChosenImportFile({required this.name, required this.bytes});

  final String name;
  final List<int> bytes;
}

/// Opens the browser's file chooser for an .xlsx or .csv file; `null` when
/// HR cancels.
typedef ChooseImportFile = Future<ChosenImportFile?> Function();

/// The system file chooser (package `file_picker`).
Future<ChosenImportFile?> chooseImportFile() async {
  final files = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: EmployeeImportFileReader.extensions);
  final file = files.firstOrNull;
  if (file == null) return null;
  return ChosenImportFile(name: file.name, bytes: await file.xFile.readAsBytes());
}
