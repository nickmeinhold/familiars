import 'dart:async';

import 'package:flutter/material.dart' hide Card;
import 'package:flutter/material.dart' as m show Card;

import '../models/board.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../services/sse_client.dart';

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
  /// are ignored to avoid fighting with the user's gesture.
  final Set<String> _activeDragIds = {};

  @override
  void initState() {
    super.initState();
    _sse = SseClient(auth: widget.auth);
    _load();
  }

  @override
  void dispose() {
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
      _onSseEvent,
      onError: (Object err) {
        // Reconnect after a short delay; keeps the screen useful through
        // transient network blips.
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) _connectSse();
        });
      },
      onDone: () {
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) _connectSse();
        });
      },
    );
  }

  void _onSseEvent(BoardEvent ev) {
    final board = _board;
    if (board == null) return;
    final data = ev.data;
    setState(() {
      switch (ev.type) {
        case 'card_created':
          _applyCardUpsert(board, Card.fromJson(data));
          break;
        case 'card_updated':
          _applyCardUpsert(board, Card.fromJson(data));
          break;
        case 'card_moved':
          final id = data['id'] as String?;
          if (id == null || _activeDragIds.contains(id)) break;
          _applyCardUpsert(board, Card.fromJson(data));
          break;
        case 'card_deleted':
          final id = data['id'] as String?;
          if (id != null) _applyCardDelete(board, id);
          break;
        case 'list_created':
        case 'list_updated':
        case 'list_deleted':
          // Phase 0 keeps lists static — refetch lazily for these.
          _load();
          break;
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

    setState(() {
      _activeDragIds.add(cardId);
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
      if (mounted) {
        setState(() => _activeDragIds.remove(cardId));
      }
    }
  }

  Future<void> _addCardToList(BoardList list) async {
    final title = await _promptForText(
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
      // SSE will reconcile, but reload to be safe in case stream is dropped.
      await _load();
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
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Save failed: $e')),
      );
    }
  }

  Future<void> _addList() async {
    final name = await _promptForText(
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
      await _load();
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

/// The drop target for a lane. Hosts the cards as draggables and accepts drops
/// at any vertical position — the index is computed from the current pointer
/// position relative to the laid-out cards.
class _CardListDropZone extends StatefulWidget {
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
  State<_CardListDropZone> createState() => _CardListDropZoneState();
}

class _CardListDropZoneState extends State<_CardListDropZone> {
  /// Index where a hovering card would land if dropped right now, or null.
  int? _hoverIndex;

  @override
  Widget build(BuildContext context) {
    final cards = widget.list.cards;
    return DragTarget<_CardDragPayload>(
      onWillAcceptWithDetails: (_) => true,
      onMove: (details) {
        // Find which card the pointer is currently over and snap to insert
        // before/after it. We don't have per-card render boxes here so use a
        // simple uniform-height approximation tied to the listview's layout.
        final box = context.findRenderObject() as RenderBox?;
        if (box == null) return;
        final local = box.globalToLocal(details.offset);
        const cardHeight = 64.0;
        final idx = (local.dy / cardHeight).round().clamp(0, cards.length);
        if (_hoverIndex != idx) setState(() => _hoverIndex = idx);
      },
      onLeave: (_) => setState(() => _hoverIndex = null),
      onAcceptWithDetails: (details) {
        final payload = details.data;
        final idx = _hoverIndex ?? cards.length;
        setState(() => _hoverIndex = null);
        widget.onCardDropped(
          cardId: payload.card.id,
          fromListId: payload.fromListId,
          toListId: widget.list.id,
          toIndex: idx,
        );
      },
      builder: (context, candidate, rejected) {
        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          itemCount: cards.length,
          itemBuilder: (_, i) => _DraggableCard(
            card: cards[i],
            fromListId: widget.list.id,
            onTap: () => widget.onTap(cards[i]),
            highlightAbove: _hoverIndex == i,
          ),
        );
      },
    );
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
  final bool highlightAbove;

  const _DraggableCard({
    required this.card,
    required this.fromListId,
    required this.onTap,
    required this.highlightAbove,
  });

  @override
  Widget build(BuildContext context) {
    final tile = m.Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
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
    return Column(
      children: [
        if (highlightAbove)
          Container(
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 2),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        LongPressDraggable<_CardDragPayload>(
          data: _CardDragPayload(card: card, fromListId: fromListId),
          feedback: Material(
            elevation: 6,
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(width: 260, child: tile),
          ),
          childWhenDragging: Opacity(opacity: 0.3, child: tile),
          child: tile,
        ),
      ],
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

Future<String?> _promptForText({
  required BuildContext context,
  required String title,
  required String hint,
}) async {
  final controller = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: InputDecoration(hintText: hint),
        onSubmitted: (v) => Navigator.of(ctx).pop(v),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(controller.text),
          child: const Text('Save'),
        ),
      ],
    ),
  );
}
