import 'package:familiars_mobile/models/board.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Board.fromJson sorts lists by position and parses cards', () {
    final board = Board.fromJson({
      'id': 'b1',
      'name': 'Demo',
      'lists': [
        {
          'id': 'l2',
          'boardId': 'b1',
          'name': 'Doing',
          'position': 2.0,
          'cards': [
            {
              'id': 'c2',
              'boardId': 'b1',
              'listId': 'l2',
              'title': 'second',
              'description': null,
              'position': 1.0,
              'prompt': null,
              'prUrl': null,
              'mediaKey': null,
            },
          ],
        },
        {
          'id': 'l1',
          'boardId': 'b1',
          'name': 'Todo',
          'position': 1.0,
          'cards': [],
        },
      ],
    });
    expect(board.lists.first.id, 'l1');
    expect(board.lists.last.id, 'l2');
    expect(board.lists.last.cards.first.title, 'second');
    expect(board.lists.last.cards.first.boardId, 'b1');
  });

  test('Card.fromJson tolerates absent optional nullable fields', () {
    // The server only sends nullable fields when they're set — absent is
    // valid. Regression for the broken `'foo?': T? foo` map-pattern
    // syntax that interpreted the question-marked key as a literal.
    final card = Card.fromJson({
      'id': 'c1',
      'boardId': 'b1',
      'listId': 'l1',
      'title': 'hello',
      'position': 1.5,
    });
    expect(card.id, 'c1');
    expect(card.boardId, 'b1');
    expect(card.listId, 'l1');
    expect(card.title, 'hello');
    expect(card.position, 1.5);
    expect(card.description, isNull);
    expect(card.prompt, isNull);
  });

  test('Card.fromJson rejects payload without boardId', () {
    // Server enriches every card payload with boardId so SSE events are
    // self-describing. A card without boardId is a contract violation we
    // surface at the boundary rather than tolerate silently.
    expect(
      () => Card.fromJson({
        'id': 'c1',
        'listId': 'l1',
        'title': 'hello',
        'position': 1.5,
      }),
      throwsFormatException,
    );
  });

  test('Card.copyWith preserves untouched fields', () {
    const card = Card(
      id: 'c1',
      boardId: 'b1',
      listId: 'l1',
      title: 'orig',
      description: 'd',
      position: 1.0,
      prompt: null,
      prUrl: null,
      mediaKey: null,
    );
    final moved = card.copyWith(listId: 'l2', position: 2.5);
    expect(moved.title, 'orig');
    expect(moved.boardId, 'b1');
    expect(moved.listId, 'l2');
    expect(moved.position, 2.5);
    expect(moved.description, 'd');
  });
}
