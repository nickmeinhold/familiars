import 'dart:async';

import 'package:flutter/material.dart' hide Card;
import 'package:flutter/material.dart' as m show Card;

import '../models/board.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../services/sse_client.dart';
import '../widgets/text_prompt.dart';

/// The main proof-point screen: lanes of cards with drag-drop and live SSE.
///
/// State model:
///   - [_board] is the source of truth shown to the user.
///   - Drag-drops mutate [_board] *optimistically* and immediately PATCH the
///     server. On conflict the board is reloaded.
///   - SSE events from the server reconcile [_board] in the background:
///     `card_moved` events whose target card is currently being dragged by
///     this user are ignored; everything else is applied.
class BoardScreen extends StatefulWidget {
  final ApiClient api;
  final AuthService auth;
  final String boardId;
  final String boardName;

  const BoardScreen({
    super.key,
    required this.api,
    required this.auth,
    required this.boardId,
    required this.boardName,
  });

  @override
  State<BoardScreen> createState() => _BoardScreenState();
}

class _BoardScreenState extends State<BoardScreen> {
  Board? _board;
  String? _error;
  late SseClient _sse;
  StreamSubscription<BoardEvent>? _sseSub;

  /// Card ids currently being dragged locally — incoming SSE events for these
  /// are ignored to avoid fighting with the user's gesture. Entries are kept
  /// in the set for a short post-drop dampening window so a late SSE echo
  /// can't re-snap the card after the optimistic update has already landed.
  final Set<String> _activeDragIds = {};

  /// Current SSE reconnect backoff. Reset to [_minReconnect] on a successful
  /// connection (i.e. when we receive any event); doubled on each failure up
  /// to [_maxReconnect]. Prevents hammering the server when it's down.
  Duration _reconnectDelay = _minReconnect;
  static const Duration _minReconnect = Duration(seconds: 2);
  static const Duration _maxReconnect = Duration(seconds: 30);
  Timer? _reconnectTimer;

  @override
  void initState() {
    super.initState();
    _sse = SseClient(auth: widget.auth);
    _load();
  }

  @override
  void dispose() {
    _reconnectTimer?.cancel();
    _sseSub?.cancel();
    _sse.close();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final board = await widget.api.getBoard(widget.boardId);
      if (!mounted) return;
      setState(() => _board = board);
      _connectSse();
    } on UnauthenticatedException {
      await widget.auth.signOut();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '$e');
    }
  }

  void _connectSse() {
    _sseSub?.cancel();
    _sseSub = _sse.connect(widget.boardId).listen(
      (ev) {
        // First successful event resets the backoff window.
        _reconnectDelay = _minReconnect;
        _onSseEvent(ev);
      },
      onError: (Object err) {
        if (err is UnauthenticatedException) {
          // Token expired — bail back to the auth gate rather than spinning.
          widget.auth.signOut();
          return;
        }
        _scheduleReconnect();
      },
      onDone: _scheduleReconnect,
    );
  }

  void _scheduleReconnect() {
    if (!mounted) return;
    _reconnectTimer?.cancel();
    final delay = _reconnectDelay;
    _reconnectTimer = Timer(delay, () {
      if (mounted) _connectSse();
    });
    // Exponential backoff capped at [_maxReconnect].
    final next = delay * 2;
    _reconnectDelay = next > _maxReconnect ? _maxReconnect : next;
  }

  void _onSseEvent(BoardEvent ev) {
    final board = _board;
    if (board == null) return;
    setState(() {
      switch (ev) {
        case CardCreated(:final card) || CardUpdated(:final card):
          _applyCardUpsert(board, card);
        case CardMoved(:final card):
          if (_activeDragIds.contains(card.id)) break;
          _applyCardUpsert(board, card);
        case CardDeleted(:final cardId):
          _applyCardDelete(board, cardId);
        case ListChanged():
          // Phase 0 keeps lists static — refetch lazily for these. Future:
          // reconcile per-event using the typed payload like cards.
          _load();
      }
    });
  }

  void _applyCardUpsert(Board board, Card card) {
    // Remove any existing copy of this card from any list.
    for (final l in board.lists) {
      l.cards.removeWhere((c) => c.id == card.id);
    }
    final dest = board.lists.firstWhere(
      (l) => l.id == card.listId,
      orElse: () => board.lists.first,
    );
    dest.cards
      ..add(card)
      ..sort((a, b) => a.position.compareTo(b.position));
  }

  void _applyCardDelete(Board board, String id) {
    for (final l in board.lists) {
      l.cards.removeWhere((c) => c.id == id);
    }
  }

  /// Compute the position to send when dropping a card at [targetIndex] in a
  /// list whose existing cards are [destCards] (the dragged card already
  /// removed). Uses simple midpoint between neighbours so the server's
  /// position-as-real-number scheme keeps producing well-spaced values.
  double _positionForInsert(List<Card> destCards, int targetIndex) {
    if (destCards.isEmpty) return 1.0;
    if (targetIndex <= 0) return destCards.first.position - 1.0;
    if (targetIndex >= destCards.length) return destCards.last.position + 1.0;
    final before = destCards[targetIndex - 1].position;
    final after = destCards[targetIndex].position;
    return (before + after) / 2.0;
  }

  Future<void> _moveCard({
    required String cardId,
    required String fromListId,
    required String toListId,
    required int toIndex,
  }) async {
    final board = _board;
    if (board == null) return;
    final srcList = board.lists.firstWhere((l) => l.id == fromListId);
    final dstList = board.lists.firstWhere((l) => l.id == toListId);
    final card = srcList.cards.firstWhere((c) => c.id == cardId);

    // Optimistically remove from source.
    final newSrcCards = [...srcList.cards]..removeWhere((c) => c.id == cardId);
    // Compute new position relative to destination *without* the dragged card.
    final dstCardsWithoutDragged =
        dstList.cards.where((c) => c.id != cardId).toList();
    final clampedIdx = toIndex.clamp(0, dstCardsWithoutDragged.length);
    final newPos = _positionForInsert(dstCardsWithoutDragged, clampedIdx);
    final updated = card.copyWith(listId: toListId, position: newPos);

    _activeDragIds.add(cardId);
    setState(() {
      // Replace src list cards
      final lists = [...board.lists];
      final srcIdx = lists.indexWhere((l) => l.id == fromListId);
      lists[srcIdx] = srcList.copyWith(cards: newSrcCards);
      // Insert into dst (could be the same as src, re-fetch after)
      final dstIdx = lists.indexWhere((l) => l.id == toListId);
      final newDstCards = [...lists[dstIdx].cards]
        ..removeWhere((c) => c.id == cardId)
        ..insert(clampedIdx, updated)
        ..sort((a, b) => a.position.compareTo(b.position));
      lists[dstIdx] = lists[dstIdx].copyWith(cards: newDstCards);
      _board = Board(id: board.id, name: board.name, lists: lists);
    });

    try {
      await widget.api.updateCard(
        cardId,
        listId: toListId,
        position: newPos,
      );
    } on ConflictException {
      await _load(); // server says state diverged — reload
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Move failed: $e'),
          action: SnackBarAction(label: 'Retry', onPressed: _load),
        ),
      );
      await _load();
    } finally {
      // Keep the active-drag guard in place briefly so a late SSE echo of
      // our own move can't re-snap the card after the optimistic update has
      // already landed. 500ms is long enough to cover bus latency without
      // delaying genuine remote-origin moves perceptibly.
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          setState(() => _activeDragIds.remove(cardId));
        }
      });
    }
  }

  Future<void> _addCardToList(BoardList list) async {
    final title = await promptForText(
      context: context,
      title: 'New card',
      hint: 'Title',
    );
    if (title == null || title.isEmpty) return;
    final board = _board;
    if (board == null) return;
    final lastPos =
        list.cards.isEmpty ? 1.0 : list.cards.last.position + 1.0;
    try {
      await widget.api.createCard(
        boardId: board.id,
        listId: list.id,
        title: title,
        position: lastPos,
      );
      // SSE delivers the `card_created` event and the screen reconciles
      // through [_onSseEvent]; no explicit reload needed.
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Create failed: $e')),
      );
    }
  }

  Future<void> _editCard(Card card) async {
    final result = await showModalBottomSheet<_CardEditResult>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _CardEditSheet(card: card),
    );
    if (result == null) return;
    try {
      await widget.api.updateCard(
        card.id,
        title: result.title,
        description: result.description,
      );
      // SSE delivers `card_updated` for reconciliation.
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Save failed: $e')),
      );
    }
  }

  Future<void> _addList() async {
    final name = await promptForText(
      context: context,
      title: 'New list',
      hint: 'List name',
    );
    if (name == null || name.isEmpty) return;
    final board = _board;
    if (board == null) return;
    final lastPos =
        board.lists.isEmpty ? 1.0 : board.lists.last.position + 1.0;
    try {
      await widget.api.createList(
        boardId: board.id,
        name: name,
        position: lastPos,
      );
      // ListChanged event triggers a reload via [_onSseEvent].
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Create failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.boardName),
        actions: [
          IconButton(
            tooltip: 'Add list',
            icon: const Icon(Icons.view_column),
            onPressed: _addList,
          ),
          IconButton(
            tooltip: 'Reload',
            icon: const Icon(Icons.refresh),
            onPressed: _load,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Network error: $_error', textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }
    final board = _board;
    if (board == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (board.lists.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('No lists yet — add one to get started.'),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _addList,
                icon: const Icon(Icons.add),
                label: const Text('Add list'),
              ),
            ],
          ),
        ),
      );
    }
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.all(8),
      itemCount: board.lists.length,
      itemBuilder: (_, i) => _LaneWidget(
        list: board.lists[i],
        onAddCard: () => _addCardToList(board.lists[i]),
        onTapCard: _editCard,
        onCardDropped: _moveCard,
      ),
    );
  }
}

class _LaneWidget extends StatelessWidget {
  final BoardList list;
  final VoidCallback onAddCard;
  final void Function(Card) onTapCard;
  final Future<void> Function({
    required String cardId,
    required String fromListId,
    required String toListId,
    required int toIndex,
  }) onCardDropped;

  const _LaneWidget({
    required this.list,
    required this.onAddCard,
    required this.onTapCard,
    required this.onCardDropped,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 280,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 8, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    list.name,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                Text('${list.cards.length}',
                    style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          Expanded(
            child: _CardListDropZone(
              list: list,
              onTap: onTapCard,
              onCardDropped: onCardDropped,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: TextButton.icon(
              onPressed: onAddCard,
              icon: const Icon(Icons.add),
              label: const Text('Add card'),
            ),
          ),
        ],
      ),
    );
  }
}

/// The drop target for a lane.
///
/// Each card is wrapped in a "drop above this index" `DragTarget` (rendered
/// as a thin gap so the visual indicator can light up between cards), with a
/// final "append at end" target after the last card. This means the insert
/// index is whatever target Flutter's hit-testing landed on — no
/// uniform-card-height approximation, no magic numbers.
class _CardListDropZone extends StatelessWidget {
  final BoardList list;
  final void Function(Card) onTap;
  final Future<void> Function({
    required String cardId,
    required String fromListId,
    required String toListId,
    required int toIndex,
  }) onCardDropped;

  const _CardListDropZone({
    required this.list,
    required this.onTap,
    required this.onCardDropped,
  });

  @override
  Widget build(BuildContext context) {
    final cards = list.cards;
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      // One gap-target above each card, plus a tail target at the end.
      itemCount: cards.length + 1,
      itemBuilder: (_, i) {
        if (i == cards.length) {
          // Tail: append-at-end target. Stretches to fill remaining space so
          // dropping into empty whitespace below the last card still works.
          return _GapDropTarget(
            index: cards.length,
            listId: list.id,
            onCardDropped: onCardDropped,
            minHeight: 80,
            expand: true,
          );
        }
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _GapDropTarget(
              index: i,
              listId: list.id,
              onCardDropped: onCardDropped,
            ),
            _DraggableCard(
              card: cards[i],
              fromListId: list.id,
              onTap: () => onTap(cards[i]),
            ),
          ],
        );
      },
    );
  }
}

/// A thin (or expanding) gap between cards that accepts a card-drag and
/// reports its [index] as the insert position. Lights up when a drag hovers
/// over it. Per-target hit-testing replaces the previous magic-number
/// uniform-card-height heuristic.
class _GapDropTarget extends StatefulWidget {
  final int index;
  final String listId;
  final double minHeight;
  final bool expand;
  final Future<void> Function({
    required String cardId,
    required String fromListId,
    required String toListId,
    required int toIndex,
  }) onCardDropped;

  const _GapDropTarget({
    required this.index,
    required this.listId,
    required this.onCardDropped,
    this.minHeight = 8,
    this.expand = false,
  });

  @override
  State<_GapDropTarget> createState() => _GapDropTargetState();
}

class _GapDropTargetState extends State<_GapDropTarget> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final indicator = AnimatedContainer(
      duration: const Duration(milliseconds: 100),
      height: _hover ? 12 : widget.minHeight,
      decoration: BoxDecoration(
        color: _hover
            ? Theme.of(context).colorScheme.primary
            : Colors.transparent,
        borderRadius: BorderRadius.circular(4),
      ),
    );
    final target = DragTarget<_CardDragPayload>(
      onWillAcceptWithDetails: (_) {
        setState(() => _hover = true);
        return true;
      },
      onLeave: (_) => setState(() => _hover = false),
      onAcceptWithDetails: (details) {
        setState(() => _hover = false);
        widget.onCardDropped(
          cardId: details.data.card.id,
          fromListId: details.data.fromListId,
          toListId: widget.listId,
          toIndex: widget.index,
        );
      },
      // The indicator's own height already grows on hover; the surrounding
      // SizedBox in the expand path gives the tail target a generous hit
      // area for "drop into empty whitespace below the last card". Expanded
      // would be wrong here — this widget is a ListView.builder item, not a
      // Flex child, and iOS 26 asserts on the parent-data mismatch.
      builder: (_, __, ___) => indicator,
    );
    if (!widget.expand) return target;
    // 0.6 of the viewport is enough to feel like "the rest of the column"
    // without being so large that the scroll position jumps awkwardly when
    // the list is short.
    final tailHeight = MediaQuery.of(context).size.height * 0.6;
    return SizedBox(height: tailHeight, child: target);
  }
}

class _CardDragPayload {
  final Card card;
  final String fromListId;
  const _CardDragPayload({required this.card, required this.fromListId});
}

class _DraggableCard extends StatelessWidget {
  final Card card;
  final String fromListId;
  final VoidCallback onTap;

  const _DraggableCard({
    required this.card,
    required this.fromListId,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tile = m.Card(
      margin: const EdgeInsets.symmetric(vertical: 2),
      child: ListTile(
        title: Text(card.title),
        subtitle: card.description != null && card.description!.isNotEmpty
            ? Text(
                card.description!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              )
            : null,
        onTap: onTap,
      ),
    );
    return LongPressDraggable<_CardDragPayload>(
      data: _CardDragPayload(card: card, fromListId: fromListId),
      feedback: Material(
        elevation: 6,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(width: 260, child: tile),
      ),
      childWhenDragging: Opacity(opacity: 0.3, child: tile),
      child: tile,
    );
  }
}

class _CardEditResult {
  final String title;
  final String? description;
  const _CardEditResult({required this.title, required this.description});
}

/// Bottom-sheet editor for a card's title + description.
class _CardEditSheet extends StatefulWidget {
  final Card card;
  const _CardEditSheet({required this.card});

  @override
  State<_CardEditSheet> createState() => _CardEditSheetState();
}

class _CardEditSheetState extends State<_CardEditSheet> {
  late final TextEditingController _title =
      TextEditingController(text: widget.card.title);
  late final TextEditingController _desc =
      TextEditingController(text: widget.card.description ?? '');

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + viewInsets),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Edit card',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          TextField(
            controller: _title,
            decoration: const InputDecoration(labelText: 'Title'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _desc,
            maxLines: 4,
            decoration: const InputDecoration(labelText: 'Description'),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(_CardEditResult(
                  title: _title.text,
                  description: _desc.text.isEmpty ? null : _desc.text,
                )),
                child: const Text('Save'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

