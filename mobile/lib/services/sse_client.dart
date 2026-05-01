import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/board.dart';
import 'api_client.dart';
import 'auth_service.dart';

/// Sealed hierarchy of server-sent events from the familiars-server board
/// stream. Mirrors the closed set of event types in `lib/api/stream_router.dart`
/// — using a sealed class lets the analyzer enforce exhaustive switching
/// instead of silently no-op'ing on a typo'd string literal.
sealed class BoardEvent {
  const BoardEvent();

  /// Parse a raw SSE frame (event name + decoded data payload) into a typed
  /// event. Returns null for unknown event types — callers should ignore
  /// rather than crash, since the server may add types ahead of clients.
  static BoardEvent? fromRaw(String type, Map<String, dynamic> data) {
    switch (type) {
      case 'card_created':
        return CardCreated(Card.fromJson(data));
      case 'card_updated':
        return CardUpdated(Card.fromJson(data));
      case 'card_moved':
        return CardMoved(Card.fromJson(data));
      case 'card_deleted':
        return CardDeleted(data['id'] as String);
      case 'list_created':
        return const ListChanged();
      case 'list_updated':
        return const ListChanged();
      case 'list_deleted':
        return const ListChanged();
      default:
        return null;
    }
  }
}

class CardCreated extends BoardEvent {
  final Card card;
  const CardCreated(this.card);
}

class CardUpdated extends BoardEvent {
  final Card card;
  const CardUpdated(this.card);
}

class CardMoved extends BoardEvent {
  final Card card;
  const CardMoved(this.card);
}

class CardDeleted extends BoardEvent {
  final String cardId;
  const CardDeleted(this.cardId);
}

/// Catch-all for list mutations — phase 0 reloads the board on these rather
/// than reconciling per-event. Refine when list editing matures.
class ListChanged extends BoardEvent {
  const ListChanged();
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
              final ev = BoardEvent.fromRaw(eventName, decoded);
              if (ev != null) yield ev;
              // else: unknown event type — server is ahead of client; ignore.
            }
          } catch (e) {
            // Skip malformed frames but surface in debug mode so we notice
            // protocol drift early.
            assert(() {
              // ignore: avoid_print
              print('[SseClient] dropped malformed frame "$eventName": $e');
              return true;
            }());
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
