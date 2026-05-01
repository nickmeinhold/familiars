import 'package:drift/drift.dart';

import '../db/database.dart';
import '../events/board_event_bus.dart';
import 'lists_repo.dart';
import '../util/ulid.dart';

/// Raised when a card op references a non-existent list.
class ListNotFoundException implements Exception {
  /// The list id that was missing.
  final String id;

  /// Construct.
  ListNotFoundException(this.id);

  @override
  String toString() => 'ListNotFoundException($id)';
}

/// Thin wrapper over Drift for the Cards table. Publishes
/// `card_created` / `card_updated` / `card_deleted` / `card_moved` events
/// on the [BoardEventBus] when mutations succeed.
class CardsRepo {
  final AppDatabase _db;
  final BoardEventBus _bus;

  /// Construct.
  CardsRepo(this._db, this._bus);

  /// Fetch by id, or `null`.
  Future<Card?> findById(String id) {
    return (_db.select(_db.cards)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
  }

  /// Create a card. The card is placed under [listId] (which must exist and
  /// belong to [boardId]). Position defaults to (max + 1.0) within the list.
  ///
  /// Throws [ListNotFoundException] / [BoardNotFoundException] if those
  /// references are bad — the router maps these to 404.
  Future<Card> create({
    required String boardId,
    required String listId,
    required String title,
    String? description,
    double? position,
    String? prompt,
  }) async {
    // Validate list exists AND belongs to the requested board. The latter
    // matters because the URL has the boardId; a client supplying a listId
    // from a different board is a bug, not a silent move.
    final list = await (_db.select(_db.lists)
          ..where((t) => t.id.equals(listId)))
        .getSingleOrNull();
    if (list == null) {
      throw ListNotFoundException(listId);
    }
    if (list.boardId != boardId) {
      throw BoardNotFoundException(boardId);
    }
    final pos = position ?? await _nextPositionInList(listId);
    final card = Card(
      id: newUlid(),
      listId: listId,
      title: title,
      description: description,
      position: pos,
      createdAt: DateTime.now().millisecondsSinceEpoch,
      prUrl: null,
      mediaKey: null,
      prompt: prompt,
    );
    await _db.into(_db.cards).insert(card);
    _bus.publish(boardId, BoardEvent('card_created', card.toJson()));
    return card;
  }

  /// Update a card. Any combination of fields may be supplied.
  ///
  /// If [listId] is supplied and differs from the existing list, a
  /// `card_moved` event fires (in addition to the underlying update). If
  /// only the position changes within the same list, a `card_updated` event
  /// fires — clients can treat both shapes as "re-render this card".
  ///
  /// Returns the updated card, or `null` if [id] was not found.
  Future<Card?> update(
    String id, {
    String? title,
    Object? description = _absent,
    String? listId,
    double? position,
    Object? prompt = _absent,
    Object? prUrl = _absent,
    Object? mediaKey = _absent,
  }) async {
    final existing = await findById(id);
    if (existing == null) return null;

    // If listId changes, validate destination exists and is on the same
    // board. Cross-board moves are out of scope for Phase 0.
    final destListId = listId ?? existing.listId;
    BoardList? destList;
    if (listId != null && listId != existing.listId) {
      destList = await (_db.select(_db.lists)
            ..where((t) => t.id.equals(listId)))
          .getSingleOrNull();
      if (destList == null) {
        throw ListNotFoundException(listId);
      }
      // Look up source list's board to compare.
      final sourceList = await (_db.select(_db.lists)
            ..where((t) => t.id.equals(existing.listId)))
          .getSingleOrNull();
      if (sourceList != null && sourceList.boardId != destList.boardId) {
        throw ListNotFoundException(listId);
      }
    }

    final companion = CardsCompanion(
      title: title == null ? const Value.absent() : Value(title),
      description: identical(description, _absent)
          ? const Value.absent()
          : Value(description as String?),
      listId: listId == null ? const Value.absent() : Value(listId),
      position: position == null ? const Value.absent() : Value(position),
      prompt: identical(prompt, _absent)
          ? const Value.absent()
          : Value(prompt as String?),
      prUrl: identical(prUrl, _absent)
          ? const Value.absent()
          : Value(prUrl as String?),
      mediaKey: identical(mediaKey, _absent)
          ? const Value.absent()
          : Value(mediaKey as String?),
    );
    final n = await (_db.update(_db.cards)..where((t) => t.id.equals(id)))
        .write(companion);
    if (n == 0) return null;

    final updated = await findById(id);
    if (updated == null) return null;

    // Resolve the parent board for fan-out. If listId changed, we use the
    // destination board id (which we've validated equals the source).
    final boardId = await _boardIdForList(destListId);
    if (boardId != null) {
      final moved = listId != null && listId != existing.listId;
      _bus.publish(
        boardId,
        BoardEvent(
          moved ? 'card_moved' : 'card_updated',
          updated.toJson(),
        ),
      );
    }
    return updated;
  }

  /// Delete card [id]. Returns `true` if a row was deleted.
  Future<bool> delete(String id) async {
    final card = await findById(id);
    if (card == null) return false;
    final boardId = await _boardIdForList(card.listId);
    final n = await (_db.delete(_db.cards)..where((t) => t.id.equals(id)))
        .go();
    if (n > 0 && boardId != null) {
      _bus.publish(
        boardId,
        BoardEvent(
          'card_deleted',
          {'id': id, 'listId': card.listId, 'boardId': boardId},
        ),
      );
    }
    return n > 0;
  }

  Future<double> _nextPositionInList(String listId) async {
    final maxPos = _db.cards.position.max();
    final query = _db.selectOnly(_db.cards)
      ..addColumns([maxPos])
      ..where(_db.cards.listId.equals(listId));
    final row = await query.getSingleOrNull();
    final current = row?.read(maxPos);
    return (current ?? 0.0) + 1.0;
  }

  Future<String?> _boardIdForList(String listId) async {
    final list = await (_db.select(_db.lists)
          ..where((t) => t.id.equals(listId)))
        .getSingleOrNull();
    return list?.boardId;
  }
}

/// Sentinel for "field not supplied" vs "field set to null" in update calls.
const Object _absent = Object();
