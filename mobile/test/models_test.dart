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
    expect(moved.listId, 'l2');
    expect(moved.position, 2.5);
    expect(moved.description, 'd');
  });
}
