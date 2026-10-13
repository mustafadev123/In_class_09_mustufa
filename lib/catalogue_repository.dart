import 'package:sqflite/sqflite.dart';

import 'database_helper.dart';
import 'models.dart';

class DuplicateFolderNameException implements Exception {
  const DuplicateFolderNameException(this.name);

  final String name;

  @override
  String toString() => 'A folder named "$name" already exists.';
}

/// All catalogue SQL lives here so widgets never build queries themselves.
class CatalogueRepository {
  CatalogueRepository(this._helper);

  final DatabaseHelper _helper;

  Database get _db => _helper.database;

  // ---- Folders ----

  /// Returns the new folder ID. Throws [DuplicateFolderNameException] when
  /// the UNIQUE constraint rejects the name (no ConflictAlgorithm.replace,
  /// which would delete the old folder and cascade to its cards).
  Future<int> insertFolder(String name) async {
    final folder = Folder(name: name, createdAt: DateTime.now());
    try {
      return await _db.insert(DatabaseHelper.foldersTable, folder.toMap());
    } on DatabaseException catch (error) {
      if (error.isUniqueConstraintError()) {
        throw DuplicateFolderNameException(name);
      }
      rethrow;
    }
  }

  /// LEFT JOIN keeps empty folders with a count of zero.
  Future<List<Folder>> getFoldersWithCounts() async {
    final rows = await _db.rawQuery(
      'SELECT f.id, f.name, f.created_at, COUNT(c.id) AS card_count '
      'FROM ${DatabaseHelper.foldersTable} f '
      'LEFT JOIN ${DatabaseHelper.cardsTable} c ON c.folder_id = f.id '
      'GROUP BY f.id '
      'ORDER BY f.name COLLATE NOCASE ASC',
    );
    return rows.map(Folder.fromMap).toList();
  }

  /// Returns the affected parent-row count; cards cascade via the foreign key.
  Future<int> deleteFolder(int id) {
    return _db.delete(
      DatabaseHelper.foldersTable,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Evidence check for T5: cards still pointing at a folder ID.
  Future<int> countCardsReferencingFolder(int folderId) async {
    final result = await _db.rawQuery(
      'SELECT COUNT(*) FROM ${DatabaseHelper.cardsTable} WHERE folder_id = ?',
      [folderId],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  // ---- Cards ----

  Future<List<CardRecord>> getCards(int folderId) async {
    final rows = await _db.query(
      DatabaseHelper.cardsTable,
      where: 'folder_id = ?',
      whereArgs: [folderId],
      orderBy: 'title COLLATE NOCASE ASC, id ASC',
    );
    return rows.map(CardRecord.fromMap).toList();
  }

  Future<int> insertCard(CardRecord card) {
    return _db.insert(DatabaseHelper.cardsTable, card.toMap()..remove('id'));
  }

  /// Returns the affected-row count; 0 means the card ID no longer exists.
  Future<int> updateCard(CardRecord card) {
    final id = card.id;
    if (id == null) {
      throw ArgumentError('Cannot update a card without an ID.');
    }
    return _db.update(
      DatabaseHelper.cardsTable,
      card.toMap()..remove('id'),
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteCard(int id) {
    return _db.delete(
      DatabaseHelper.cardsTable,
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
