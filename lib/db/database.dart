import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;

import 'tables.dart';

part 'database.g.dart';

/// The familiars-server Drift database.
///
/// Phase 0 owns three tables — [Boards], [Lists], [Cards]. Familiars
/// and runs tables land in Phase 1 alongside the spawn flow.
///
/// Open with [AppDatabase.open] (default path `data/familiars.db`,
/// override via [AppDatabase.openAt]) or pass an in-memory executor
/// directly via the default constructor for tests.
@DriftDatabase(tables: [Boards, Lists, Cards])
class AppDatabase extends _$AppDatabase {
  /// Construct with a caller-provided [QueryExecutor]. Useful for
  /// tests (`NativeDatabase.memory()`) and dependency injection.
  AppDatabase(super.e);

  /// Open the database at [path], creating parent directories as
  /// needed. Defaults to `data/familiars.db` relative to the
  /// process's working directory.
  factory AppDatabase.open([String path = 'data/familiars.db']) {
    final file = File(path);
    final dir = Directory(p.dirname(file.absolute.path));
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    return AppDatabase(NativeDatabase(file));
  }

  @override
  int get schemaVersion => 1;
}
