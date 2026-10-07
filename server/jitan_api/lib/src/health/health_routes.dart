import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../http/json_response.dart';
import 'database_health_repository.dart';

/// Unauthenticated infrastructure endpoints (ENGINEERING_RULES §32).
///
/// Consumers: deployment monitoring and Nginx upstream checks, and
/// developers verifying the API → MySQL path before each slice.
class HealthRoutes {
  const HealthRoutes(this._databaseHealth);

  final DatabaseHealthRepository _databaseHealth;

  Router get router => Router()
    ..get('/health', _health)
    ..get('/health/database', _databaseHealthCheck);

  Response _health(Request request) => jsonResponse({'status': 'ok'});

  /// 200 when `SELECT 1` succeeds; otherwise the error middleware returns
  /// 503 `database_unavailable`.
  Future<Response> _databaseHealthCheck(Request request) async {
    await _databaseHealth.ping();
    return jsonResponse({'status': 'ok', 'database': 'reachable'});
  }
}
