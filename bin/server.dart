import 'dart:async';
import 'dart:io';

import 'package:familiars_server/api/boards_router.dart';
import 'package:familiars_server/api/cards_router.dart';
import 'package:familiars_server/api/lists_router.dart';
import 'package:familiars_server/api/stream_router.dart';
import 'package:familiars_server/db/database.dart';
import 'package:familiars_server/events/board_event_bus.dart';
import 'package:familiars_server/middleware/auth.dart';
import 'package:familiars_server/repositories/boards_repo.dart';
import 'package:familiars_server/repositories/cards_repo.dart';
import 'package:familiars_server/repositories/lists_repo.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';

/// Phase 0 entrypoint.
///
/// Routes:
///   - `GET /health`             — unauthenticated liveness probe.
///   - `/api/boards`             — boards CRUD.
///   - `/api/boards/<id>`        — board fetch / rename / delete.
///   - `/api/boards/<bid>/lists` — list creation under a board.
///   - `/api/lists/<id>`         — list update / delete.
///   - `/api/boards/<bid>/cards` — card creation under a board.
///   - `/api/cards/<id>`         — card update / delete.
///   - `/api/boards/<id>/stream` — SSE stream of mutations on this board.
///
/// All `/api/*` routes are guarded by [firebaseAuth].
///
/// Storage: a Drift-backed SQLite database (boards/lists/cards) opened at
/// startup. Override the path with `FAMILIARS_DB_PATH`
/// (default: `data/familiars.db` relative to cwd).
///
/// Env:
///   - `FIREBASE_PROJECT_ID` (default: `downstream-181e2`) — JWT `aud`/`iss`.
///   - `FAMILIARS_TEST_MODE=1` — bypass Firebase auth (uid set to "test").
///     Intended for local smoke tests; do NOT enable in production.
///   - `PORT` (default: `8081`) — HTTP listen port.
Future<void> main() async {
  final dbPath =
      Platform.environment['FAMILIARS_DB_PATH'] ?? 'data/familiars.db';
  final db = AppDatabase.open(dbPath);
  // Force the lazy NativeDatabase open + migration strategy
  // (including `PRAGMA foreign_keys = ON`) by issuing a real query
  // through a generated DAO.
  await db.select(db.boards).get();
  print('drift schema ready (path: $dbPath)');

  final projectId =
      Platform.environment['FIREBASE_PROJECT_ID'] ?? 'downstream-181e2';
  final testMode = Platform.environment['FAMILIARS_TEST_MODE'] == '1';

  final bus = BoardEventBus();
  final boardsRepo = BoardsRepo(db);
  final listsRepo = ListsRepo(db, bus);
  final cardsRepo = CardsRepo(db, bus);

  final apiHandler = const Pipeline()
      .addMiddleware(testMode ? _testAuthBypass() : firebaseAuth(projectId: projectId))
      .addHandler(buildApiRouter(boardsRepo, listsRepo, cardsRepo, bus).call);

  final root = Router()
    ..get('/health', _healthHandler)
    ..mount('/api/', apiHandler);

  final handler =
      const Pipeline().addMiddleware(logRequests()).addHandler(root.call);

  final port = int.parse(Platform.environment['PORT'] ?? '8081');
  final server =
      await shelf_io.serve(handler, InternetAddress.anyIPv4, port);
  if (testMode) {
    print('WARNING: FAMILIARS_TEST_MODE=1 — auth is BYPASSED.');
  }
  print(
    'familiars-server listening on http://${server.address.host}:${server.port} '
    '(firebase project: $projectId)',
  );

  // Graceful shutdown.
  Future<void> shutdown(ProcessSignal signal) async {
    print('received $signal, shutting down...');
    await server.close(force: false);
    await bus.close();
    await db.close();
    exit(0);
  }

  ProcessSignal.sigint.watch().listen(shutdown);
  if (!Platform.isWindows) {
    ProcessSignal.sigterm.watch().listen(shutdown);
  }
}

/// Compose the four sub-router builders into a single API [Router]. Each
/// builder registers its own routes on the shared [Router] passed in. This
/// keeps the `/boards/<bid>/...` namespace owned by a single Router (which
/// is what shelf_router needs — `mount` on overlapping prefixes is awkward).
///
/// The trailing catch-all returns a JSON 404 for any path that didn't
/// match, so authenticated callers probing the route surface get a useful
/// response.
Router buildApiRouter(
  BoardsRepo boardsRepo,
  ListsRepo listsRepo,
  CardsRepo cardsRepo,
  BoardEventBus bus,
) {
  final router = Router();
  registerBoardsRoutes(router, boardsRepo);
  registerListsRoutes(router, listsRepo);
  registerCardsRoutes(router, cardsRepo);
  registerStreamRoutes(router, boardsRepo, bus);

  router.all('/<ignored|.*>', (Request _) => Response.notFound(
        '{"error":"not_found"}',
        headers: {'content-type': 'application/json'},
      ));

  return router;
}

/// Test-only middleware that injects a fake uid. Gated behind
/// [Platform.environment]'s `FAMILIARS_TEST_MODE=1` in [main].
Middleware _testAuthBypass() {
  return (Handler inner) {
    return (Request request) {
      final updated = request.change(
        context: {...request.context, 'uid': 'test'},
      );
      return inner(updated);
    };
  };
}

Response _healthHandler(Request request) {
  return Response.ok(
    '{"status":"ok","service":"familiars-server","phase":0}\n',
    headers: {'content-type': 'application/json'},
  );
}
