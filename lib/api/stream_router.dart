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

/// Cumulative cap on bytes enqueued per subscriber before the response is
/// force-closed. Because we can't directly observe the underlying TCP
/// socket's drain in shelf_io, this is a conservative session-lifetime
/// counter: a stalled client will trip the cap quickly (its enqueued
/// bytes pile up server-side); a healthy client will eventually trip it
/// too and reconnect, which is fine.
///
/// 8 MB ≈ 40k SSE events at ~200 bytes/event. Healthy sessions take many
/// hours of constant editing to reach this; stalled sessions saturate it
/// in seconds once mutations are flowing. A thousand stalled clients
/// caps process-wide buffering at ~8 GB which still beats unbounded.
/// Future work: wire a real backpressure-aware sink.
const int _maxBufferedBytes = 8 * 1024 * 1024;

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

    // We can't directly observe the shelf_io socket's drain rate, so we
    // approximate via a session-cumulative byte counter and force-close
    // the response if we've enqueued more than [_maxBufferedBytes] worth
    // since the last successful drain. The counter resets on every
    // event we *know* was delivered… which is "never" with a vanilla
    // StreamController. This is a deliberate approximation: we accept
    // that a long-lived healthy session will eventually trip the cap and
    // reconnect; the alternative (unbounded buffering) is worse. The cap
    // is sized so a healthy session takes hours of constant editing to
    // reach it. Future work: wire a real backpressure-aware sink.
    final controller = StreamController<List<int>>();
    var bytesEnqueuedThisSession = 0;
    var closedForOverflow = false;

    void enqueue(List<int> bytes) {
      if (controller.isClosed || closedForOverflow) return;
      if (bytesEnqueuedThisSession + bytes.length > _maxBufferedBytes) {
        closedForOverflow = true;
        controller.close();
        return;
      }
      bytesEnqueuedThisSession += bytes.length;
      controller.add(bytes);
    }

    final sub = bus.subscribe(id).listen((event) {
      final payload = StringBuffer()
        ..write('event: ${event.type}\n')
        ..write('data: ${jsonEncode(event.data)}\n\n');
      enqueue(utf8.encode(payload.toString()));
    });

    // Initial comment so clients see a complete chunked message right away;
    // also flushes intermediary buffers (some proxies wait for the first
    // byte before starting to stream).
    enqueue(utf8.encode(': connected\n\n'));

    final keepalive = Timer.periodic(_keepaliveInterval, (_) {
      enqueue(utf8.encode(': keepalive\n\n'));
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
