import 'package:jitan_models/jitan_models.dart';
import 'package:test/test.dart';

void main() {
  test('an employee code is stored trimmed and in capitals (CLARIFY-16)', () {
    expect(EmployeeCodes.normalize('  sbw '), 'SBW');
    expect(EmployeeCodes.normalize('Emu1'), 'EMU1');
    expect(EmployeeCodes.normalize('DEV-ADMIN'), 'DEV-ADMIN');
  });
}
