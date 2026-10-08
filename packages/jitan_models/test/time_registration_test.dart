import 'package:jitan_models/jitan_models.dart';
import 'package:test/test.dart';

void main() {
  final registration = TimeRegistration(
    id: 7,
    userId: 3,
    timestamp: DateTime(2026, 10, 8, 8, 3),
    typeId: 1,
    typeName: 'In',
    addressId: 2,
    addressName: 'Almeco office',
    isManualEntry: false,
    comment: null,
    modifiedAt: null,
  );

  test('round-trips; the wall-clock timestamp carries no offset (GAP-02)', () {
    final json = registration.toJson();
    final back = TimeRegistration.fromJson(json);

    expect(json['timestamp'], '2026-10-08T08:03:00.000');
    expect(back.timestamp, DateTime(2026, 10, 8, 8, 3));
    expect(back.timestamp.isUtc, isFalse);
    expect((back.id, back.typeName, back.addressName, back.isManualEntry), (7, 'In', 'Almeco office', false));
  });

  test('unknown manual flag, type and address stay null; nothing is invented', () {
    final back = TimeRegistration.fromJson({
      'id': 1,
      'userId': 3,
      'timestamp': '2026-10-08T08:03:00',
      'typeId': null,
      'typeName': null,
      'addressId': null,
      'addressName': null,
      'isManualEntry': null,
      'comment': null,
      'modifiedAt': null,
    });

    expect((back.typeId, back.addressId, back.isManualEntry), (null, null, null));
  });

  test('a page round-trips with its cursor', () {
    final page = TimeRegistrationPage.fromJson(
      TimeRegistrationPage(registrations: [registration], nextCursor: 'abc').toJson(),
    );

    expect(page.registrations.single.id, 7);
    expect(page.nextCursor, 'abc');
    expect(() => TimeRegistration.fromJson({'id': 1, 'userId': 3}), throwsFormatException);
  });
}
