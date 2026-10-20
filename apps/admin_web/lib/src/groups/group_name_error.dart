import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:jitan_models/jitan_models.dart';

import '../l10n/admin_text_keys.dart';

/// The text key for a group name the server refused, or `null` when the
/// failure is not about the name (shown as a general error instead).
String? groupNameErrorKey(ApiClientException failure) => switch (failure.error) {
  ApiError(code: ApiErrorCode.duplicateGroupName) => AdminTextKeys.groupsErrorNameDuplicate,
  ApiError(code: ApiErrorCode.validationFailed, field: GroupNameRequest.fieldName) => AdminTextKeys.groupsErrorNameEmpty,
  _ => null,
};

/// The same checks as the server, for quick feedback: not empty, at most
/// [GroupNameRequest.maxNameLength] characters.
String? groupNameProblem(String name) {
  final trimmed = name.trim();
  if (trimmed.isEmpty) return AdminTextKeys.groupsErrorNameEmpty;
  if (trimmed.runes.length > GroupNameRequest.maxNameLength) return AdminTextKeys.groupsErrorNameTooLong;
  return null;
}
