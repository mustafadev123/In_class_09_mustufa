enum Suit {
  hearts('Hearts', '♥'),
  diamonds('Diamonds', '♦'),
  clubs('Clubs', '♣'),
  spades('Spades', '♠');

  const Suit(this.label, this.symbol);

  final String label;
  final String symbol;

  static Suit fromLabel(String label) {
    return Suit.values.firstWhere(
      (suit) => suit.label == label,
      orElse: () => throw FormatException('Unknown suit: $label'),
    );
  }
}

class Folder {
  const Folder({
    this.id,
    required this.name,
    required this.createdAt,
    this.cardCount = 0,
  });

  final int? id;
  final String name;

  /// Stored as an ISO-8601 string.
  final DateTime createdAt;

  /// Derived from a LEFT JOIN count; never written to the folders table.
  final int cardCount;

  factory Folder.fromMap(Map<String, Object?> map) {
    return Folder(
      id: map['id'] as int,
      name: map['name'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
      cardCount: (map['card_count'] as int?) ?? 0,
    );
  }

  Map<String, Object?> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

/// Named CardRecord to avoid colliding with Material's Card widget.
class CardRecord {
  const CardRecord({
    this.id,
    required this.title,
    required this.suit,
    this.notes = '',
    this.imageRef,
    required this.folderId,
  });

  final int? id;
  final String title;
  final Suit suit;
  final String notes;

  /// Nullable reference (asset path or URL), not the image bytes.
  final String? imageRef;
  final int folderId;

  factory CardRecord.fromMap(Map<String, Object?> map) {
    return CardRecord(
      id: map['id'] as int,
      title: map['title'] as String,
      suit: Suit.fromLabel(map['suit'] as String),
      notes: map['notes'] as String,
      imageRef: map['image_ref'] as String?,
      folderId: map['folder_id'] as int,
    );
  }

  Map<String, Object?> toMap() {
    return {
      if (id != null) 'id': id,
      'title': title,
      'suit': suit.label,
      'notes': notes,
      'image_ref': imageRef,
      'folder_id': folderId,
    };
  }
}
