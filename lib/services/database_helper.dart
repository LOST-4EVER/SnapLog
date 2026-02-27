import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/photo_entry.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;

  factory DatabaseHelper() => _instance;

  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'snaplog.db');
    return await openDatabase(
      path,
      version: 2,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS app_settings(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          key TEXT UNIQUE,
          value TEXT
        )
      ''');
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE photo_entries(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        imagePath TEXT,
        caption TEXT,
        mood TEXT,
        filter TEXT,
        timestamp TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE app_settings(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        key TEXT UNIQUE,
        value TEXT
      )
    ''');
  }

  Future<int> insertEntry(PhotoEntry entry) async {
    Database db = await database;
    return await db.insert('photo_entries', entry.toMap());
  }

  Future<List<PhotoEntry>> getEntries() async {
    Database db = await database;
    List<Map<String, dynamic>> maps = await db.query('photo_entries', orderBy: 'timestamp DESC');
    return List.generate(maps.length, (i) => PhotoEntry.fromMap(maps[i]));
  }

  Future<void> clearAllData() async {
    Database db = await database;
    await db.delete('photo_entries');
  }

  Future<int> getTodaysPhotoCount() async {
    Database db = await database;
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    final endOfDay = DateTime(today.year, today.month, today.day, 23, 59, 59);

    final result = await db.rawQuery(
      '''SELECT COUNT(*) as count FROM photo_entries 
         WHERE timestamp >= ? AND timestamp <= ?''',
      [startOfDay.toIso8601String(), endOfDay.toIso8601String()],
    );

    return Sqflite.firstIntValue(result) ?? 0;
  }
}
