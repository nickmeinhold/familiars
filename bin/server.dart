import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';

/// Phase 0 entrypoint — just enough to flip the live 502 into a 200.
/// Boards/lists/cards/SSE/auth all land in subsequent steps.
Future<void> main() async {
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
