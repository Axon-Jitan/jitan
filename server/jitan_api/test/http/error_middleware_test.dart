import 'dart:convert';

import 'package:jitan_api/src/database/database_exception.dart';
import 'package:jitan_api/src/http/api_exception.dart';
import 'package:logging/logging.dart';
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

  test('a deadlock or lock timeout says try again (503), and the log keeps only the error number (review M7, I1)', () async {
    final logged = <String>[];
    Logger.root.level = Level.ALL;
    final listening = Logger.root.onRecord.listen((r) => logged.add('${r.message} ${r.error ?? ''}'));
    addTearDown(listening.cancel);

    for (final code in [1213, 1205]) {
      final handler = errorMiddleware()((_) => throw DatabaseQueryException("Duplicate entry 'SECRET-QR' for key", errorCode: code));
      final response = await handler(Request('GET', Uri.parse('http://api.test/x')));
      expect(response.statusCode, 503, reason: '$code');
    }
    final other = await errorFor(const DatabaseQueryException("Duplicate entry 'SECRET-QR' for key", errorCode: 1062));
    expect(other['code'], ApiErrorCode.internalError);
    expect(logged.join(), isNot(contains('SECRET-QR')));
    expect(logged.join(), contains('Database error 1213'));
  });

  test('a validation error keeps its message and field (the client shows it)', () async {
    final error = await errorFor(const ApiException.validation('name', 'Enter a name.'));

    expect(error, {'code': ApiErrorCode.validationFailed, 'message': 'Enter a name.', 'field': 'name'});
  });
}
