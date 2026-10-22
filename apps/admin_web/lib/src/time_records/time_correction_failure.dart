import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:jitan_models/jitan_models.dart';

import '../common/api_failure_text.dart';
import '../l10n/admin_text_keys.dart';

/// Where a failed correction is shown: under the time, under the reason, or
/// as a message above the buttons. Text from keys, never from the server's
/// diagnostic message.
sealed class TimeCorrectionFailure {
  const TimeCorrectionFailure();

  static TimeCorrectionFailure of(ApiClientException failure) => switch (failure.error) {
    ApiError(code: ApiErrorCode.validationFailed, field: CorrectTimeRequest.fieldTime) => const TimeFieldFailure(
      AdminTextKeys.timeCorrectTimeRejected,
    ),
    ApiError(code: ApiErrorCode.validationFailed, field: CorrectTimeRequest.fieldReason) => const ReasonFieldFailure(
      AdminTextKeys.timeCorrectReasonRequired,
    ),
    ApiError(code: ApiErrorCode.configurationError) => const MessageFailure(AdminTextKeys.timeCorrectNoRounding),
    ApiError(code: ApiErrorCode.nothingToMarkNonWork) => const MessageFailure(AdminTextKeys.timeResolveNothingToMark),
    _ => MessageFailure.keys(failureTextKeysFor(failure)),
  };
}

class TimeFieldFailure extends TimeCorrectionFailure {
  const TimeFieldFailure(this.key);

  final String key;
}

class ReasonFieldFailure extends TimeCorrectionFailure {
  const ReasonFieldFailure(this.key);

  final String key;
}

class MessageFailure extends TimeCorrectionFailure {
  const MessageFailure(this.title, [this.message]);

  MessageFailure.keys(FailureTextKeys keys) : this(keys.title, keys.message);

  final String title;
  final String? message;
}
