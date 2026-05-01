import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../repositories/boards_repo.dart';
import 'json_helpers.dart';

/// Register the boards endpoints on [router].
///
/// Endpoints (mounted under `/api/`):
///   - `GET    /boards`          — list all boards.
///   - `POST   /boards`          — create a board. Body: `{name}`.
///   - `GET    /boards/<id>`     — board with nested lists and cards.
///   - `PATCH  /boards/<id>`     — rename. Body: `{name?}`.
///   - `DELETE /boards/<id>`     — cascade-deletes lists and cards.
void registerBoardsRoutes(Router router, BoardsRepo repo) {

  router.get('/boards', (Request request) async {
    final boards = await repo.listAll();
    return jsonOk(boards.map((b) => b.toJson()).toList());
  });

  router.post('/boards', (Request request) async {
    final Map<String, Object?>? body;
    try {
      body = await decodeJsonBody(request);
    } on FormatException catch (e) {
      return badRequest('malformed json: ${e.message}');
    }
    final name = body?['name'];
    if (name is! String || name.isEmpty) {
      return badRequest('name required');
    }
    final board = await repo.create(name: name);
    return jsonCreated(board.toJson());
  });

  router.get('/boards/<id>', (Request request, String id) async {
    final board = await repo.findById(id);
    if (board == null) return notFound('board not found');
    final lists = await repo.listsFor(id);
    final cards = await repo.cardsForLists(lists.map((l) => l.id).toList());
    final cardsByList = <String, List<Map<String, Object?>>>{};
    for (final c in cards) {
      cardsByList.putIfAbsent(c.listId, () => []).add(c.toJson());
    }
    return jsonOk({
      ...board.toJson(),
      'lists': [
        for (final l in lists)
          {
            ...l.toJson(),
            'cards': cardsByList[l.id] ?? const [],
          },
      ],
    });
  });

  router.patch('/boards/<id>', (Request request, String id) async {
    final Map<String, Object?>? body;
    try {
      body = await decodeJsonBody(request);
    } on FormatException catch (e) {
      return badRequest('malformed json: ${e.message}');
    }
    final name = body?['name'];
    if (name != null && name is! String) {
      return badRequest('name must be a string');
    }
    if (name == null) {
      // No-op: mirror current state without writing.
      final board = await repo.findById(id);
      if (board == null) return notFound('board not found');
      return jsonOk(board.toJson());
    }
    final updated = await repo.rename(id, name as String);
    if (updated == null) return notFound('board not found');
    return jsonOk(updated.toJson());
  });

  router.delete('/boards/<id>', (Request request, String id) async {
    final ok = await repo.delete(id);
    if (!ok) return notFound('board not found');
    return Response(204);
  });
}
