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
    try {
      Database db = await database;
      await db.delete('photo_entries');
      // Also clear the database settings if needed
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

  // Get entries from this day in previous years
  Future<List<PhotoEntry>> getOnThisDayEntries() async {
    Database db = await database;
    final now = DateTime.now();
    final month = now.month.toString().padLeft(2, '0');
    final day = now.day.toString().padLeft(2, '0');
    final todayStr = "-$month-${day}T"; // Searching for -MM-DDT in ISO string

    // Query for entries where month and day match but year is different
    final List<Map<String, dynamic>> maps = await db.rawQuery(
      "SELECT * FROM photo_entries WHERE timestamp LIKE ? AND timestamp NOT LIKE ?",
      ['%$todayStr%', '${now.year}$todayStr%']
    );

    return List.generate(maps.length, (i) => PhotoEntry.fromMap(maps[i]));
  }

  // Calculate the current daily streak
  Future<int> calculateStreak() async {
    Database db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'photo_entries',
      columns: ['timestamp'],
      orderBy: 'timestamp DESC',
    );

    if (maps.isEmpty) return 0;

    // Convert to a set of date-only values
    Set<DateTime> uniqueDates = {};
    for (var row in maps) {
      DateTime dt = DateTime.parse(row['timestamp']);
      uniqueDates.add(DateTime(dt.year, dt.month, dt.day));
    }

    List<DateTime> sortedDates = uniqueDates.toList();
    sortedDates.sort((a, b) => b.compareTo(a)); // newest first

    int streak = 0;
    DateTime today = DateTime.now();
    DateTime checkDate = DateTime(today.year, today.month, today.day);

    for (var date in sortedDates) {
      if (date.isAtSameMomentAs(checkDate)) {
        streak++;
        checkDate = checkDate.subtract(const Duration(days: 1));
      } else if (date.isBefore(checkDate)) {
        // If the date is older than the day we're checking, and it's not the next in sequence, break
        break;
      } else {
        // date is after checkDate (shouldn't happen because sorted desc), skip
        continue;
      }
    }

    return streak;
  }
}
