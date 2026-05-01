import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../repositories/lists_repo.dart';
import 'json_helpers.dart';

/// Register the lists endpoints on [router].
///
/// Endpoints (mounted under `/api/`):
///   - `POST   /boards/<bid>/lists` — create. Body: `{name, position?}`.
///   - `PATCH  /lists/<id>`         — rename / reposition.
///                                    Body: `{name?, position?}`.
///   - `DELETE /lists/<id>`         — cascade-deletes cards.
void registerListsRoutes(Router router, ListsRepo repo) {

  router.post('/boards/<bid>/lists',
      (Request request, String bid) async {
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
    final positionRaw = body?['position'];
    if (positionRaw != null && positionRaw is! num) {
      return badRequest('position must be a number');
    }
    try {
      final list = await repo.create(
        boardId: bid,
        name: name,
        position: (positionRaw as num?)?.toDouble(),
      );
      return jsonCreated(list.toJson());
    } on BoardNotFoundException {
      return notFound('board not found');
    }
  });

  router.patch('/lists/<id>', (Request request, String id) async {
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
    final position = body?['position'];
    if (position != null && position is! num) {
      return badRequest('position must be a number');
    }
    final updated = await repo.update(
      id,
      name: name as String?,
      position: (position as num?)?.toDouble(),
    );
    if (updated == null) return notFound('list not found');
    return jsonOk(updated.toJson());
  });

  router.delete('/lists/<id>', (Request request, String id) async {
    final ok = await repo.delete(id);
    if (!ok) return notFound('list not found');
    return Response(204);
  });
}
