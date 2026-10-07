import 'dart:convert';

import 'package:shelf/shelf.dart';

import 'api_exception.dart';

/// The request body as a JSON object; 400 when it is not one.
Future<Map<String, Object?>> readJsonObject(Request request) async {
  final Object? decoded;
  try {
    decoded = jsonDecode(await request.readAsString());
  } on FormatException {
    throw const ApiException.badRequest('The request body must be valid JSON.');
  }
  if (decoded is Map<String, Object?>) return decoded;
  throw const ApiException.badRequest('The request body must be a JSON object.');
}
