import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  static const databaseName = 'MyDatabase.db';
  static const tableName = 'my_table';
  static const columnId = '_id';
  static const columnName = 'name';
  static const columnAge = 'age';

  late Database _database;

  Future<void> init() async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final path = join(documentsDirectory.path, databaseName);
    _database = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) => db.execute(
        'CREATE TABLE $tableName('
        '$columnId INTEGER PRIMARY KEY, '
        '$columnName TEXT NOT NULL, '
        '$columnAge INTEGER NOT NULL)',
      ),
    );
  }

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
