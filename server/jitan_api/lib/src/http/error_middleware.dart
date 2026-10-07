import 'package:jitan_models/jitan_models.dart';
import 'package:logging/logging.dart';
import 'package:shelf/shelf.dart';

import '../database/database_exception.dart';
import 'api_exception.dart';
import 'json_response.dart';

final _log = Logger('http.errors');

/// Converts every failure into the structured `{"error": {...}}` body.
///
/// Expected failures ([ApiException]) keep their message. Anything else is
/// logged with its stack trace and returned as a generic message, so
/// internals (SQL, hostnames, stack traces) never reach the client.
Middleware errorMiddleware() => (inner) => (request) async {
      try {
        return await inner(request);
      } on ApiException catch (e) {
        return jsonResponse(e.toApiError().toJson(), statusCode: e.statusCode);
      } on DatabaseUnavailableException catch (e, stack) {
        _log.severe('Database unavailable: ${request.method} ${request.requestedUri.path}', e, stack);
        return jsonResponse(
          const ApiError(
            code: ApiErrorCode.databaseUnavailable,
            message: 'The database is currently unavailable.',
          ).toJson(),
          statusCode: 503,
        );
      } catch (e, stack) {
        _log.severe('Unhandled error: ${request.method} ${request.requestedUri.path}', e, stack);
        return jsonResponse(
          const ApiError(
            code: ApiErrorCode.internalError,
            message: 'An unexpected error occurred.',
          ).toJson(),
          statusCode: 500,
        );
      }
    };
