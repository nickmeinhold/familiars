import 'package:drift/drift.dart';

/// Boards: top-level groupings. Usually one per project.
///
/// Each board owns lists, which in turn own cards. Phase 0 schema —
/// familiars and runs tables arrive in Phase 1.
@DataClassName('Board')
class Boards extends Table {
  /// ULID, generated client-side when the board is created.
  TextColumn get id => text()();

  /// Human-readable name. Free-form, e.g. "downstream", "fade-to-human".
  TextColumn get name => text()();

  /// Creation timestamp in epoch milliseconds.
  IntColumn get createdAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Lists: lanes within a board. Stable structure but user-editable.
///
/// Lists are reordered by writing a midpoint into [position] — see
/// the position-as-real trick documented on [Cards].
@DataClassName('BoardList')
class Lists extends Table {
  /// ULID.
  TextColumn get id => text()();

  /// Owning board's id. Cascade-deletes when the board is removed.
  /// Enforced at the SQL level via [customConstraints] below — the
  /// fluent `.references()` call only declares the relationship for
  /// Drift's codegen and does NOT emit a `REFERENCES` clause.
  TextColumn get boardId =>
      text().references(Boards, #id, onDelete: KeyAction.cascade)();

  /// Lane name, e.g. "Crux", "Working on", "Done".
  TextColumn get name => text()();

  /// Sort key. Drag-reorder writes the midpoint between neighbours.
  RealColumn get position => real()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
        'FOREIGN KEY (board_id) REFERENCES boards(id) ON DELETE CASCADE',
      ];
}

/// Cards: tasks. Each card lives in exactly one list.
///
/// Position is a [RealColumn] so drag-reorders never have to
/// renumber siblings: insert between cards at 1.0 and 2.0 by
/// writing 1.5; between 1.0 and 1.5 by writing 1.25; and so on.
/// Densities only collapse after many bisections — when they do,
/// a one-shot resequencing pass is fine. We don't pre-pay that cost
/// on every drag.
///
/// Phase 1 will add `familiarId` and `currentRunId` columns once
/// familiars and runs tables exist.
@DataClassName('Card')
class Cards extends Table {
  /// ULID.
  TextColumn get id => text()();

  /// Owning list's id. Cascade-deletes when the list is removed.
  TextColumn get listId =>
      text().references(Lists, #id, onDelete: KeyAction.cascade)();

  /// Card title — short, board-visible.
  TextColumn get title => text()();

  /// Long-form description; markdown welcome, may be appended to by
  /// familiars during a run (Phase 1).
  TextColumn get description => text().nullable()();

  /// Sort key within the parent list. See class doc for the trick.
  RealColumn get position => real()();

  /// Creation timestamp in epoch milliseconds.
  IntColumn get createdAt => integer()();

  /// URL of the PR most recently produced for this card (if any).
  TextColumn get prUrl => text().nullable()();

  /// Object-store key for an associated media artifact (image,
  /// recording, etc.). Storage backend TBD.
  TextColumn get mediaKey => text().nullable()();

  /// Task-specific prompt, fed to a familiar at summon time (Phase 1).
  TextColumn get prompt => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
        'FOREIGN KEY (list_id) REFERENCES lists(id) ON DELETE CASCADE',
      ];
}
