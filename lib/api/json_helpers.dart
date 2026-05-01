import 'dart:convert';

import 'package:shelf/shelf.dart';

/// Build a JSON [Response] with [statusCode] and JSON-encoded [body].
Response jsonResponse(int statusCode, Object body) {
  return Response(
    statusCode,
    body: jsonEncode(body),
    headers: {'content-type': 'application/json'},
  );
}

/// 200 + JSON body.
Response jsonOk(Object body) => jsonResponse(200, body);

/// 201 + JSON body.
Response jsonCreated(Object body) => jsonResponse(201, body);

/// 400 + `{"error": message}`.
Response badRequest(String message) =>
    jsonResponse(400, {'error': message});

/// 404 + `{"error": message}`.
Response notFound(String message) =>
    jsonResponse(404, {'error': message});

/// 409 + `{"error": message}`.
Response conflict(String message) =>
    jsonResponse(409, {'error': message});

/// Decode the request body as a JSON object. Returns `null` if the body is
/// empty (callers can decide whether that's OK). Throws [FormatException] if
/// the body is non-empty but not a JSON object — the router catches this and
/// returns 400.
Future<Map<String, Object?>?> decodeJsonBody(Request request) async {
  final raw = await request.readAsString();
  if (raw.isEmpty) return null;
  final decoded = jsonDecode(raw);
  if (decoded is! Map) {
    throw const FormatException('expected JSON object');
  }
  return decoded.cast<String, Object?>();
}
