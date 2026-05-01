import 'dart:async';

/// A single event emitted by a board mutation.
///
/// `type` is one of the documented SSE event names:
///   `card_created`, `card_updated`, `card_deleted`, `card_moved`,
///   `list_created`, `list_updated`, `list_deleted`.
///
/// `data` is the JSON-serialisable payload for the event.
class BoardEvent {
  /// Event type — see class doc.
  final String type;

  /// JSON-serialisable payload.
  final Map<String, Object?> data;

  /// Construct a [BoardEvent].
  BoardEvent(this.type, this.data);
}

/// In-process pub/sub keyed by board id.
///
/// Repositories publish [BoardEvent]s on mutation; the SSE router subscribes
/// per request. There is one broadcast [StreamController] per board that has
/// at least one publish or subscribe call against it; controllers stay open
/// for the lifetime of the bus (boards are long-lived; subscriber count
/// fluctuating between 0 and N is fine).
///
/// Not safe across isolates — Phase 0 runs a single-process server, which is
/// the assumption baked in everywhere else (Drift over a single SQLite file,
/// etc).
class BoardEventBus {
  final Map<String, StreamController<BoardEvent>> _controllers = {};

  /// Subscribe to events for [boardId]. The returned stream is broadcast;
  /// multiple SSE connections to the same board share the same controller.
  Stream<BoardEvent> subscribe(String boardId) {
    return _controllerFor(boardId).stream;
  }

  /// Publish [event] to subscribers of [boardId]. No-op if there are no
  /// subscribers — the controller is created lazily so the first publish is
  /// not lost if a subscribe arrives later, but events published *before* a
  /// subscriber attaches are dropped (broadcast streams have no buffer).
  void publish(String boardId, BoardEvent event) {
    final ctrl = _controllerFor(boardId);
    if (!ctrl.isClosed) ctrl.add(event);
  }

  /// Close every per-board controller. Call on graceful shutdown so pending
  /// SSE connections see their streams complete.
  Future<void> close() async {
    for (final c in _controllers.values) {
      await c.close();
    }
    _controllers.clear();
  }

  StreamController<BoardEvent> _controllerFor(String boardId) {
    return _controllers.putIfAbsent(
      boardId,
      () => StreamController<BoardEvent>.broadcast(),
    );
  }
}
