import 'package:drift/drift.dart';

import '../db/database.dart';
import '../util/ulid.dart';

/// Thin wrapper over Drift for the Boards table.
///
/// Boards have no SSE events in Phase 0 (board lifecycle is rare and a
/// separate concern from the per-board mutation stream), so this repo does
/// not take a [BoardEventBus]. Lists and cards do.
class BoardsRepo {
  final AppDatabase _db;

  /// Construct against [_db].
  BoardsRepo(this._db);

  /// List all boards, ordered by creation time (oldest first).
  Future<List<Board>> listAll() {
    final query = _db.select(_db.boards)
      ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]);
    return query.get();
  }

  /// Fetch a single board by id; returns `null` if not found.
  Future<Board?> findById(String id) {
    return (_db.select(_db.boards)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
  }

  /// Create a board with the given [name]. Returns the inserted [Board].
  Future<Board> create({required String name}) async {
    final board = Board(
      id: newUlid(),
      name: name,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );
    await _db.into(_db.boards).insert(board);
    return board;
  }

  /// Rename board [id]. Returns the updated row, or `null` if not found.
  Future<Board?> rename(String id, String name) async {
    final updated = await (_db.update(_db.boards)
          ..where((t) => t.id.equals(id)))
        .write(BoardsCompanion(name: Value(name)));
    if (updated == 0) return null;
    return findById(id);
  }

  /// Delete board [id]. Returns `true` if a row was deleted.
  /// Cascade-deletes lists and cards via FK ON DELETE CASCADE.
  Future<bool> delete(String id) async {
    final n = await (_db.delete(_db.boards)..where((t) => t.id.equals(id)))
        .go();
    return n > 0;
  }

  /// Lists belonging to [boardId], ordered by position.
  Future<List<BoardList>> listsFor(String boardId) {
    return (_db.select(_db.lists)
          ..where((t) => t.boardId.equals(boardId))
          ..orderBy([(t) => OrderingTerm.asc(t.position)]))
        .get();
  }

  /// Cards belonging to any of [listIds], ordered by position within their
  /// list. Returns a flat list — caller groups by `listId`.
  Future<List<Card>> cardsForLists(List<String> listIds) {
    if (listIds.isEmpty) return Future.value(const []);
    return (_db.select(_db.cards)
          ..where((t) => t.listId.isIn(listIds))
          ..orderBy([(t) => OrderingTerm.asc(t.position)]))
        .get();
  }
}
