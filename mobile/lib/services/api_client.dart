import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/board.dart';
import 'auth_service.dart';

/// Thrown when the server rejects auth (HTTP 401).
class UnauthenticatedException implements Exception {
  const UnauthenticatedException();
  @override
  String toString() => 'UnauthenticatedException';
}

/// Thrown when the server reports a foreign-key / state conflict (HTTP 409).
class ConflictException implements Exception {
  final String message;
  const ConflictException(this.message);
  @override
  String toString() => 'ConflictException: $message';
}

/// Thin REST client for the familiars-server `/api/*` surface.
///
/// All calls attach a Firebase JWT via [AuthService.idToken]. On 401 the
/// caller should drop the user back to the login screen; on 409 the caller
/// should reload board state.
class ApiClient {
  /// Base URL for the deployed familiars-server.
  static const String baseUrl = 'https://familiars.imagineering.cc';

  final AuthService auth;
  final http.Client _http;

  ApiClient({required this.auth, http.Client? httpClient})
      : _http = httpClient ?? http.Client();

  Future<Map<String, String>> _authHeaders({bool forceRefresh = false}) async {
    final token = await auth.idToken(forceRefresh: forceRefresh);
    if (token == null) throw const UnauthenticatedException();
    return {
      'authorization': 'Bearer $token',
      'content-type': 'application/json',
    };
  }

  Never _throwForStatus(http.Response res) {
    if (res.statusCode == 401) throw const UnauthenticatedException();
    if (res.statusCode == 409) {
      throw ConflictException(_messageOrBody(res));
    }
    throw HttpException(
      'HTTP ${res.statusCode}: ${_messageOrBody(res)}',
    );
  }

  String _messageOrBody(http.Response res) {
    try {
      final j = jsonDecode(res.body);
      if (j is Map && j['error'] is String) return j['error'] as String;
    } catch (_) {}
    return res.body;
  }

  /// List all boards (lightweight — no nested lists/cards).
  Future<List<Map<String, dynamic>>> listBoards() async {
    final res = await _http.get(
      Uri.parse('$baseUrl/api/boards'),
      headers: await _authHeaders(),
    );
    if (res.statusCode != 200) _throwForStatus(res);
    return (jsonDecode(res.body) as List<dynamic>)
        .cast<Map<String, dynamic>>();
  }

  /// Create a new board with [name].
  Future<Map<String, dynamic>> createBoard(String name) async {
    final res = await _http.post(
      Uri.parse('$baseUrl/api/boards'),
      headers: await _authHeaders(),
      body: jsonEncode({'name': name}),
    );
    if (res.statusCode != 201) _throwForStatus(res);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  /// Fetch a board with nested lists and cards.
  Future<Board> getBoard(String boardId) async {
    final res = await _http.get(
      Uri.parse('$baseUrl/api/boards/$boardId'),
      headers: await _authHeaders(),
    );
    if (res.statusCode != 200) _throwForStatus(res);
    return Board.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  /// Create a list on a board.
  Future<Map<String, dynamic>> createList({
    required String boardId,
    required String name,
    double? position,
  }) async {
    final res = await _http.post(
      Uri.parse('$baseUrl/api/boards/$boardId/lists'),
      headers: await _authHeaders(),
      body: jsonEncode({
        'name': name,
        if (position != null) 'position': position,
      }),
    );
    if (res.statusCode != 201) _throwForStatus(res);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  /// Create a card on a list.
  Future<Map<String, dynamic>> createCard({
    required String boardId,
    required String listId,
    required String title,
    String? description,
    double? position,
  }) async {
    final res = await _http.post(
      Uri.parse('$baseUrl/api/boards/$boardId/cards'),
      headers: await _authHeaders(),
      body: jsonEncode({
        'listId': listId,
        'title': title,
        if (description != null) 'description': description,
        if (position != null) 'position': position,
      }),
    );
    if (res.statusCode != 201) _throwForStatus(res);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  /// PATCH a card. Pass only the fields that should change. Omitted fields
  /// retain their current values; explicitly null fields clear them.
  Future<Map<String, dynamic>> updateCard(
    String id, {
    String? title,
    String? listId,
    double? position,
    Object? description = _absent,
  }) async {
    final body = <String, dynamic>{};
    if (title != null) body['title'] = title;
    if (listId != null) body['listId'] = listId;
    if (position != null) body['position'] = position;
    if (!identical(description, _absent)) body['description'] = description;

    final res = await _http.patch(
      Uri.parse('$baseUrl/api/cards/$id'),
      headers: await _authHeaders(),
      body: jsonEncode(body),
    );
    if (res.statusCode != 200) _throwForStatus(res);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  void close() => _http.close();
}

/// Sentinel for distinguishing "field not provided" from "field set to null".
const Object _absent = Object();

/// Thrown for non-401/409 HTTP failures; surfaced as a toast in the UI.
class HttpException implements Exception {
  final String message;
  const HttpException(this.message);
  @override
  String toString() => message;
}
