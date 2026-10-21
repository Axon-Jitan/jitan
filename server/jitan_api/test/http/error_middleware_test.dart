import 'dart:convert';

import 'package:jitan_api/src/http/api_exception.dart';
import 'package:jitan_api/src/http/error_middleware.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

/// No internal detail reaches the client (ENGINEERING_RULES §28a).
void main() {
  Future<Map<String, Object?>> errorFor(Object thrown) async {
    final handler = errorMiddleware()((_) => throw thrown);
    final response = await handler(Request('GET', Uri.parse('http://api.test/x')));
    return (jsonDecode(await response.readAsString()) as Map<String, Object?>)['error']! as Map<String, Object?>;
  }

  test('a configuration error keeps its code but not its detail (tables, rows, IDs)', () async {
    final error = await errorFor(
      const ApiException.configurationError('tblScheduleType must have exactly one active row named "Break" (found 2).'),
    );

    expect(error['code'], ApiErrorCode.configurationError);
    expect(error['message'], configurationErrorMessage);
    expect(jsonEncode(error), isNot(contains('tbl')));
  });

  test('an unexpected error says nothing about SQL or the server', () async {
    final error = await errorFor(StateError("SELECT * FROM tblUser WHERE userPassword = 'x' failed on db.internal:3306"));

    expect(error['code'], ApiErrorCode.internalError);
    expect(jsonEncode(error), isNot(anyOf(contains('SELECT'), contains('tblUser'), contains('3306'), contains('userPassword'))));
  });

  test('a validation error keeps its message and field (the client shows it)', () async {
    final error = await errorFor(const ApiException.validation('name', 'Enter a name.'));

    expect(error, {'code': ApiErrorCode.validationFailed, 'message': 'Enter a name.', 'field': 'name'});
  });
}
