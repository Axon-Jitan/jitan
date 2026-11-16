import 'package:employee_mobile/src/l10n/employee_text_keys.dart';
import 'package:employee_mobile/src/today/registration_failure_text.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:jitan_models/jitan_models.dart';

void main() {
  test('a time outside 05:00–19:00 says to see HR (D52); others as before', () {
    ApiClientException server(String code) => ApiClientException.server(400, ApiError(code: code, message: 'x'));

    expect(registrationFailureKey(server(ApiErrorCode.outsideWorkingHours)), EmployeeTextKeys.todayOutsideWorkingHours);
    expect(registrationFailureKey(server(ApiErrorCode.validationFailed)), EmployeeTextKeys.todaySaveRefused);
    expect(registrationFailureKey(const ApiClientException.network('offline')), EmployeeTextKeys.todayCheckConnection);
  });
}
