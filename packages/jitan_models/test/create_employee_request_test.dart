import 'package:jitan_models/jitan_models.dart';
import 'package:test/test.dart';

void main() {
  test('CreateEmployeeRequest round-trips, optional fields included', () {
    const original = CreateEmployeeRequest(
      firstName: 'Disan',
      lastName: 'Ssebowa',
      code: 'SBW',
      phone: '+32 470',
      email: 'disan@example.com',
      companyIds: [8],
      groupIds: [3, 4],
      scheduleGroupId: 4,
    );

    final decoded = CreateEmployeeRequest.fromJson(original.toJson());

    expect(decoded.firstName, 'Disan');
    expect(decoded.code, 'SBW');
    expect(decoded.phone, '+32 470');
    expect(decoded.email, 'disan@example.com');
    expect(decoded.companyIds, [8]);
    expect(decoded.groupIds, [3, 4]);
    expect(decoded.scheduleGroupId, 4);
  });

  test('CreateEmployeeRequest accepts missing optional fields', () {
    final decoded = CreateEmployeeRequest.fromJson({'firstName': 'A', 'lastName': 'B', 'code': 'C'});

    expect(decoded.groupIds, isEmpty);
    expect(decoded.companyIds, isEmpty);
    expect(decoded.phone, isNull);
    expect(decoded.email, isNull);
    expect(decoded.scheduleGroupId, isNull);
  });

  test('CreateEmployeeRequest rejects a missing required field', () {
    expect(() => CreateEmployeeRequest.fromJson({'firstName': 'A', 'code': 'C'}), throwsFormatException);
  });

  test('GroupListResponse round-trips', () {
    const original = GroupListResponse(groups: [GroupSummary(id: 1, name: 'White collar')]);

    expect(GroupListResponse.fromJson(original.toJson()).groups.single.name, 'White collar');
  });

  test('ApiError carries an optional field', () {
    const withField = ApiError(code: ApiErrorCode.duplicateEmployeeCode, message: 'x', field: 'code');
    const withoutField = ApiError(code: ApiErrorCode.forbidden, message: 'x');

    expect(ApiError.fromJson(withField.toJson()).field, 'code');
    expect(ApiError.fromJson(withoutField.toJson()).field, isNull);
    expect((withoutField.toJson()['error'] as Map).containsKey('field'), isFalse);
  });
}
