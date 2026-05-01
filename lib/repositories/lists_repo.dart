import 'package:drift/drift.dart';

import '../db/database.dart';
import '../events/board_event_bus.dart';
import '../util/ulid.dart';

/// Result of a list lookup that needs the parent board id (for SSE
/// fan-out). Returned by [ListsRepo.findWithBoard].
class ListWithBoard {
  /// The list row.
  final BoardList list;

  /// Parent board id (denormalised onto the list itself).
  String get boardId => list.boardId;

  /// Construct.
  ListWithBoard(this.list);
}

/// Thin wrapper over Drift for the Lists table. Publishes
/// `list_created` / `list_updated` / `list_deleted` events on the
/// [BoardEventBus] when mutations succeed.
class ListsRepo {
  final AppDatabase _db;
  final BoardEventBus _bus;

  /// Construct.
  ListsRepo(this._db, this._bus);

  /// Fetch by id, returning `null` if not found.
  Future<BoardList?> findById(String id) {
    return (_db.select(_db.lists)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
  }

  /// Create a list under [boardId]. If [position] is null, the list is
  /// appended (max-position + 1.0).
  ///
  /// Throws a [BoardNotFoundException] if [boardId] does not exist (caught by
  /// the router and mapped to 404).
  Future<BoardList> create({
    required String boardId,
    required String name,
    double? position,
  }) async {
    final board = await (_db.select(_db.boards)
          ..where((t) => t.id.equals(boardId)))
        .getSingleOrNull();
    if (board == null) {
      throw BoardNotFoundException(boardId);
    }
    final pos = position ?? await _nextPosition(boardId);
    final row = BoardList(
      id: newUlid(),
      boardId: boardId,
      name: name,
      position: pos,
    );
    await _db.into(_db.lists).insert(row);
    _bus.publish(boardId, BoardEvent('list_created', row.toJson()));
    return row;
  }

  /// Update list [id] — rename and/or reposition. Returns the updated row,
  /// or `null` if not found.
  Future<BoardList?> update(
    String id, {
    String? name,
    double? position,
  }) async {
    if (name == null && position == null) {
      return findById(id);
    }
    final companion = ListsCompanion(
      name: name == null ? const Value.absent() : Value(name),
      position: position == null ? const Value.absent() : Value(position),
    );
    final n = await (_db.update(_db.lists)..where((t) => t.id.equals(id)))
        .write(companion);
    if (n == 0) return null;
    final updated = await findById(id);
    if (updated != null) {
      _bus.publish(updated.boardId,
          BoardEvent('list_updated', updated.toJson()));
    }
    return updated;
  }

  /// Delete list [id] (cascade-removes its cards). Returns `true` if a row
  /// was deleted.
  Future<bool> delete(String id) async {
    final list = await findById(id);
    if (list == null) return false;
    final n = await (_db.delete(_db.lists)..where((t) => t.id.equals(id)))
        .go();
    if (n > 0) {
      _bus.publish(
        list.boardId,
        BoardEvent('list_deleted', {'id': id, 'boardId': list.boardId}),
      );
    }
    return n > 0;
  }

  Future<double> _nextPosition(String boardId) async {
    final maxPos = _db.lists.position.max();
    final query = _db.selectOnly(_db.lists)
      ..addColumns([maxPos])
      ..where(_db.lists.boardId.equals(boardId));
    final row = await query.getSingleOrNull();
    final current = row?.read(maxPos);
    return (current ?? 0.0) + 1.0;
  }
}

/// Raised when a list operation references a non-existent board.
class BoardNotFoundException implements Exception {
  /// The id that was not found.
  final String id;

  /// Construct.
  BoardNotFoundException(this.id);

  @override
  String toString() => 'BoardNotFoundException($id)';
}
