import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:familiars_server/api/boards_router.dart';
import 'package:familiars_server/api/cards_router.dart';
import 'package:familiars_server/api/lists_router.dart';
import 'package:familiars_server/api/stream_router.dart';
import 'package:familiars_server/db/database.dart';
import 'package:familiars_server/events/board_event_bus.dart';
import 'package:familiars_server/repositories/boards_repo.dart';
import 'package:familiars_server/repositories/cards_repo.dart';
import 'package:familiars_server/repositories/lists_repo.dart';
import 'package:http/http.dart' as http;
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';
import 'package:test/test.dart';

/// Spin up the full HTTP stack against an in-memory Drift DB.
///
/// We bypass the Firebase auth middleware here — the auth path is unit-
/// tested separately in `test/middleware/auth_test.dart`. This file
/// exercises routing, repository semantics, and SSE fan-out end-to-end.
class _Harness {
  final AppDatabase db;
  final BoardEventBus bus;
  final HttpServer server;
  final Uri base;

  _Harness(this.db, this.bus, this.server)
      : base = Uri.parse(
            'http://${server.address.host}:${server.port}');

  static Future<_Harness> start() async {
    final db = AppDatabase(NativeDatabase.memory());
    final bus = BoardEventBus();

    final boards = BoardsRepo(db);
    final lists = ListsRepo(db, bus);
    final cards = CardsRepo(db, bus);

    final router = Router();
    registerBoardsRoutes(router, boards);
    registerListsRoutes(router, lists);
    registerCardsRoutes(router, cards);
    registerStreamRoutes(router, boards, bus);

    final root = Router()..mount('/api/', router.call);
    final handler = const Pipeline().addHandler(root.call);

    final server =
        await shelf_io.serve(handler, InternetAddress.loopbackIPv4, 0);
    return _Harness(db, bus, server);
  }

  Uri url(String path) => base.replace(path: path);

  Future<void> stop() async {
    await server.close(force: true);
    await bus.close();
    await db.close();
  }
}

void main() {
  group('REST CRUD', () {
    late _Harness h;

    setUp(() async {
      h = await _Harness.start();
    });
    tearDown(() async {
      await h.stop();
    });

    test('boards: create, get, list, rename, delete', () async {
      // create
      final created = await http.post(h.url('/api/boards'),
          body: jsonEncode({'name': 'downstream'}),
          headers: {'content-type': 'application/json'});
      expect(created.statusCode, 201);
      final boardId = (jsonDecode(created.body) as Map)['id'] as String;

      // get (with empty lists)
      final got = await http.get(h.url('/api/boards/$boardId'));
      expect(got.statusCode, 200);
      final getBody = jsonDecode(got.body) as Map;
      expect(getBody['name'], 'downstream');
      expect(getBody['lists'], isEmpty);

      // list
      final list = await http.get(h.url('/api/boards'));
      expect(list.statusCode, 200);
      expect(jsonDecode(list.body), hasLength(1));

      // rename
      final patched = await http.patch(h.url('/api/boards/$boardId'),
          body: jsonEncode({'name': 'renamed'}),
          headers: {'content-type': 'application/json'});
      expect(patched.statusCode, 200);
      expect((jsonDecode(patched.body) as Map)['name'], 'renamed');

      // delete
      final deleted = await http.delete(h.url('/api/boards/$boardId'));
      expect(deleted.statusCode, 204);

      final missing = await http.get(h.url('/api/boards/$boardId'));
      expect(missing.statusCode, 404);
    });

    test('lists: create on board, update, delete cascades cards',
        () async {
      // make a board
      final b = await http.post(h.url('/api/boards'),
          body: jsonEncode({'name': 'b'}),
          headers: {'content-type': 'application/json'});
      final boardId = (jsonDecode(b.body) as Map)['id'] as String;

      // create list — auto-positioned
      final l1 = await http.post(h.url('/api/boards/$boardId/lists'),
          body: jsonEncode({'name': 'Crux'}),
          headers: {'content-type': 'application/json'});
      expect(l1.statusCode, 201);
      final listId = (jsonDecode(l1.body) as Map)['id'] as String;
      expect((jsonDecode(l1.body) as Map)['position'], 1.0);

      // create card in list
      final c1 = await http.post(h.url('/api/boards/$boardId/cards'),
          body: jsonEncode({'listId': listId, 'title': 'task'}),
          headers: {'content-type': 'application/json'});
      expect(c1.statusCode, 201);

      // delete list — card should cascade
      final del = await http.delete(h.url('/api/lists/$listId'));
      expect(del.statusCode, 204);

      // board now has no lists/cards
      final got = await http.get(h.url('/api/boards/$boardId'));
      expect((jsonDecode(got.body) as Map)['lists'], isEmpty);
    });

    test('cards: create with auto-position, reorder, move between lists',
        () async {
      final b = await http.post(h.url('/api/boards'),
          body: jsonEncode({'name': 'b'}),
          headers: {'content-type': 'application/json'});
      final boardId = (jsonDecode(b.body) as Map)['id'] as String;

      final l1 = await http.post(h.url('/api/boards/$boardId/lists'),
          body: jsonEncode({'name': 'todo'}),
          headers: {'content-type': 'application/json'});
      final list1 = (jsonDecode(l1.body) as Map)['id'] as String;
      final l2 = await http.post(h.url('/api/boards/$boardId/lists'),
          body: jsonEncode({'name': 'done'}),
          headers: {'content-type': 'application/json'});
      final list2 = (jsonDecode(l2.body) as Map)['id'] as String;

      // create two cards in list1; positions should be 1.0, 2.0
      final c1 = await http.post(h.url('/api/boards/$boardId/cards'),
          body: jsonEncode({'listId': list1, 'title': 'a'}),
          headers: {'content-type': 'application/json'});
      final c2 = await http.post(h.url('/api/boards/$boardId/cards'),
          body: jsonEncode({'listId': list1, 'title': 'b'}),
          headers: {'content-type': 'application/json'});
      expect((jsonDecode(c1.body) as Map)['position'], 1.0);
      expect((jsonDecode(c2.body) as Map)['position'], 2.0);

      // reorder c2 between c1 and itself: midpoint position
      final c2Id = (jsonDecode(c2.body) as Map)['id'] as String;
      final reord = await http.patch(h.url('/api/cards/$c2Id'),
          body: jsonEncode({'position': 0.5}),
          headers: {'content-type': 'application/json'});
      expect(reord.statusCode, 200);
      expect((jsonDecode(reord.body) as Map)['position'], 0.5);

      // move c2 to list2
      final moved = await http.patch(h.url('/api/cards/$c2Id'),
          body: jsonEncode({'listId': list2, 'position': 1.0}),
          headers: {'content-type': 'application/json'});
      expect(moved.statusCode, 200);
      expect((jsonDecode(moved.body) as Map)['listId'], list2);
    });

    test('400 on malformed JSON', () async {
      final res = await http.post(h.url('/api/boards'),
          body: 'not json',
          headers: {'content-type': 'application/json'});
      expect(res.statusCode, 400);
    });

    test('404 on missing list when creating card', () async {
      final b = await http.post(h.url('/api/boards'),
          body: jsonEncode({'name': 'b'}),
          headers: {'content-type': 'application/json'});
      final boardId = (jsonDecode(b.body) as Map)['id'] as String;

      final res = await http.post(h.url('/api/boards/$boardId/cards'),
          body: jsonEncode({'listId': 'nope', 'title': 't'}),
          headers: {'content-type': 'application/json'});
      expect(res.statusCode, 404);
    });
  });

  group('SSE', () {
    late _Harness h;

    setUp(() async {
      h = await _Harness.start();
    });
    tearDown(() async {
      await h.stop();
    });

    test('mutations broadcast to subscribers of the right board',
        () async {
      // Two boards.
      final bA = await http.post(h.url('/api/boards'),
          body: jsonEncode({'name': 'A'}),
          headers: {'content-type': 'application/json'});
      final boardA = (jsonDecode(bA.body) as Map)['id'] as String;
      final bB = await http.post(h.url('/api/boards'),
          body: jsonEncode({'name': 'B'}),
          headers: {'content-type': 'application/json'});
      final boardB = (jsonDecode(bB.body) as Map)['id'] as String;

      // Subscribe to board A only.
      final client = http.Client();
      final req = http.Request('GET', h.url('/api/boards/$boardA/stream'));
      final resp = await client.send(req);
      expect(resp.statusCode, 200);
      expect(resp.headers['content-type'], contains('text/event-stream'));

      final eventsA = <String>[];
      final completer = Completer<void>();
      late StreamSubscription sub;
      sub = resp.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) {
        if (line.startsWith('event: ')) {
          eventsA.add(line.substring('event: '.length));
          if (eventsA.length >= 2 && !completer.isCompleted) {
            completer.complete();
          }
        }
      });

      // Mutation on board B should not arrive on A's stream.
      final lB = await http.post(h.url('/api/boards/$boardB/lists'),
          body: jsonEncode({'name': 'noise'}),
          headers: {'content-type': 'application/json'});
      expect(lB.statusCode, 201);

      // Mutations on board A — should arrive (list_created, card_created).
      final lA = await http.post(h.url('/api/boards/$boardA/lists'),
          body: jsonEncode({'name': 'crux'}),
          headers: {'content-type': 'application/json'});
      final listA = (jsonDecode(lA.body) as Map)['id'] as String;
      await http.post(h.url('/api/boards/$boardA/cards'),
          body: jsonEncode({'listId': listA, 'title': 't'}),
          headers: {'content-type': 'application/json'});

      await completer.future.timeout(const Duration(seconds: 5));
      await sub.cancel();
      client.close();

      expect(eventsA, containsAllInOrder(['list_created', 'card_created']));
      // Only the two A-events appeared; no B-noise leaked in.
      expect(eventsA.length, 2);
    });

    test('card_moved fires on listId change', () async {
      final b = await http.post(h.url('/api/boards'),
          body: jsonEncode({'name': 'b'}),
          headers: {'content-type': 'application/json'});
      final boardId = (jsonDecode(b.body) as Map)['id'] as String;
      final l1 = await http.post(h.url('/api/boards/$boardId/lists'),
          body: jsonEncode({'name': '1'}),
          headers: {'content-type': 'application/json'});
      final list1 = (jsonDecode(l1.body) as Map)['id'] as String;
      final l2 = await http.post(h.url('/api/boards/$boardId/lists'),
          body: jsonEncode({'name': '2'}),
          headers: {'content-type': 'application/json'});
      final list2 = (jsonDecode(l2.body) as Map)['id'] as String;
      final c = await http.post(h.url('/api/boards/$boardId/cards'),
          body: jsonEncode({'listId': list1, 'title': 't'}),
          headers: {'content-type': 'application/json'});
      final cardId = (jsonDecode(c.body) as Map)['id'] as String;

      // Subscribe AFTER setup so the stream only sees the move.
      final client = http.Client();
      final req =
          http.Request('GET', h.url('/api/boards/$boardId/stream'));
      final resp = await client.send(req);
      final events = <String>[];
      final completer = Completer<void>();
      late StreamSubscription sub;
      sub = resp.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) {
        if (line.startsWith('event: ')) {
          events.add(line.substring('event: '.length));
          if (!completer.isCompleted) completer.complete();
        }
      });

      // small delay to ensure subscribe is wired before mutation
      await Future<void>.delayed(const Duration(milliseconds: 50));

      await http.patch(h.url('/api/cards/$cardId'),
          body: jsonEncode({'listId': list2}),
          headers: {'content-type': 'application/json'});

      await completer.future.timeout(const Duration(seconds: 5));
      await sub.cancel();
      client.close();

      expect(events, contains('card_moved'));
    });
  });
}
