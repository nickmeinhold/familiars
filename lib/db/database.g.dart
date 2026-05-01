// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $BoardsTable extends Boards with TableInfo<$BoardsTable, Board> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BoardsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
      'created_at', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [id, name, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'boards';
  @override
  VerificationContext validateIntegrity(Insertable<Board> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Board map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Board(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}created_at'])!,
    );
  }

  @override
  $BoardsTable createAlias(String alias) {
    return $BoardsTable(attachedDatabase, alias);
  }
}

class Board extends DataClass implements Insertable<Board> {
  /// ULID, generated client-side when the board is created.
  final String id;

  /// Human-readable name. Free-form, e.g. "downstream", "fade-to-human".
  final String name;

  /// Creation timestamp in epoch milliseconds.
  final int createdAt;
  const Board({required this.id, required this.name, required this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['created_at'] = Variable<int>(createdAt);
    return map;
  }

  BoardsCompanion toCompanion(bool nullToAbsent) {
    return BoardsCompanion(
      id: Value(id),
      name: Value(name),
      createdAt: Value(createdAt),
    );
  }

  factory Board.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Board(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'createdAt': serializer.toJson<int>(createdAt),
    };
  }

  Board copyWith({String? id, String? name, int? createdAt}) => Board(
        id: id ?? this.id,
        name: name ?? this.name,
        createdAt: createdAt ?? this.createdAt,
      );
  Board copyWithCompanion(BoardsCompanion data) {
    return Board(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Board(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Board &&
          other.id == this.id &&
          other.name == this.name &&
          other.createdAt == this.createdAt);
}

class BoardsCompanion extends UpdateCompanion<Board> {
  final Value<String> id;
  final Value<String> name;
  final Value<int> createdAt;
  final Value<int> rowid;
  const BoardsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  BoardsCompanion.insert({
    required String id,
    required String name,
    required int createdAt,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        name = Value(name),
        createdAt = Value(createdAt);
  static Insertable<Board> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<int>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  BoardsCompanion copyWith(
      {Value<String>? id,
      Value<String>? name,
      Value<int>? createdAt,
      Value<int>? rowid}) {
    return BoardsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BoardsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ListsTable extends Lists with TableInfo<$ListsTable, BoardList> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ListsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _boardIdMeta =
      const VerificationMeta('boardId');
  @override
  late final GeneratedColumn<String> boardId = GeneratedColumn<String>(
      'board_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _positionMeta =
      const VerificationMeta('position');
  @override
  late final GeneratedColumn<double> position = GeneratedColumn<double>(
      'position', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [id, boardId, name, position];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'lists';
  @override
  VerificationContext validateIntegrity(Insertable<BoardList> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('board_id')) {
      context.handle(_boardIdMeta,
          boardId.isAcceptableOrUnknown(data['board_id']!, _boardIdMeta));
    } else if (isInserting) {
      context.missing(_boardIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('position')) {
      context.handle(_positionMeta,
          position.isAcceptableOrUnknown(data['position']!, _positionMeta));
    } else if (isInserting) {
      context.missing(_positionMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  BoardList map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BoardList(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      boardId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}board_id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      position: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}position'])!,
    );
  }

  @override
  $ListsTable createAlias(String alias) {
    return $ListsTable(attachedDatabase, alias);
  }
}

class BoardList extends DataClass implements Insertable<BoardList> {
  /// ULID.
  final String id;

  /// Owning board's id. Cascade-deletes when the board is removed.
  /// Enforced at the SQL level via [customConstraints] below — the
  /// fluent `.references()` call only declares the relationship for
  /// Drift's codegen and does NOT emit a `REFERENCES` clause.
  final String boardId;

  /// Lane name, e.g. "Crux", "Working on", "Done".
  final String name;

  /// Sort key. Drag-reorder writes the midpoint between neighbours.
  final double position;
  const BoardList(
      {required this.id,
      required this.boardId,
      required this.name,
      required this.position});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['board_id'] = Variable<String>(boardId);
    map['name'] = Variable<String>(name);
    map['position'] = Variable<double>(position);
    return map;
  }

  ListsCompanion toCompanion(bool nullToAbsent) {
    return ListsCompanion(
      id: Value(id),
      boardId: Value(boardId),
      name: Value(name),
      position: Value(position),
    );
  }

  factory BoardList.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BoardList(
      id: serializer.fromJson<String>(json['id']),
      boardId: serializer.fromJson<String>(json['boardId']),
      name: serializer.fromJson<String>(json['name']),
      position: serializer.fromJson<double>(json['position']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'boardId': serializer.toJson<String>(boardId),
      'name': serializer.toJson<String>(name),
      'position': serializer.toJson<double>(position),
    };
  }

  BoardList copyWith(
          {String? id, String? boardId, String? name, double? position}) =>
      BoardList(
        id: id ?? this.id,
        boardId: boardId ?? this.boardId,
        name: name ?? this.name,
        position: position ?? this.position,
      );
  BoardList copyWithCompanion(ListsCompanion data) {
    return BoardList(
      id: data.id.present ? data.id.value : this.id,
      boardId: data.boardId.present ? data.boardId.value : this.boardId,
      name: data.name.present ? data.name.value : this.name,
      position: data.position.present ? data.position.value : this.position,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BoardList(')
          ..write('id: $id, ')
          ..write('boardId: $boardId, ')
          ..write('name: $name, ')
          ..write('position: $position')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, boardId, name, position);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BoardList &&
          other.id == this.id &&
          other.boardId == this.boardId &&
          other.name == this.name &&
          other.position == this.position);
}

class ListsCompanion extends UpdateCompanion<BoardList> {
  final Value<String> id;
  final Value<String> boardId;
  final Value<String> name;
  final Value<double> position;
  final Value<int> rowid;
  const ListsCompanion({
    this.id = const Value.absent(),
    this.boardId = const Value.absent(),
    this.name = const Value.absent(),
    this.position = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ListsCompanion.insert({
    required String id,
    required String boardId,
    required String name,
    required double position,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        boardId = Value(boardId),
        name = Value(name),
        position = Value(position);
  static Insertable<BoardList> custom({
    Expression<String>? id,
    Expression<String>? boardId,
    Expression<String>? name,
    Expression<double>? position,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (boardId != null) 'board_id': boardId,
      if (name != null) 'name': name,
      if (position != null) 'position': position,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ListsCompanion copyWith(
      {Value<String>? id,
      Value<String>? boardId,
      Value<String>? name,
      Value<double>? position,
      Value<int>? rowid}) {
    return ListsCompanion(
      id: id ?? this.id,
      boardId: boardId ?? this.boardId,
      name: name ?? this.name,
      position: position ?? this.position,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (boardId.present) {
      map['board_id'] = Variable<String>(boardId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (position.present) {
      map['position'] = Variable<double>(position.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ListsCompanion(')
          ..write('id: $id, ')
          ..write('boardId: $boardId, ')
          ..write('name: $name, ')
          ..write('position: $position, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CardsTable extends Cards with TableInfo<$CardsTable, Card> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CardsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _listIdMeta = const VerificationMeta('listId');
  @override
  late final GeneratedColumn<String> listId = GeneratedColumn<String>(
      'list_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
      'title', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _descriptionMeta =
      const VerificationMeta('description');
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
      'description', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _positionMeta =
      const VerificationMeta('position');
  @override
  late final GeneratedColumn<double> position = GeneratedColumn<double>(
      'position', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
      'created_at', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _prUrlMeta = const VerificationMeta('prUrl');
  @override
  late final GeneratedColumn<String> prUrl = GeneratedColumn<String>(
      'pr_url', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _mediaKeyMeta =
      const VerificationMeta('mediaKey');
  @override
  late final GeneratedColumn<String> mediaKey = GeneratedColumn<String>(
      'media_key', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _promptMeta = const VerificationMeta('prompt');
  @override
  late final GeneratedColumn<String> prompt = GeneratedColumn<String>(
      'prompt', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        listId,
        title,
        description,
        position,
        createdAt,
        prUrl,
        mediaKey,
        prompt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cards';
  @override
  VerificationContext validateIntegrity(Insertable<Card> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('list_id')) {
      context.handle(_listIdMeta,
          listId.isAcceptableOrUnknown(data['list_id']!, _listIdMeta));
    } else if (isInserting) {
      context.missing(_listIdMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
          _titleMeta, title.isAcceptableOrUnknown(data['title']!, _titleMeta));
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
          _descriptionMeta,
          description.isAcceptableOrUnknown(
              data['description']!, _descriptionMeta));
    }
    if (data.containsKey('position')) {
      context.handle(_positionMeta,
          position.isAcceptableOrUnknown(data['position']!, _positionMeta));
    } else if (isInserting) {
      context.missing(_positionMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('pr_url')) {
      context.handle(
          _prUrlMeta, prUrl.isAcceptableOrUnknown(data['pr_url']!, _prUrlMeta));
    }
    if (data.containsKey('media_key')) {
      context.handle(_mediaKeyMeta,
          mediaKey.isAcceptableOrUnknown(data['media_key']!, _mediaKeyMeta));
    }
    if (data.containsKey('prompt')) {
      context.handle(_promptMeta,
          prompt.isAcceptableOrUnknown(data['prompt']!, _promptMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Card map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Card(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      listId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}list_id'])!,
      title: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}title'])!,
      description: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}description']),
      position: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}position'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}created_at'])!,
      prUrl: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}pr_url']),
      mediaKey: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}media_key']),
      prompt: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}prompt']),
    );
  }

  @override
  $CardsTable createAlias(String alias) {
    return $CardsTable(attachedDatabase, alias);
  }
}

class Card extends DataClass implements Insertable<Card> {
  /// ULID.
  final String id;

  /// Owning list's id. Cascade-deletes when the list is removed.
  final String listId;

  /// Card title — short, board-visible.
  final String title;

  /// Long-form description; markdown welcome, may be appended to by
  /// familiars during a run (Phase 1).
  final String? description;

  /// Sort key within the parent list. See class doc for the trick.
  final double position;

  /// Creation timestamp in epoch milliseconds.
  final int createdAt;

  /// URL of the PR most recently produced for this card (if any).
  final String? prUrl;

  /// Object-store key for an associated media artifact (image,
  /// recording, etc.). Storage backend TBD.
  final String? mediaKey;

  /// Task-specific prompt, fed to a familiar at summon time (Phase 1).
  final String? prompt;
  const Card(
      {required this.id,
      required this.listId,
      required this.title,
      this.description,
      required this.position,
      required this.createdAt,
      this.prUrl,
      this.mediaKey,
      this.prompt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['list_id'] = Variable<String>(listId);
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    map['position'] = Variable<double>(position);
    map['created_at'] = Variable<int>(createdAt);
    if (!nullToAbsent || prUrl != null) {
      map['pr_url'] = Variable<String>(prUrl);
    }
    if (!nullToAbsent || mediaKey != null) {
      map['media_key'] = Variable<String>(mediaKey);
    }
    if (!nullToAbsent || prompt != null) {
      map['prompt'] = Variable<String>(prompt);
    }
    return map;
  }

  CardsCompanion toCompanion(bool nullToAbsent) {
    return CardsCompanion(
      id: Value(id),
      listId: Value(listId),
      title: Value(title),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      position: Value(position),
      createdAt: Value(createdAt),
      prUrl:
          prUrl == null && nullToAbsent ? const Value.absent() : Value(prUrl),
      mediaKey: mediaKey == null && nullToAbsent
          ? const Value.absent()
          : Value(mediaKey),
      prompt:
          prompt == null && nullToAbsent ? const Value.absent() : Value(prompt),
    );
  }

  factory Card.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Card(
      id: serializer.fromJson<String>(json['id']),
      listId: serializer.fromJson<String>(json['listId']),
      title: serializer.fromJson<String>(json['title']),
      description: serializer.fromJson<String?>(json['description']),
      position: serializer.fromJson<double>(json['position']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      prUrl: serializer.fromJson<String?>(json['prUrl']),
      mediaKey: serializer.fromJson<String?>(json['mediaKey']),
      prompt: serializer.fromJson<String?>(json['prompt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'listId': serializer.toJson<String>(listId),
      'title': serializer.toJson<String>(title),
      'description': serializer.toJson<String?>(description),
      'position': serializer.toJson<double>(position),
      'createdAt': serializer.toJson<int>(createdAt),
      'prUrl': serializer.toJson<String?>(prUrl),
      'mediaKey': serializer.toJson<String?>(mediaKey),
      'prompt': serializer.toJson<String?>(prompt),
    };
  }

  Card copyWith(
          {String? id,
          String? listId,
          String? title,
          Value<String?> description = const Value.absent(),
          double? position,
          int? createdAt,
          Value<String?> prUrl = const Value.absent(),
          Value<String?> mediaKey = const Value.absent(),
          Value<String?> prompt = const Value.absent()}) =>
      Card(
        id: id ?? this.id,
        listId: listId ?? this.listId,
        title: title ?? this.title,
        description: description.present ? description.value : this.description,
        position: position ?? this.position,
        createdAt: createdAt ?? this.createdAt,
        prUrl: prUrl.present ? prUrl.value : this.prUrl,
        mediaKey: mediaKey.present ? mediaKey.value : this.mediaKey,
        prompt: prompt.present ? prompt.value : this.prompt,
      );
  Card copyWithCompanion(CardsCompanion data) {
    return Card(
      id: data.id.present ? data.id.value : this.id,
      listId: data.listId.present ? data.listId.value : this.listId,
      title: data.title.present ? data.title.value : this.title,
      description:
          data.description.present ? data.description.value : this.description,
      position: data.position.present ? data.position.value : this.position,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      prUrl: data.prUrl.present ? data.prUrl.value : this.prUrl,
      mediaKey: data.mediaKey.present ? data.mediaKey.value : this.mediaKey,
      prompt: data.prompt.present ? data.prompt.value : this.prompt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Card(')
          ..write('id: $id, ')
          ..write('listId: $listId, ')
          ..write('title: $title, ')
          ..write('description: $description, ')
          ..write('position: $position, ')
          ..write('createdAt: $createdAt, ')
          ..write('prUrl: $prUrl, ')
          ..write('mediaKey: $mediaKey, ')
          ..write('prompt: $prompt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, listId, title, description, position,
      createdAt, prUrl, mediaKey, prompt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Card &&
          other.id == this.id &&
          other.listId == this.listId &&
          other.title == this.title &&
          other.description == this.description &&
          other.position == this.position &&
          other.createdAt == this.createdAt &&
          other.prUrl == this.prUrl &&
          other.mediaKey == this.mediaKey &&
          other.prompt == this.prompt);
}

class CardsCompanion extends UpdateCompanion<Card> {
  final Value<String> id;
  final Value<String> listId;
  final Value<String> title;
  final Value<String?> description;
  final Value<double> position;
  final Value<int> createdAt;
  final Value<String?> prUrl;
  final Value<String?> mediaKey;
  final Value<String?> prompt;
  final Value<int> rowid;
  const CardsCompanion({
    this.id = const Value.absent(),
    this.listId = const Value.absent(),
    this.title = const Value.absent(),
    this.description = const Value.absent(),
    this.position = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.prUrl = const Value.absent(),
    this.mediaKey = const Value.absent(),
    this.prompt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CardsCompanion.insert({
    required String id,
    required String listId,
    required String title,
    this.description = const Value.absent(),
    required double position,
    required int createdAt,
    this.prUrl = const Value.absent(),
    this.mediaKey = const Value.absent(),
    this.prompt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        listId = Value(listId),
        title = Value(title),
        position = Value(position),
        createdAt = Value(createdAt);
  static Insertable<Card> custom({
    Expression<String>? id,
    Expression<String>? listId,
    Expression<String>? title,
    Expression<String>? description,
    Expression<double>? position,
    Expression<int>? createdAt,
    Expression<String>? prUrl,
    Expression<String>? mediaKey,
    Expression<String>? prompt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (listId != null) 'list_id': listId,
      if (title != null) 'title': title,
      if (description != null) 'description': description,
      if (position != null) 'position': position,
      if (createdAt != null) 'created_at': createdAt,
      if (prUrl != null) 'pr_url': prUrl,
      if (mediaKey != null) 'media_key': mediaKey,
      if (prompt != null) 'prompt': prompt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CardsCompanion copyWith(
      {Value<String>? id,
      Value<String>? listId,
      Value<String>? title,
      Value<String?>? description,
      Value<double>? position,
      Value<int>? createdAt,
      Value<String?>? prUrl,
      Value<String?>? mediaKey,
      Value<String?>? prompt,
      Value<int>? rowid}) {
    return CardsCompanion(
      id: id ?? this.id,
      listId: listId ?? this.listId,
      title: title ?? this.title,
      description: description ?? this.description,
      position: position ?? this.position,
      createdAt: createdAt ?? this.createdAt,
      prUrl: prUrl ?? this.prUrl,
      mediaKey: mediaKey ?? this.mediaKey,
      prompt: prompt ?? this.prompt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (listId.present) {
      map['list_id'] = Variable<String>(listId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (position.present) {
      map['position'] = Variable<double>(position.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (prUrl.present) {
      map['pr_url'] = Variable<String>(prUrl.value);
    }
    if (mediaKey.present) {
      map['media_key'] = Variable<String>(mediaKey.value);
    }
    if (prompt.present) {
      map['prompt'] = Variable<String>(prompt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CardsCompanion(')
          ..write('id: $id, ')
          ..write('listId: $listId, ')
          ..write('title: $title, ')
          ..write('description: $description, ')
          ..write('position: $position, ')
          ..write('createdAt: $createdAt, ')
          ..write('prUrl: $prUrl, ')
          ..write('mediaKey: $mediaKey, ')
          ..write('prompt: $prompt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $BoardsTable boards = $BoardsTable(this);
  late final $ListsTable lists = $ListsTable(this);
  late final $CardsTable cards = $CardsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [boards, lists, cards];
}

typedef $$BoardsTableCreateCompanionBuilder = BoardsCompanion Function({
  required String id,
  required String name,
  required int createdAt,
  Value<int> rowid,
});
typedef $$BoardsTableUpdateCompanionBuilder = BoardsCompanion Function({
  Value<String> id,
  Value<String> name,
  Value<int> createdAt,
  Value<int> rowid,
});

class $$BoardsTableFilterComposer
    extends Composer<_$AppDatabase, $BoardsTable> {
  $$BoardsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));
}

class $$BoardsTableOrderingComposer
    extends Composer<_$AppDatabase, $BoardsTable> {
  $$BoardsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));
}

class $$BoardsTableAnnotationComposer
    extends Composer<_$AppDatabase, $BoardsTable> {
  $$BoardsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$BoardsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $BoardsTable,
    Board,
    $$BoardsTableFilterComposer,
    $$BoardsTableOrderingComposer,
    $$BoardsTableAnnotationComposer,
    $$BoardsTableCreateCompanionBuilder,
    $$BoardsTableUpdateCompanionBuilder,
    (Board, BaseReferences<_$AppDatabase, $BoardsTable, Board>),
    Board,
    PrefetchHooks Function()> {
  $$BoardsTableTableManager(_$AppDatabase db, $BoardsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BoardsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BoardsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BoardsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<int> createdAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              BoardsCompanion(
            id: id,
            name: name,
            createdAt: createdAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String name,
            required int createdAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              BoardsCompanion.insert(
            id: id,
            name: name,
            createdAt: createdAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$BoardsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $BoardsTable,
    Board,
    $$BoardsTableFilterComposer,
    $$BoardsTableOrderingComposer,
    $$BoardsTableAnnotationComposer,
    $$BoardsTableCreateCompanionBuilder,
    $$BoardsTableUpdateCompanionBuilder,
    (Board, BaseReferences<_$AppDatabase, $BoardsTable, Board>),
    Board,
    PrefetchHooks Function()>;
typedef $$ListsTableCreateCompanionBuilder = ListsCompanion Function({
  required String id,
  required String boardId,
  required String name,
  required double position,
  Value<int> rowid,
});
typedef $$ListsTableUpdateCompanionBuilder = ListsCompanion Function({
  Value<String> id,
  Value<String> boardId,
  Value<String> name,
  Value<double> position,
  Value<int> rowid,
});

class $$ListsTableFilterComposer extends Composer<_$AppDatabase, $ListsTable> {
  $$ListsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get boardId => $composableBuilder(
      column: $table.boardId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get position => $composableBuilder(
      column: $table.position, builder: (column) => ColumnFilters(column));
}

class $$ListsTableOrderingComposer
    extends Composer<_$AppDatabase, $ListsTable> {
  $$ListsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get boardId => $composableBuilder(
      column: $table.boardId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get position => $composableBuilder(
      column: $table.position, builder: (column) => ColumnOrderings(column));
}

class $$ListsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ListsTable> {
  $$ListsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get boardId =>
      $composableBuilder(column: $table.boardId, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<double> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);
}

class $$ListsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $ListsTable,
    BoardList,
    $$ListsTableFilterComposer,
    $$ListsTableOrderingComposer,
    $$ListsTableAnnotationComposer,
    $$ListsTableCreateCompanionBuilder,
    $$ListsTableUpdateCompanionBuilder,
    (BoardList, BaseReferences<_$AppDatabase, $ListsTable, BoardList>),
    BoardList,
    PrefetchHooks Function()> {
  $$ListsTableTableManager(_$AppDatabase db, $ListsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ListsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ListsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ListsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> boardId = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<double> position = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ListsCompanion(
            id: id,
            boardId: boardId,
            name: name,
            position: position,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String boardId,
            required String name,
            required double position,
            Value<int> rowid = const Value.absent(),
          }) =>
              ListsCompanion.insert(
            id: id,
            boardId: boardId,
            name: name,
            position: position,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$ListsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $ListsTable,
    BoardList,
    $$ListsTableFilterComposer,
    $$ListsTableOrderingComposer,
    $$ListsTableAnnotationComposer,
    $$ListsTableCreateCompanionBuilder,
    $$ListsTableUpdateCompanionBuilder,
    (BoardList, BaseReferences<_$AppDatabase, $ListsTable, BoardList>),
    BoardList,
    PrefetchHooks Function()>;
typedef $$CardsTableCreateCompanionBuilder = CardsCompanion Function({
  required String id,
  required String listId,
  required String title,
  Value<String?> description,
  required double position,
  required int createdAt,
  Value<String?> prUrl,
  Value<String?> mediaKey,
  Value<String?> prompt,
  Value<int> rowid,
});
typedef $$CardsTableUpdateCompanionBuilder = CardsCompanion Function({
  Value<String> id,
  Value<String> listId,
  Value<String> title,
  Value<String?> description,
  Value<double> position,
  Value<int> createdAt,
  Value<String?> prUrl,
  Value<String?> mediaKey,
  Value<String?> prompt,
  Value<int> rowid,
});

class $$CardsTableFilterComposer extends Composer<_$AppDatabase, $CardsTable> {
  $$CardsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get listId => $composableBuilder(
      column: $table.listId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get position => $composableBuilder(
      column: $table.position, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get prUrl => $composableBuilder(
      column: $table.prUrl, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get mediaKey => $composableBuilder(
      column: $table.mediaKey, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get prompt => $composableBuilder(
      column: $table.prompt, builder: (column) => ColumnFilters(column));
}

class $$CardsTableOrderingComposer
    extends Composer<_$AppDatabase, $CardsTable> {
  $$CardsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get listId => $composableBuilder(
      column: $table.listId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get position => $composableBuilder(
      column: $table.position, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get prUrl => $composableBuilder(
      column: $table.prUrl, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get mediaKey => $composableBuilder(
      column: $table.mediaKey, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get prompt => $composableBuilder(
      column: $table.prompt, builder: (column) => ColumnOrderings(column));
}

class $$CardsTableAnnotationComposer
    extends Composer<_$AppDatabase, $CardsTable> {
  $$CardsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get listId =>
      $composableBuilder(column: $table.listId, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => column);

  GeneratedColumn<double> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get prUrl =>
      $composableBuilder(column: $table.prUrl, builder: (column) => column);

  GeneratedColumn<String> get mediaKey =>
      $composableBuilder(column: $table.mediaKey, builder: (column) => column);

  GeneratedColumn<String> get prompt =>
      $composableBuilder(column: $table.prompt, builder: (column) => column);
}

class $$CardsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $CardsTable,
    Card,
    $$CardsTableFilterComposer,
    $$CardsTableOrderingComposer,
    $$CardsTableAnnotationComposer,
    $$CardsTableCreateCompanionBuilder,
    $$CardsTableUpdateCompanionBuilder,
    (Card, BaseReferences<_$AppDatabase, $CardsTable, Card>),
    Card,
    PrefetchHooks Function()> {
  $$CardsTableTableManager(_$AppDatabase db, $CardsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CardsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CardsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CardsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> listId = const Value.absent(),
            Value<String> title = const Value.absent(),
            Value<String?> description = const Value.absent(),
            Value<double> position = const Value.absent(),
            Value<int> createdAt = const Value.absent(),
            Value<String?> prUrl = const Value.absent(),
            Value<String?> mediaKey = const Value.absent(),
            Value<String?> prompt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              CardsCompanion(
            id: id,
            listId: listId,
            title: title,
            description: description,
            position: position,
            createdAt: createdAt,
            prUrl: prUrl,
            mediaKey: mediaKey,
            prompt: prompt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String listId,
            required String title,
            Value<String?> description = const Value.absent(),
            required double position,
            required int createdAt,
            Value<String?> prUrl = const Value.absent(),
            Value<String?> mediaKey = const Value.absent(),
            Value<String?> prompt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              CardsCompanion.insert(
            id: id,
            listId: listId,
            title: title,
            description: description,
            position: position,
            createdAt: createdAt,
            prUrl: prUrl,
            mediaKey: mediaKey,
            prompt: prompt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$CardsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $CardsTable,
    Card,
    $$CardsTableFilterComposer,
    $$CardsTableOrderingComposer,
    $$CardsTableAnnotationComposer,
    $$CardsTableCreateCompanionBuilder,
    $$CardsTableUpdateCompanionBuilder,
    (Card, BaseReferences<_$AppDatabase, $CardsTable, Card>),
    Card,
    PrefetchHooks Function()>;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$BoardsTableTableManager get boards =>
      $$BoardsTableTableManager(_db, _db.boards);
  $$ListsTableTableManager get lists =>
      $$ListsTableTableManager(_db, _db.lists);
  $$CardsTableTableManager get cards =>
      $$CardsTableTableManager(_db, _db.cards);
}
