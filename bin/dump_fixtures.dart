/// Capture canonical server responses into mobile-side fixture JSON.
///
/// The mobile tests under `mobile/test/contract_fixtures_test.dart`
/// load these files and parse them through `Board.fromJson` etc, so
/// the fixtures are server-generated truth — not hand-crafted maps
/// that risk drifting from what the server actually emits.
///
/// Re-run after any change to the JSON projections in
/// `lib/api/*_router.dart`:
///
///     dart run bin/dump_fixtures.dart
///
/// Diff the fixture files in the resulting commit; any unexplained
/// shape change is the signal that the mobile parsers need an update
/// in the same PR.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:familiars_server/api/boards_router.dart';
import 'package:familiars_server/api/cards_router.dart';
import 'package:familiars_server/api/lists_router.dart';
import 'package:familiars_server/db/database.dart';
import 'package:familiars_server/events/board_event_bus.dart';
import 'package:familiars_server/repositories/boards_repo.dart';
import 'package:familiars_server/repositories/cards_repo.dart';
import 'package:familiars_server/repositories/lists_repo.dart';
import 'package:http/http.dart' as http;
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';

const _jsonHeaders = {'content-type': 'application/json'};

/// Walk a parsed JSON tree and replace fields with non-deterministic
/// runtime values (ULIDs, millisecond epochs) with stable placeholders.
///
/// IDs are interned by their raw value so cross-references stay
/// consistent within a single fixture (boardId on a card resolves to
/// the same `<board-id-1>` token as the parent board's id).
dynamic _normalize(dynamic node) {
  final ids = <String, String>{};
  String coin(String prefix, String raw) =>
      ids.putIfAbsent(raw, () => '<$prefix-${ids.length + 1}>');

  dynamic walk(dynamic n) {
    if (n is Map) {
      final out = <String, dynamic>{};
      n.forEach((k, v) {
        if (k == 'createdAt' || k == 'updatedAt' || k == 'finishedAt' ||
            k == 'startedAt') {
          out[k.toString()] = '<epoch-ms>';
        } else if (k == 'id' && v is String) {
          out[k.toString()] = coin('id', v);
        } else if (k == 'boardId' && v is String) {
          out[k.toString()] = coin('id', v);
        } else if (k == 'listId' && v is String) {
          out[k.toString()] = coin('id', v);
        } else {
          out[k.toString()] = walk(v);
        }
      });
      return out;
    }
    if (n is List) return n.map(walk).toList();
    return n;
  }

  return walk(node);
}

Future<void> main() async {
  final db = AppDatabase(NativeDatabase.memory());
  final bus = BoardEventBus();

  final boards = BoardsRepo(db);
  final lists = ListsRepo(db, bus);
  final cards = CardsRepo(db, bus);

  final router = Router();
  registerBoardsRoutes(router, boards);
  registerListsRoutes(router, lists);
  registerCardsRoutes(router, cards);

  final root = Router()..mount('/api/', router.call);
  final handler = const Pipeline().addHandler(root.call);
  final server =
      await shelf_io.serve(handler, InternetAddress.loopbackIPv4, 0);
  final base = Uri.parse('http://${server.address.host}:${server.port}');
  Uri url(String path) => base.replace(path: path);

  try {
    // ---- Build a canonical board ----
    final boardResp = await http.post(
      url('/api/boards'),
      body: jsonEncode({'name': 'Demo'}),
      headers: _jsonHeaders,
    );
    final boardId = (jsonDecode(boardResp.body) as Map)['id'] as String;

    Future<String> mkList(String name) async {
      final r = await http.post(
        url('/api/boards/$boardId/lists'),
        body: jsonEncode({'name': name}),
        headers: _jsonHeaders,
      );
      return (jsonDecode(r.body) as Map)['id'] as String;
    }

    /// Create a card and optionally PATCH fields that POST doesn't accept
    /// (prUrl, mediaKey — these are assigned post-creation by familiar runs).
    /// Returns the card id so callers can chase further mutations.
    Future<String> mkCard(String listId, Map<String, dynamic> createBody,
        {Map<String, dynamic>? patchBody}) async {
      final r = await http.post(
        url('/api/boards/$boardId/cards'),
        body: jsonEncode({'listId': listId, ...createBody}),
        headers: _jsonHeaders,
      );
      if (r.statusCode != 201) {
        stderr.writeln('mkCard failed: ${r.statusCode} ${r.body}');
        exit(1);
      }
      final id = (jsonDecode(r.body) as Map)['id'] as String;
      if (patchBody != null) {
        final p = await http.patch(
          url('/api/cards/$id'),
          body: jsonEncode(patchBody),
          headers: _jsonHeaders,
        );
        if (p.statusCode != 200) {
          stderr.writeln('PATCH card failed: ${p.statusCode} ${p.body}');
          exit(1);
        }
      }
      return id;
    }

    final backlogId = await mkList('Backlog');
    final doingId = await mkList('Doing');
    final doneId = await mkList('Done');

    // Backlog: minimal card (only required fields)
    await mkCard(backlogId, {'title': 'Minimal card'});

    // Doing: card with description
    await mkCard(doingId, {
      'title': 'Card with description',
      'description': 'Some longer text\nwith a newline',
    });

    // Doing: card with all optional fields populated.
    // POST accepts {description, position, prompt}; prUrl + mediaKey
    // are PATCH-only (assigned post-creation by familiar runs).
    await mkCard(
      doingId,
      {
        'title': 'Fully-populated card',
        'description': 'desc',
        'prompt': 'Make it shine',
      },
      patchBody: {
        'prUrl': 'https://github.com/example/familiars/pull/1',
        'mediaKey': 'media/abc123.png',
      },
    );

    // Done: card with empty-string description (distinct from null)
    await mkCard(doneId, {'title': 'Done card', 'description': ''});

    // ---- Capture the canonical GET /api/boards/<id> payload ----
    final fullBoard = await http.get(url('/api/boards/$boardId'));
    if (fullBoard.statusCode != 200) {
      stderr.writeln('GET board failed: ${fullBoard.statusCode}');
      exit(1);
    }

    // ---- Capture the list-of-boards payload too ----
    final boardsList = await http.get(url('/api/boards'));

    // ---- Pretty-print and write ----
    // Resolve relative to this script (<repo>/bin/dump_fixtures.dart),
    // not the CWD — otherwise running from `mobile/` (or anywhere
    // else) would silently land fixtures in the wrong directory.
    final scriptFile = File.fromUri(Platform.script);
    final repoRoot = scriptFile.parent.parent.path;
    final fixturesDir = Directory('$repoRoot/mobile/test/fixtures');
    if (!fixturesDir.existsSync()) {
      fixturesDir.createSync(recursive: true);
    }

    Future<void> writeFixture(String name, String body) async {
      final normalized = _normalize(jsonDecode(body));
      final pretty = const JsonEncoder.withIndent('  ').convert(normalized);
      final file = File('${fixturesDir.path}/$name');
      await file.writeAsString('$pretty\n');
      stdout.writeln('wrote ${file.path}');
    }

    await writeFixture('board_with_lists_and_cards.json', fullBoard.body);
    await writeFixture('boards_list.json', boardsList.body);
  } finally {
    await server.close(force: true);
    await bus.close();
    await db.close();
  }
}
