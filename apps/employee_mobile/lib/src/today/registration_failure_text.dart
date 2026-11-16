import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:jitan_models/jitan_models.dart';

import '../l10n/employee_text_keys.dart';

/// The message under a start or finish that wasn't saved: the connection,
/// a time outside 05:00–19:00 (see HR, D52), or any other refusal.
String registrationFailureKey(ApiClientException failure) {
  if (failure.kind == ApiFailureKind.network) return EmployeeTextKeys.todayCheckConnection;
  if (failure.error?.code == ApiErrorCode.outsideWorkingHours) return EmployeeTextKeys.todayOutsideWorkingHours;
  return EmployeeTextKeys.todaySaveRefused;
}
