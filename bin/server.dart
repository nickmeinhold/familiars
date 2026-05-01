import 'dart:async';
import 'dart:io';

import 'package:familiars_server/db/database.dart';
import 'package:familiars_server/middleware/auth.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';

/// Phase 0 entrypoint.
///
/// Routes:
///   - `GET /health` — unauthenticated liveness probe.
///   - `/api/*`     — Firebase-authenticated; protected by [firebaseAuth].
///                     No endpoints exist yet; the prefix is mounted so future
///                     endpoints inherit auth automatically.
///
/// Storage: a Drift-backed SQLite database (boards/lists/cards) opened at
/// startup. Override the path with `FAMILIARS_DB_PATH`
/// (default: `data/familiars.db` relative to cwd).
///
/// Env:
///   - `FIREBASE_PROJECT_ID` (default: `downstream-181e2`) — JWT `aud` / `iss`.
///   - `PORT` (default: `8081`) — HTTP listen port.
Future<void> main() async {
  final dbPath =
      Platform.environment['FAMILIARS_DB_PATH'] ?? 'data/familiars.db';
  final db = AppDatabase.open(dbPath);
  // Force the lazy NativeDatabase open + migration strategy
  // (including `PRAGMA foreign_keys = ON`) by issuing a real query
  // through a generated DAO. A no-op SELECT would also work, but
  // exercising the actual schema makes the intent obvious.
  await db.select(db.boards).get();
  print('drift schema ready (path: $dbPath)');

  final projectId =
      Platform.environment['FIREBASE_PROJECT_ID'] ?? 'downstream-181e2';

  // Catch-all 404 handler on the auth-protected sub-router. Order matters:
  // because this lives *inside* the [firebaseAuth] pipeline below, requests
  // to undefined `/api/*` paths still hit the middleware first and get a
  // 401 if unauthenticated, only reaching this 404 once auth passes. Don't
  // "simplify" by moving the fallback above the mount — it would let
  // unauthenticated callers probe the route surface.
  final apiRouter = Router()
    ..all('/<ignored|.*>', (Request _) => Response.notFound(
          '{"error":"not_found"}',
          headers: {'content-type': 'application/json'},
        ));

  final apiHandler = const Pipeline()
      .addMiddleware(firebaseAuth(projectId: projectId))
      .addHandler(apiRouter.call);

  final root = Router()
    ..get('/health', _healthHandler)
    ..mount('/api/', apiHandler);

  final handler =
      const Pipeline().addMiddleware(logRequests()).addHandler(root.call);

  final port = int.parse(Platform.environment['PORT'] ?? '8081');
  final server =
      await shelf_io.serve(handler, InternetAddress.anyIPv4, port);
  print(
    'familiars-server listening on http://${server.address.host}:${server.port} '
    '(firebase project: $projectId)',
  );

  // Graceful shutdown: close HTTP listener, then the database.
  // SIGTERM is what Docker / systemd send on stop; SIGINT is Ctrl+C.
  Future<void> shutdown(ProcessSignal signal) async {
    print('received $signal, shutting down...');
    await server.close(force: false);
    await db.close();
    exit(0);
  }

  ProcessSignal.sigint.watch().listen(shutdown);
  // SIGTERM listening isn't supported on Windows; guard it.
  if (!Platform.isWindows) {
    ProcessSignal.sigterm.watch().listen(shutdown);
  }
}

Response _healthHandler(Request request) {
  return Response.ok(
    '{"status":"ok","service":"familiars-server","phase":0}\n',
    headers: {'content-type': 'application/json'},
  );
}
