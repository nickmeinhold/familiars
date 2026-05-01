import 'dart:async';
import 'dart:io';

import 'package:familiars_server/db/database.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';

/// Phase 0 entrypoint — minimal Shelf server with /health and a
/// Drift-backed SQLite database holding boards/lists/cards.
/// Familiars/runs/SSE/auth land in subsequent phases.
///
/// Override the database path with `FAMILIARS_DB_PATH`
/// (default: `data/familiars.db` relative to cwd). Override the
/// HTTP port with `PORT` (default: 8081).
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

  final router = Router()..get('/health', _healthHandler);

  final handler = const Pipeline()
      .addMiddleware(logRequests())
      .addHandler(router.call);

  final port = int.parse(Platform.environment['PORT'] ?? '8081');
  final server =
      await shelf_io.serve(handler, InternetAddress.anyIPv4, port);
  print('familiars-server listening on http://${server.address.host}:${server.port}');

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
