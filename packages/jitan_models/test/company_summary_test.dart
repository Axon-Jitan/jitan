import 'package:jitan_models/jitan_models.dart';
import 'package:test/test.dart';

void main() {
  group('CompanySummary', () {
    test('round-trips through JSON', () {
      final original = CompanySummary(
        id: 7,
        name: 'Almeco',
        isActive: true,
        employeeCount: 48,
        lastUpdatedAt: DateTime(2026, 10, 7, 9, 30),
      );

      final decoded = CompanySummary.fromJson(original.toJson());

      expect(decoded.id, 7);
      expect(decoded.name, 'Almeco');
      expect(decoded.isActive, isTrue);
      expect(decoded.employeeCount, 48);
      expect(decoded.lastUpdatedAt, DateTime(2026, 10, 7, 9, 30));
    });

    test('accepts a null lastUpdatedAt', () {
      final decoded = CompanySummary.fromJson({
        'id': 1,
        'name': 'PCA',
        'isActive': false,
        'employeeCount': 0,
        'lastUpdatedAt': null,
      });

      expect(decoded.lastUpdatedAt, isNull);
      expect(decoded.isActive, isFalse);
    });

    test('rejects a payload with a wrongly typed field', () {
      expect(
        () => CompanySummary.fromJson({
          'id': '1',
          'name': 'PCA',
          'isActive': true,
          'employeeCount': 0,
          'lastUpdatedAt': null,
        }),
        throwsFormatException,
      );
    });
  });

  group('CompanyListResponse', () {
    test('decodes a list of companies', () {
      final response = CompanyListResponse.fromJson({
        'companies': [
          {'id': 1, 'name': 'A', 'isActive': true, 'employeeCount': 2, 'lastUpdatedAt': null},
          {'id': 2, 'name': 'B', 'isActive': false, 'employeeCount': 0, 'lastUpdatedAt': null},
        ],
      });

      expect(response.companies.map((c) => c.name), ['A', 'B']);
    });
  });

  group('ApiError', () {
    test('round-trips through JSON', () {
      const error = ApiError(code: ApiErrorCode.forbidden, message: 'No access.');

      final decoded = ApiError.fromJson(error.toJson());

      expect(decoded.code, ApiErrorCode.forbidden);
      expect(decoded.message, 'No access.');
    });
  });
}
