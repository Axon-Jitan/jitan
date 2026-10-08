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

  test('isAssignable defaults to active and unassigned, survives JSON, and can be narrowed', () {
    const free = AssignmentOption(id: 2, name: 'HR', isActive: true, isAssigned: false);
    const nl = AssignmentOption(id: 2, name: 'Nederlands', isActive: true, isAssigned: false, code: 'nl');

    expect(free.isAssignable, isTrue);
    expect(const AssignmentOption(id: 1, name: 'x', isActive: false, isAssigned: false).isAssignable, isFalse);
    expect(AssignmentOption.fromJson(free.withAssignable(false).toJson()).isAssignable, isFalse);
    expect(AssignmentOption.fromJson(nl.toJson()).code, 'nl');
    expect(free.toJson().containsKey('code'), isFalse);
  });

  test('language requests', () {
    expect(SetLanguageRequest.fromJson({'languageId': 3}).languageId, 3);
    expect(() => SetLanguageRequest.fromJson({'languageId': '3'}), throwsFormatException);
    expect(SetUserLanguageRequest.fromJson({'languageCode': 'nl'}).languageCode, 'nl');
    expect(() => SetUserLanguageRequest.fromJson({}), throwsFormatException);
  });

  test('add request carries integer ids only', () {
    expect(AddAssignmentsRequest.fromJson({'ids': [2, 3]}).ids, [2, 3]);
    expect(() => AddAssignmentsRequest.fromJson({'ids': ['2']}), throwsFormatException);
    expect(() => AddAssignmentsRequest.fromJson({}), throwsFormatException);
  });
}
