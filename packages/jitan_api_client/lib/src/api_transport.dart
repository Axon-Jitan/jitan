import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:jitan_models/jitan_models.dart';

import 'api_client_exception.dart';

/// Sends requests to the Jitan API and turns every outcome into either a
/// decoded JSON object or an [ApiClientException].
///
/// With [accessToken], every request carries `Authorization: Bearer <token>`
/// (the session from onboarding or sign-in). The per-resource API classes
/// stay unaware of authentication.
class ApiTransport {
  ApiTransport({required this.baseUri, http.Client? httpClient, this.timeout = defaultTimeout, this.accessToken})
    : _http = httpClient ?? http.Client();

  /// Returns the current session token, or `null` when signed out. Read on
  /// every request, so signing in or out takes effect immediately.
  final String? Function()? accessToken;

  static const defaultTimeout = Duration(seconds: 15);

  /// API root, e.g. `http://127.0.0.1:8080/`.
  final Uri baseUri;
  final Duration timeout;
  final http.Client _http;

  Future<Map<String, Object?>> getJson(String path, {Map<String, String>? query}) {
    final uri = baseUri.resolve(path).replace(queryParameters: (query == null || query.isEmpty) ? null : query);
    return _send('GET', uri, () => _http.get(uri, headers: _headers(const {'accept': 'application/json'})));
  }

  /// POSTs [body] as JSON.
  ///
  /// A timeout is reported as a network failure even though the server may
  /// have completed the request; callers must not assume it failed. For
  /// creates, a retry then meets the server's duplicate protection (e.g.
  /// `duplicate_employee_code`) instead of creating twice.
  Future<Map<String, Object?>> postJson(String path, Map<String, Object?> body) {
    final uri = baseUri.resolve(path);
    return _send(
      'POST',
      uri,
      () => _http.post(
        uri,
        headers: _headers(const {'accept': 'application/json', 'content-type': 'application/json; charset=utf-8'}),
        body: jsonEncode(body),
      ),
    );
  }

  Future<Map<String, Object?>> _send(String method, Uri uri, Future<http.Response> Function() call) async {
    final http.Response response;
    try {
      response = await call().timeout(timeout);
    } on TimeoutException {
      throw ApiClientException.network('$method $uri timed out after $timeout.');
    } on http.ClientException catch (e) {
      throw ApiClientException.network('$method $uri failed: ${e.message}');
    }

    final body = _decodeObject(response);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (body == null) {
        throw ApiClientException.invalidResponse(response.statusCode, 'Expected a JSON object.');
      }
      return body;
    }
    final error = body == null ? null : _tryParseError(body);
    if (error != null) throw ApiClientException.server(response.statusCode, error);
    throw ApiClientException.invalidResponse(
      response.statusCode,
      'Unexpected ${response.statusCode} response without a structured error.',
    );
  }

  Map<String, String> _headers(Map<String, String> base) {
    final token = accessToken?.call();
    return token == null ? base : {...base, 'authorization': 'Bearer $token'};
  }

  void close() => _http.close();

  static ApiError? _tryParseError(Map<String, Object?> body) {
    try {
      return ApiError.fromJson(body);
    } on FormatException {
      return null;
    }
  }

  static Map<String, Object?>? _decodeObject(http.Response response) {
    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      return decoded is Map<String, Object?> ? decoded : null;
    } on FormatException {
      return null;
    }
  }
}
