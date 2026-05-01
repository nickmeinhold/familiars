import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../repositories/cards_repo.dart';
import '../repositories/lists_repo.dart';
import 'json_helpers.dart';

/// Sentinel for distinguishing "key absent" from "key present with null".
const Object _absent = Object();

Object? _readOptionalNullable(Map<String, Object?> body, String key) {
  if (!body.containsKey(key)) return _absent;
  return body[key];
}

/// Register the cards endpoints on [router].
///
/// Endpoints (mounted under `/api/`):
///   - `POST   /boards/<bid>/cards` — create.
///     Body: `{listId, title, description?, position?, prompt?}`.
///   - `PATCH  /cards/<id>`         — update / move / reorder.
///     Body: `{title?, description?, listId?, position?, prompt?,
///             prUrl?, mediaKey?}`.
///   - `DELETE /cards/<id>`.
void registerCardsRoutes(Router router, CardsRepo repo) {

  router.post('/boards/<bid>/cards',
      (Request request, String bid) async {
    final Map<String, Object?>? body;
    try {
      body = await decodeJsonBody(request);
    } on FormatException catch (e) {
      return badRequest('malformed json: ${e.message}');
    }
    if (body == null) return badRequest('body required');

    final listId = body['listId'];
    if (listId is! String || listId.isEmpty) {
      return badRequest('listId required');
    }
    final title = body['title'];
    if (title is! String || title.isEmpty) {
      return badRequest('title required');
    }
    final description = body['description'];
    if (description != null && description is! String) {
      return badRequest('description must be a string');
    }
    final position = body['position'];
    if (position != null && position is! num) {
      return badRequest('position must be a number');
    }
    final prompt = body['prompt'];
    if (prompt != null && prompt is! String) {
      return badRequest('prompt must be a string');
    }

    try {
      final card = await repo.create(
        boardId: bid,
        listId: listId,
        title: title,
        description: description as String?,
        position: (position as num?)?.toDouble(),
        prompt: prompt as String?,
      );
      return jsonCreated(card.toJson());
    } on ListNotFoundException {
      return notFound('list not found');
    } on BoardNotFoundException {
      // List exists but belongs to a different board than the URL claims.
      return notFound('list does not belong to this board');
    }
  });

  router.patch('/cards/<id>', (Request request, String id) async {
    final Map<String, Object?>? body;
    try {
      body = await decodeJsonBody(request);
    } on FormatException catch (e) {
      return badRequest('malformed json: ${e.message}');
    }
    if (body == null) return badRequest('body required');

    final title = body['title'];
    if (title != null && title is! String) {
      return badRequest('title must be a string');
    }
    final listId = body['listId'];
    if (listId != null && listId is! String) {
      return badRequest('listId must be a string');
    }
    final position = body['position'];
    if (position != null && position is! num) {
      return badRequest('position must be a number');
    }

    // Nullable fields: distinguish absent (don't touch) from null (clear).
    final description = _readOptionalNullable(body, 'description');
    if (!identical(description, _absent) &&
        description != null &&
        description is! String) {
      return badRequest('description must be a string or null');
    }
    final prompt = _readOptionalNullable(body, 'prompt');
    if (!identical(prompt, _absent) && prompt != null && prompt is! String) {
      return badRequest('prompt must be a string or null');
    }
    final prUrl = _readOptionalNullable(body, 'prUrl');
    if (!identical(prUrl, _absent) && prUrl != null && prUrl is! String) {
      return badRequest('prUrl must be a string or null');
    }
    final mediaKey = _readOptionalNullable(body, 'mediaKey');
    if (!identical(mediaKey, _absent) &&
        mediaKey != null &&
        mediaKey is! String) {
      return badRequest('mediaKey must be a string or null');
    }

    try {
      final updated = await repo.update(
        id,
        title: title as String?,
        listId: listId as String?,
        position: (position as num?)?.toDouble(),
        description: description,
        prompt: prompt,
        prUrl: prUrl,
        mediaKey: mediaKey,
      );
      if (updated == null) return notFound('card not found');
      return jsonOk(updated.toJson());
    } on ListNotFoundException {
      return notFound('destination list not found or on a different board');
    }
  });

  router.delete('/cards/<id>', (Request request, String id) async {
    final ok = await repo.delete(id);
    if (!ok) return notFound('card not found');
    return Response(204);
  });
}
