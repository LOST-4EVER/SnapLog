import 'package:flutter/foundation.dart';
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
      version: 3, // Incremented version for new columns
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
    if (oldVersion < 3) {
      // Migrate from single imagePath to imagePaths and add metadata columns
      await db.execute('ALTER TABLE photo_entries ADD COLUMN location TEXT');
      await db.execute('ALTER TABLE photo_entries ADD COLUMN tags TEXT');
      
      // Rename imagePath to imagePaths if possible, or just add the new one
      // SQLite doesn't support easy column renaming in older versions, 
      // so we add the new one and will handle the transition in code.
      try {
        await db.execute('ALTER TABLE photo_entries RENAME COLUMN imagePath TO imagePaths');
      } catch (e) {
        // Fallback if RENAME COLUMN is not supported
        await db.execute('ALTER TABLE photo_entries ADD COLUMN imagePaths TEXT');
        await db.execute('UPDATE photo_entries SET imagePaths = imagePath');
      }
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE photo_entries(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        imagePaths TEXT,
        caption TEXT,
        mood TEXT,
        filter TEXT,
        timestamp TEXT,
        location TEXT,
        tags TEXT
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

  Future<int> updateEntry(PhotoEntry entry) async {
    Database db = await database;
    return await db.update(
      'photo_entries',
      entry.toMap(),
      where: 'id = ?',
      whereArgs: [entry.id],
    );
  }

  Future<int> deleteEntry(int id) async {
    Database db = await database;
    return await db.delete(
      'photo_entries',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<PhotoEntry>> getEntries() async {
    Database db = await database;
    List<Map<String, dynamic>> maps = await db.query('photo_entries', orderBy: 'timestamp DESC');
    return List.generate(maps.length, (i) => PhotoEntry.fromMap(maps[i]));
  }

  Future<void> clearAllData() async {
    try {
      Database db = await database;
      await db.delete('photo_entries');
      await db.delete('app_settings');
    } catch (e) {
      debugPrint('Error clearing all data: $e');
      rethrow;
    }
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

  Future<List<PhotoEntry>> getOnThisDayEntries() async {
    Database db = await database;
    final now = DateTime.now();
    final month = now.month.toString().padLeft(2, '0');
    final day = now.day.toString().padLeft(2, '0');
    final todayStr = "-$month-${day}T";

    final List<Map<String, dynamic>> maps = await db.rawQuery(
      "SELECT * FROM photo_entries WHERE timestamp LIKE ? AND timestamp NOT LIKE ?",
      ['%$todayStr%', '${now.year}$todayStr%']
    );

    return List.generate(maps.length, (i) => PhotoEntry.fromMap(maps[i]));
  }

  Future<int> calculateStreak() async {
    Database db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'photo_entries',
      columns: ['timestamp'],
      orderBy: 'timestamp DESC',
    );

    if (maps.isEmpty) return 0;

    Set<DateTime> uniqueDates = {};
    for (var row in maps) {
      DateTime dt = DateTime.parse(row['timestamp']);
      uniqueDates.add(DateTime(dt.year, dt.month, dt.day));
    }

    List<DateTime> sortedDates = uniqueDates.toList();
    sortedDates.sort((a, b) => b.compareTo(a));

    int streak = 0;
    DateTime today = DateTime.now();
    DateTime checkDate = DateTime(today.year, today.month, today.day);

    for (var date in sortedDates) {
      if (date.isAtSameMomentAs(checkDate)) {
        streak++;
        checkDate = checkDate.subtract(const Duration(days: 1));
      } else if (date.isBefore(checkDate)) {
        break;
      } else {
        continue;
      }
    }

    return streak;
  }
}
