import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_client.dart';
import 'auth_service.dart';

/// One server-sent event from the familiars-server board stream.
class BoardEvent {
  /// e.g. `card_created`, `card_updated`, `card_deleted`, `card_moved`,
  /// `list_created`, `list_updated`, `list_deleted`.
  final String type;

  /// Decoded JSON payload from the `data:` line.
  final Map<String, dynamic> data;

  const BoardEvent(this.type, this.data);
}

/// Subscribes to `/api/boards/<id>/stream` and parses the SSE wire format.
///
/// The familiars-server emits frames shaped like:
/// ```
/// event: card_moved
/// data: {"id":"...", "listId":"...", "position":1.5}
///
/// : keepalive
/// ```
/// Comment lines (starting with `:`) are ignored. Frames are separated by
/// blank lines.
class SseClient {
  final AuthService auth;
  final http.Client _http;

  SseClient({required this.auth, http.Client? httpClient})
      : _http = httpClient ?? http.Client();

  /// Connect and yield events. The returned stream completes when the
  /// connection drops; the caller is responsible for reconnect logic.
  Stream<BoardEvent> connect(String boardId) async* {
    final token = await auth.idToken();
    if (token == null) throw const UnauthenticatedException();
    final uri = Uri.parse('${ApiClient.baseUrl}/api/boards/$boardId/stream');
    final req = http.Request('GET', uri)
      ..headers['authorization'] = 'Bearer $token'
      ..headers['accept'] = 'text/event-stream';
    final res = await _http.send(req);
    if (res.statusCode == 401) throw const UnauthenticatedException();
    if (res.statusCode != 200) {
      throw HttpException('SSE connect failed: ${res.statusCode}');
    }

    String? eventName;
    final dataBuf = StringBuffer();

    await for (final line in res.stream
        .transform(utf8.decoder)
        .transform(const LineSplitter())) {
      if (line.isEmpty) {
        // Frame boundary.
        if (eventName != null && dataBuf.isNotEmpty) {
          try {
            final decoded = jsonDecode(dataBuf.toString());
            if (decoded is Map<String, dynamic>) {
              yield BoardEvent(eventName, decoded);
            }
          } catch (_) {
            // skip malformed frames
          }
        }
        eventName = null;
        dataBuf.clear();
        continue;
      }
      if (line.startsWith(':')) continue; // comment / keepalive
      if (line.startsWith('event:')) {
        eventName = line.substring(6).trim();
      } else if (line.startsWith('data:')) {
        if (dataBuf.isNotEmpty) dataBuf.write('\n');
        dataBuf.write(line.substring(5).trim());
      }
    }
  }

  void close() => _http.close();
}
