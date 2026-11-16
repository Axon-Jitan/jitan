import 'package:shelf/shelf.dart';

/// HSTS: when Jitan serves HTTPS itself, browsers are told to use only HTTPS
/// for it from now on (review I2). Behind IT's HTTPS proxy, the proxy sets it.
Middleware strictTransportMiddleware() => (inner) => (request) async {
      final response = await inner(request);
      return response.change(headers: {strictTransportHeader: strictTransportValue});
    };

const strictTransportHeader = 'strict-transport-security';

/// One year. No `includeSubDomains`: Jitan is reached by IP or by IT's host
/// name, and other services on that domain are not Jitan's to decide.
const strictTransportValue = 'max-age=31536000';
