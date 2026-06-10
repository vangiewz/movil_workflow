import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('workflow_offline.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  Future _createDB(Database db, int version) async {
    const idType = 'INTEGER PRIMARY KEY AUTOINCREMENT';
    const textType = 'TEXT NOT NULL';
    const textNullable = 'TEXT';

    // Tabla para colas offline (POST, PUT, DELETE)
    await db.execute('''
CREATE TABLE offline_queue (
  id $idType,
  url $textType,
  method $textType,
  body $textNullable,
  headers $textNullable,
  timestamp $textType
)
''');

    // Tabla para caché de GET (para responder offline)
    await db.execute('''
CREATE TABLE http_cache (
  url $textType PRIMARY KEY,
  response $textType,
  timestamp $textType
)
''');
  }

  Future<void> clearCache() async {
    final db = await instance.database;
    await db.delete('http_cache');
  }

  Future<void> close() async {
    final db = await instance.database;
    db.close();
  }
}
