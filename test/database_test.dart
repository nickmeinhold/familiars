import 'package:drift/native.dart';
import 'package:familiars_server/db/database.dart';
import 'package:test/test.dart';

void main() {
  group('AppDatabase schema', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    test('round-trips a board, list, and card', () async {
      final now = DateTime.now().millisecondsSinceEpoch;

      await db.into(db.boards).insert(BoardsCompanion.insert(
            id: 'b1',
            name: 'downstream',
            createdAt: now,
          ));

      await db.into(db.lists).insert(ListsCompanion.insert(
            id: 'l1',
            boardId: 'b1',
            name: 'Working on',
            position: 1.0,
          ));

      await db.into(db.cards).insert(CardsCompanion.insert(
            id: 'c1',
            listId: 'l1',
            title: 'first card',
            position: 1.5,
            createdAt: now,
          ));

      final cards = await db.select(db.cards).get();
      expect(cards, hasLength(1));
      expect(cards.single.title, 'first card');
      expect(cards.single.position, closeTo(1.5, 1e-9));
    });

    test('cascades card deletion when its list is removed', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      await db.into(db.boards).insert(BoardsCompanion.insert(
          id: 'b1', name: 'b', createdAt: now));
      await db.into(db.lists).insert(ListsCompanion.insert(
          id: 'l1', boardId: 'b1', name: 'l', position: 1.0));
      await db.into(db.cards).insert(CardsCompanion.insert(
          id: 'c1', listId: 'l1', title: 't', position: 1.0, createdAt: now));

      await (db.delete(db.lists)..where((t) => t.id.equals('l1'))).go();

      final cards = await db.select(db.cards).get();
      expect(cards, isEmpty,
          reason: 'FK ON DELETE CASCADE should remove orphaned cards');
    });
  });
}
