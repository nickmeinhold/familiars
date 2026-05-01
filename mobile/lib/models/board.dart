/// API DTOs for the familiars board.
///
/// Hand-written (per project convention — small model layer, no codegen).
/// Field shapes match `lib/api/*_router.dart` on the server side.
library;

/// A list (lane) on a board, with its cards in `position` order.
class BoardList {
  final String id;
  final String boardId;
  final String name;
  final double position;
  final List<Card> cards;

  const BoardList({
    required this.id,
    required this.boardId,
    required this.name,
    required this.position,
    required this.cards,
  });

  factory BoardList.fromJson(Map<String, dynamic> json) => BoardList(
        id: json['id'] as String,
        boardId: json['boardId'] as String,
        name: json['name'] as String,
        position: (json['position'] as num).toDouble(),
        cards: (json['cards'] as List<dynamic>? ?? const [])
            .map((c) => Card.fromJson(c as Map<String, dynamic>))
            .toList(),
      );

  BoardList copyWith({String? name, double? position, List<Card>? cards}) =>
      BoardList(
        id: id,
        boardId: boardId,
        name: name ?? this.name,
        position: position ?? this.position,
        cards: cards ?? this.cards,
      );
}

/// A card — the locus of a familiar's work, in phase 0 just title/description.
class Card {
  final String id;
  final String boardId;
  final String listId;
  final String title;
  final String? description;
  final double position;
  final String? prompt;
  final String? prUrl;
  final String? mediaKey;

  const Card({
    required this.id,
    required this.boardId,
    required this.listId,
    required this.title,
    required this.description,
    required this.position,
    required this.prompt,
    required this.prUrl,
    required this.mediaKey,
  });

  factory Card.fromJson(Map<String, dynamic> json) => Card(
        id: json['id'] as String,
        boardId: json['boardId'] as String,
        listId: json['listId'] as String,
        title: json['title'] as String,
        description: json['description'] as String?,
        position: (json['position'] as num).toDouble(),
        prompt: json['prompt'] as String?,
        prUrl: json['prUrl'] as String?,
        mediaKey: json['mediaKey'] as String?,
      );

  Card copyWith({
    String? title,
    String? description,
    String? listId,
    double? position,
  }) =>
      Card(
        id: id,
        boardId: boardId,
        listId: listId ?? this.listId,
        title: title ?? this.title,
        description: description ?? this.description,
        position: position ?? this.position,
        prompt: prompt,
        prUrl: prUrl,
        mediaKey: mediaKey,
      );
}

/// A board (root container) with its lists and cards eagerly resolved.
class Board {
  final String id;
  final String name;
  final List<BoardList> lists;

  const Board({
    required this.id,
    required this.name,
    required this.lists,
  });

  factory Board.fromJson(Map<String, dynamic> json) => Board(
        id: json['id'] as String,
        name: json['name'] as String,
        lists: (json['lists'] as List<dynamic>? ?? const [])
            .map((l) => BoardList.fromJson(l as Map<String, dynamic>))
            .toList()
          ..sort((a, b) => a.position.compareTo(b.position)),
      );
}
