import 'dart:convert';

import 'package:shelf/shelf.dart';

const _jsonHeaders = {'content-type': 'application/json; charset=utf-8'};

/// A JSON response. [body] must be JSON-encodable (maps, lists, scalars).
Response jsonResponse(Object? body, {int statusCode = 200}) =>
    Response(statusCode, body: jsonEncode(body), headers: _jsonHeaders);
