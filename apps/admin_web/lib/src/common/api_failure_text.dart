import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:jitan_core/jitan_core.dart';
import 'package:jitan_models/jitan_models.dart';

/// Title and message keys for a failed API call.
typedef FailureTextKeys = ({String title, String message});

/// Chooses user-facing text from the failure kind and server error code,
/// never from the server's diagnostic message.
FailureTextKeys failureTextKeysFor(ApiClientException failure) {
  if (failure.kind == ApiFailureKind.network) {
    return (title: CommonTextKeys.errorNetworkTitle, message: CommonTextKeys.errorNetworkMessage);
  }
  return switch (failure.error?.code) {
    ApiErrorCode.unauthenticated => (
      title: CommonTextKeys.errorUnauthenticatedTitle,
      message: CommonTextKeys.errorUnauthenticatedMessage,
    ),
    ApiErrorCode.forbidden => (
      title: CommonTextKeys.errorForbiddenTitle,
      message: CommonTextKeys.errorForbiddenMessage,
    ),
    ApiErrorCode.notFound => (title: CommonTextKeys.errorNotFoundTitle, message: CommonTextKeys.errorNotFoundMessage),
    ApiErrorCode.databaseUnavailable => (
      title: CommonTextKeys.errorDatabaseTitle,
      message: CommonTextKeys.errorDatabaseMessage,
    ),
    _ => (title: CommonTextKeys.errorUnexpectedTitle, message: CommonTextKeys.errorUnexpectedMessage),
  };
}
