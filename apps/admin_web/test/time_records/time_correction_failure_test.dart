import 'package:admin_web/src/l10n/admin_text_keys.dart';
import 'package:admin_web/src/time_records/time_correction_failure.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:jitan_models/jitan_models.dart';

void main() {
  test('your own time: its own message, not "no access" (review M3)', () {
    final failure = TimeCorrectionFailure.of(
      const ApiClientException.server(403, ApiError(code: ApiErrorCode.ownTimeRecords, message: 'x')),
    );

    expect(failure, isA<MessageFailure>().having((f) => f.title, 'title', AdminTextKeys.timeCorrectOwnRecords));
  });
}
