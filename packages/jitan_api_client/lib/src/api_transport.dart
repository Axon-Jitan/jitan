import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:jitan_models/jitan_models.dart';

import 'api_client_exception.dart';

/// Sends requests to the Jitan API and turns every outcome into either a
/// decoded JSON object or an [ApiClientException].
///
/// Authentication headers will be added here once real login exists; the
/// per-resource API classes stay unchanged.
class ApiTransport {
  ApiTransport({required this.baseUri, http.Client? httpClient, this.timeout = defaultTimeout})
      : _http = httpClient ?? http.Client();

  static const defaultTimeout = Duration(seconds: 15);

  /// API root, e.g. `http://127.0.0.1:8080/`.
  final Uri baseUri;
  final Duration timeout;
  final http.Client _http;

  Future<Map<String, Object?>> getJson(String path, {Map<String, String>? query}) async {
    final uri = baseUri.resolve(path).replace(
          queryParameters: (query == null || query.isEmpty) ? null : query,
        );

    final http.Response response;
    try {
      response = await _http.get(uri, headers: const {'accept': 'application/json'}).timeout(timeout);
    } on TimeoutException {
      throw ApiClientException.network('GET $uri timed out after $timeout.');
    } on http.ClientException catch (e) {
      throw ApiClientException.network('GET $uri failed: ${e.message}');
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
