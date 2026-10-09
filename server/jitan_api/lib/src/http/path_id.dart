import 'api_exception.dart';

/// An id from a URL path segment that the route already limits to `[0-9]+`.
///
/// A number too large for an int cannot be any row, so it is "not found"
/// (404, with [notFoundMessage]) like any other unknown id, never a 500.
int pathId(String raw, String notFoundMessage) => int.tryParse(raw) ?? (throw ApiException.notFound(notFoundMessage));
