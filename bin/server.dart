import 'dart:io';

import 'package:familiars_server/db/database.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';

/// Phase 0 entrypoint — minimal Shelf server with /health and a
/// Drift-backed SQLite database holding boards/lists/cards.
/// Familiars/runs/SSE/auth land in subsequent phases.
Future<void> main() async {
  final dbPath = Platform.environment['FAMILIARS_DB_PATH'] ?? 'data/familiars.db';
  final db = AppDatabase.open(dbPath);
  // Touch the database so schema migrations actually run on boot.
  await db.customSelect('SELECT 1').get();
  print('drift schema ready (path: $dbPath)');

  final router = Router()..get('/health', _healthHandler);

  final handler = const Pipeline()
      .addMiddleware(logRequests())
      .addHandler(router.call);

  final port = int.parse(Platform.environment['PORT'] ?? '8081');
  final server =
      await shelf_io.serve(handler, InternetAddress.anyIPv4, port);
  print('familiars-server listening on http://${server.address.host}:${server.port}');
}

Response _healthHandler(Request request) {
  return Response.ok(
    '{"status":"ok","service":"familiars-server","phase":0}\n',
    headers: {'content-type': 'application/json'},
  );
}
