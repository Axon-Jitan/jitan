import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:jitan_models/jitan_models.dart';

import '../l10n/admin_strings.dart';

/// Title and message to show for a failed API call.
typedef FailureText = ({String title, String message});

/// Chooses user-facing text from the failure kind and server error code,
/// never from the server's diagnostic message.
FailureText failureTextFor(ApiClientException failure) {
  if (failure.kind == ApiFailureKind.network) {
    return (title: AdminStrings.errorNetworkTitle, message: AdminStrings.errorNetworkMessage);
  }
  return switch (failure.error?.code) {
    ApiErrorCode.unauthenticated => (
        title: AdminStrings.errorUnauthenticatedTitle,
        message: AdminStrings.errorUnauthenticatedMessage,
      ),
    ApiErrorCode.forbidden => (
        title: AdminStrings.errorForbiddenTitle,
        message: AdminStrings.errorForbiddenMessage,
      ),
    ApiErrorCode.databaseUnavailable => (
        title: AdminStrings.errorDatabaseTitle,
        message: AdminStrings.errorDatabaseMessage,
      ),
    _ => (title: AdminStrings.errorUnexpectedTitle, message: AdminStrings.errorUnexpectedMessage),
  };
}
