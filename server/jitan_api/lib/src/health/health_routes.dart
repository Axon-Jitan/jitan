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

  /// `/health/live` and `/health/ready` are the names IT's network test
  /// used: live = the process answers, ready = it can reach the database.
  Router get router => Router()
    ..get('/health', _health)
    ..get('/health/live', _health)
    ..get('/health/database', _databaseHealthCheck)
    ..get('/health/ready', _databaseHealthCheck);

  Response _health(Request request) => jsonResponse({'status': 'ok'});

  /// 200 when `SELECT 1` succeeds; otherwise the error middleware returns
  /// 503 `database_unavailable`.
  Future<Response> _databaseHealthCheck(Request request) async {
    await _databaseHealth.ping();
    return jsonResponse({'status': 'ok', 'database': 'reachable'});
  }
}
