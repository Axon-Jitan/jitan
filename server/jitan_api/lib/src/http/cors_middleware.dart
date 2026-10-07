import 'package:shelf/shelf.dart';

/// Allows the listed browser origins to call the API.
///
/// Only needed in development, where the Flutter web dev server runs on a
/// different port. In production Nginx serves the web apps and the API from
/// one origin and [allowedOrigins] is empty, which makes this a no-op.
Middleware corsMiddleware(Set<String> allowedOrigins) => (inner) => (request) async {
      final origin = request.headers['origin'];
      final allowed = origin != null && allowedOrigins.contains(origin);

      if (request.method == 'OPTIONS' && allowed) {
        return Response(204, headers: _headersFor(origin));
      }

      final response = await inner(request);
      return allowed ? response.change(headers: _headersFor(origin)) : response;
    };

Map<String, String> _headersFor(String origin) => {
      'access-control-allow-origin': origin,
      'access-control-allow-methods': 'GET, POST, PUT, PATCH, DELETE, OPTIONS',
      'access-control-allow-headers': 'content-type, authorization',
      'access-control-max-age': '600',
      'vary': 'origin',
    };
