import 'package:jitan_models/jitan_models.dart';
import 'package:test/test.dart';

void main() {
  test('assignment options round-trip', () {
    const options = AssignmentOptions(options: [
      AssignmentOption(id: 1, name: 'Almeco', isActive: true, isAssigned: true),
      AssignmentOption(id: 2, name: 'PCA', isActive: true, isAssigned: false),
    ]);

    final back = AssignmentOptions.fromJson(options.toJson());

    expect(back.options.map((o) => (o.id, o.name, o.isActive, o.isAssigned)), [
      (1, 'Almeco', true, true),
      (2, 'PCA', true, false),
    ]);
  });

  test('add request carries integer ids only', () {
    expect(AddAssignmentsRequest.fromJson({'ids': [2, 3]}).ids, [2, 3]);
    expect(() => AddAssignmentsRequest.fromJson({'ids': ['2']}), throwsFormatException);
    expect(() => AddAssignmentsRequest.fromJson({}), throwsFormatException);
  });
}
