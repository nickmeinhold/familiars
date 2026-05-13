/// Contract tests: parse server-generated fixture JSON through the
/// mobile model layer, asserting invariants the SSE / REST surface
/// depends on.
///
/// Fixtures under `mobile/test/fixtures/` are produced by
/// `bin/dump_fixtures.dart` against the in-memory server harness, so
/// they're real server output (with IDs/timestamps normalized to
/// stable placeholders for clean diffs). Re-run the dumper after any
/// change to `lib/api/*_router.dart`'s JSON projection — the diff in
/// the resulting commit is the contract change the mobile parsers
/// must reckon with in the same PR.
///
/// This is the regression sentinel for the 2026-05-04 boardId /
/// optional-key shake-out: a future change that drops `boardId` from
/// the card payload would (a) show up in the fixture diff at dump
/// time, and (b) throw FormatException here at test time.
library;

import 'dart:convert';
import 'dart:io';

import 'package:familiars_mobile/models/board.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('contract fixtures (server-generated)', () {
    test('GET /api/boards/<id> parses without exceptions', () {
      final board = _loadBoard('board_with_lists_and_cards.json');
      expect(board.id, isNotEmpty);
      expect(board.name, 'Demo');
      expect(board.lists, hasLength(3));
    });

    test('cards under lists carry their boardId (SSE self-describing invariant)',
        () {
      final board = _loadBoard('board_with_lists_and_cards.json');
      for (final list in board.lists) {
        for (final card in list.cards) {
          expect(card.boardId, equals(board.id),
              reason:
                  'Card ${card.id} in list ${list.id} should share the board id; '
                  'this is the contract that lets reducers resolve a card-event '
                  'whose parent list is not yet in local state.');
          expect(card.listId, equals(list.id),
              reason: 'Card ${card.id} should reference its parent list.');
        }
      }
    });

    test('lists arrive sorted by position after Board.fromJson normalization',
        () {
      final board = _loadBoard('board_with_lists_and_cards.json');
      double prev = double.negativeInfinity;
      for (final list in board.lists) {
        expect(list.position, greaterThan(prev),
            reason: 'Lists must be in ascending position order; '
                'Board.fromJson sorts them on parse.');
        prev = list.position;
      }
    });

    test('GET /api/boards (list payload) parses each entry as a Board', () {
      final raw = _loadFixture('boards_list.json');
      final entries = jsonDecode(raw) as List;
      expect(entries, isNotEmpty);
      // Each entry from the list endpoint is a "shallow" board (no
      // nested lists/cards). Board.fromJson tolerates the missing key.
      for (final entry in entries) {
        final b = Board.fromJson(entry as Map<String, dynamic>);
        expect(b.id, isNotEmpty);
        expect(b.name, isNotEmpty);
      }
    });

    test('all optional card fields round-trip (description, prompt, prUrl, mediaKey)',
        () {
      final board = _loadBoard('board_with_lists_and_cards.json');
      final allCards = board.lists.expand((l) => l.cards).toList();

      // Find the canonical "fully populated" card from the dumper.
      final populated = allCards.firstWhere(
        (c) => c.title == 'Fully-populated card',
        orElse: () => fail('dumper should produce a Fully-populated card'),
      );
      expect(populated.description, equals('desc'));
      expect(populated.prompt, equals('Make it shine'));
      expect(populated.prUrl, isNotNull);
      expect(populated.prUrl, contains('github.com'));
      expect(populated.mediaKey, equals('media/abc123.png'));

      // And the canonical "minimal" card has all optionals null.
      final minimal = allCards.firstWhere(
        (c) => c.title == 'Minimal card',
        orElse: () => fail('dumper should produce a Minimal card'),
      );
      expect(minimal.description, isNull);
      expect(minimal.prompt, isNull);
      expect(minimal.prUrl, isNull);
      expect(minimal.mediaKey, isNull);
    });

    test('empty-string description survives round-trip (distinct from null)',
        () {
      final board = _loadBoard('board_with_lists_and_cards.json');
      final empty = board.lists
          .expand((l) => l.cards)
          .firstWhere((c) => c.title == 'Done card');
      expect(empty.description, isNotNull,
          reason: 'Empty string is data; null is absence. The mobile model '
              'must preserve the difference (a future FieldUpdate sealed '
              'class will lean on this distinction).');
      expect(empty.description, equals(''));
    });
  });
}

Board _loadBoard(String fixtureName) =>
    Board.fromJson(jsonDecode(_loadFixture(fixtureName)) as Map<String, dynamic>);

String _loadFixture(String fixtureName) {
  final file = File('test/fixtures/$fixtureName');
  if (!file.existsSync()) {
    throw StateError(
        'Missing fixture: ${file.path}. Regenerate with `dart run bin/dump_fixtures.dart` '
        'from the repo root.');
  }
  return file.readAsStringSync();
}
