import 'package:jitan_models/jitan_models.dart';
import 'package:logging/logging.dart';
import 'package:shelf/shelf.dart';

import '../database/database_exception.dart';
import 'api_exception.dart';
import 'json_response.dart';

final _log = Logger('http.errors');

/// What the client is told about a configuration error; the detail is only
/// in the server log.
const configurationErrorMessage = 'Some data this needs is not set up correctly. Ask an administrator to check it.';

/// Converts every failure into the structured `{"error": {...}}` body.
///
/// Expected failures ([ApiException]) keep their message, except
/// configuration errors: their detail names stored data (tables, rows, IDs),
/// so it is logged and the client gets a generic message (ENGINEERING_RULES
/// §28a). Anything else is logged with its stack trace and returned as a
/// generic message, so internals (SQL, hostnames, stack traces) never reach
/// the client.
Middleware errorMiddleware() => (inner) => (request) async {
      try {
        return await inner(request);
      } on ApiException catch (e) {
        if (e.code == ApiErrorCode.configurationError) {
          _log.severe('Configuration error: ${request.method} ${request.requestedUri.path}: ${e.message}');
          return jsonResponse(
            const ApiError(code: ApiErrorCode.configurationError, message: configurationErrorMessage).toJson(),
            statusCode: e.statusCode,
          );
        }
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
