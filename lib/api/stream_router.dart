import 'dart:async';
import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../events/board_event_bus.dart';
import '../repositories/boards_repo.dart';
import 'json_helpers.dart';

/// Keepalive comment interval. Most reverse proxies idle out long-lived
/// HTTP/1.1 responses after 30-60s; 25s is a comfortable margin.
const Duration _keepaliveInterval = Duration(seconds: 25);

/// Register the SSE endpoint on [router].
///
/// Endpoint (mounted under `/api/`):
///   - `GET /boards/<id>/stream` — `text/event-stream` of mutations
///     scoped to that board.
///
/// Event types: `card_created`, `card_updated`, `card_deleted`,
/// `card_moved`, `list_created`, `list_updated`, `list_deleted`.
///
/// Each SSE message is wire-formatted as
///   `event: <type>\ndata: <json>\n\n`
/// per https://html.spec.whatwg.org/multipage/server-sent-events.html.
/// A `: keepalive\n\n` comment fires every [_keepaliveInterval] to defeat
/// idle proxy timeouts.
void registerStreamRoutes(
  Router router,
  BoardsRepo boards,
  BoardEventBus bus,
) {

  router.get('/boards/<id>/stream', (Request request, String id) async {
    final board = await boards.findById(id);
    if (board == null) return notFound('board not found');

    final controller = StreamController<List<int>>();
    final sub = bus.subscribe(id).listen((event) {
      if (controller.isClosed) return;
      final payload = StringBuffer()
        ..write('event: ${event.type}\n')
        ..write('data: ${jsonEncode(event.data)}\n\n');
      controller.add(utf8.encode(payload.toString()));
    });

    // Initial comment so clients see a complete chunked message right away;
    // also flushes intermediary buffers (some proxies wait for the first
    // byte before starting to stream).
    controller.add(utf8.encode(': connected\n\n'));

    final keepalive = Timer.periodic(_keepaliveInterval, (_) {
      if (controller.isClosed) return;
      controller.add(utf8.encode(': keepalive\n\n'));
    });

    // Tear down when the client goes away. shelf surfaces disconnects via
    // controller.onCancel — once the response stream is no longer being
    // drained, this fires.
    controller.onCancel = () async {
      keepalive.cancel();
      await sub.cancel();
    };

    return Response.ok(
      controller.stream,
      headers: {
        'content-type': 'text/event-stream',
        'cache-control': 'no-cache',
        'connection': 'keep-alive',
        // Hint to nginx-style proxies not to buffer.
        'x-accel-buffering': 'no',
      },
      context: {'shelf.io.buffer_output': false},
    );
  });
}
