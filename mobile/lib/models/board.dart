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

  factory BoardList.fromJson(Map<String, dynamic> json) {
    if (json case {
      'id': String id,
      'boardId': String boardId,
      'name': String name,
      'position': num position,
    }) {
      final rawCards = json['cards'];
      return BoardList(
        id: id,
        boardId: boardId,
        name: name,
        position: position.toDouble(),
        cards: (rawCards is List ? rawCards : const [])
            .map((c) => Card.fromJson(c as Map<String, dynamic>))
            .toList(),
      );
    }
    throw FormatException('Invalid BoardList JSON: $json');
  }

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
///
/// Carries `boardId` even though the server's Cards table has no such
/// column — the field is enriched at the JSON projection so SSE event
/// payloads (`card_created` / `card_updated` / `card_moved`) are
/// self-describing. A reducer that sees a card event for a card whose
/// parent list isn't in local state yet can still resolve the board.
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

  factory Card.fromJson(Map<String, dynamic> json) {
    if (json case {
      'id': String id,
      'boardId': String boardId,
      'listId': String listId,
      'title': String title,
      'position': num position,
    }) {
      return Card(
        id: id,
        boardId: boardId,
        listId: listId,
        title: title,
        position: position.toDouble(),
        description: json['description'] as String?,
        prompt: json['prompt'] as String?,
        prUrl: json['prUrl'] as String?,
        mediaKey: json['mediaKey'] as String?,
      );
    }
    throw FormatException('Invalid Card JSON: $json');
  }

  Card copyWith({
    String? title,
    String? description,
    String? listId,
    double? position,
    String? prompt,
    String? prUrl,
    String? mediaKey,
  }) => Card(
    id: id,
    boardId: boardId,
    listId: listId ?? this.listId,
    title: title ?? this.title,
    description: description ?? this.description,
    position: position ?? this.position,
    prompt: prompt ?? this.prompt,
    prUrl: prUrl ?? this.prUrl,
    mediaKey: mediaKey ?? this.mediaKey,
  );
}

/// A board (root container) with its lists and cards eagerly resolved.
class Board {
  final String id;
  final String name;
  final List<BoardList> lists;

  const Board({required this.id, required this.name, required this.lists});

  factory Board.fromJson(Map<String, dynamic> json) {
    if (json case {
      'id': String id,
      'name': String name,
    }) {
      final rawLists = json['lists'];
      return Board(
        id: id,
        name: name,
        lists: (rawLists is List ? rawLists : const [])
            .map((l) => BoardList.fromJson(l as Map<String, dynamic>))
            .toList()
          ..sort((a, b) => a.position.compareTo(b.position)),
      );
    }
    throw FormatException('Invalid Board JSON: $json');
  }
}
