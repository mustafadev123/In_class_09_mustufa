import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  static const databaseName = 'MyDatabase.db';
  static const databaseVersion = 2;

  // Part I guest table (version 1). Kept unchanged so existing rows survive.
  static const tableName = 'my_table';
  static const columnId = '_id';
  static const columnName = 'name';
  static const columnAge = 'age';

  // Part II catalogue tables (added in version 2).
  static const foldersTable = 'folders';
  static const cardsTable = 'cards';

  late Database _database;

  Database get database => _database;

  Future<void> init() async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final path = join(documentsDirectory.path, databaseName);
    _database = await openDatabase(
      path,
      version: databaseVersion,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, version) async {
        await createPartOneTables(db);
        await createCatalogueTables(db);
      },
      // Runs inside sqflite's transaction; errors propagate so the upgrade
      // rolls back and opening fails visibly instead of half-migrating.
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await createCatalogueTables(db);
        }
      },
    );
  }

  static Future<void> createPartOneTables(Database db) async {
    await db.execute(
      'CREATE TABLE $tableName('
      '$columnId INTEGER PRIMARY KEY, '
      '$columnName TEXT NOT NULL, '
      '$columnAge INTEGER NOT NULL)',
    );
  }

  static Future<void> createCatalogueTables(Database db) async {
    await db.execute(
      'CREATE TABLE $foldersTable('
      'id INTEGER PRIMARY KEY AUTOINCREMENT, '
      'name TEXT NOT NULL UNIQUE, '
      'created_at TEXT NOT NULL)',
    );
    await db.execute(
      'CREATE TABLE $cardsTable('
      'id INTEGER PRIMARY KEY AUTOINCREMENT, '
      'title TEXT NOT NULL, '
      'suit TEXT NOT NULL, '
      "notes TEXT NOT NULL DEFAULT '', "
      'image_ref TEXT, '
      'folder_id INTEGER NOT NULL, '
      'FOREIGN KEY (folder_id) REFERENCES $foldersTable(id) ON DELETE CASCADE)',
    );
    await db.execute(
      'CREATE INDEX idx_cards_folder_id ON $cardsTable(folder_id)',
    );
  }

  /// Read-only schema checks used as T1 evidence.
  Future<Map<String, Object?>> diagnostics() async {
    final userVersion = Sqflite.firstIntValue(
      await _database.rawQuery('PRAGMA user_version'),
    );
    final foreignKeys = Sqflite.firstIntValue(
      await _database.rawQuery('PRAGMA foreign_keys'),
    );
    final tables = await _database.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table' "
      "AND name NOT LIKE 'sqlite_%' AND name != 'android_metadata' "
      'ORDER BY name',
    );
    return {
      'user_version': userVersion,
      'foreign_keys': foreignKeys,
      'tables': tables.map((row) => row['name']).toList(),
      'foreign_key_list(cards)':
          await _database.rawQuery('PRAGMA foreign_key_list($cardsTable)'),
      'index_list(cards)':
          await _database.rawQuery('PRAGMA index_list($cardsTable)'),
      'part_one_rows': await queryAllRows(),
      'part_one_count': await queryRowCount(),
    };
  }

  // ---- Part I guest operations (unchanged) ----

  Future<int> insert(Map<String, Object?> row) {
    return _database.insert(tableName, row);
  }

  Future<List<Map<String, Object?>>> queryAllRows() {
    return _database.query(tableName, orderBy: '$columnId ASC');
  }

  Future<int> queryRowCount() async {
    final result = await _database.rawQuery(
      'SELECT COUNT(*) AS count FROM $tableName',
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<int> update(Map<String, Object?> row) {
    final id = row[columnId];
    return _database.update(
      tableName,
      row,
      where: '$columnId = ?',
      whereArgs: [id],
    );
  }

  Future<int> delete(int id) {
    return _database.delete(
      tableName,
      where: '$columnId = ?',
      whereArgs: [id],
    );
  }
}
