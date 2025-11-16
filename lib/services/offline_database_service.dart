import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:convert';

class OfflineDatabaseService {
  static Database? _database;
  static const String DB_NAME = 'elearning_offline.db';

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, DB_NAME);

    return await openDatabase(path, version: 1, onCreate: _onCreate);
  }

  Future<void> _onCreate(Database db, int version) async {
    // Cached courses
    await db.execute('''
      CREATE TABLE cached_courses (
        id TEXT PRIMARY KEY,
        semester_id TEXT,
        data TEXT,
        last_sync INTEGER
      )
    ''');

    // Cached announcements
    await db.execute('''
      CREATE TABLE cached_announcements (
        id TEXT PRIMARY KEY,
        course_id TEXT,
        data TEXT,
        last_sync INTEGER
      )
    ''');

    // Cached assignments
    await db.execute('''
      CREATE TABLE cached_assignments (
        id TEXT PRIMARY KEY,
        course_id TEXT,
        data TEXT,
        last_sync INTEGER
      )
    ''');

    // Cached materials
    await db.execute('''
      CREATE TABLE cached_materials (
        id TEXT PRIMARY KEY,
        course_id TEXT,
        data TEXT,
        last_sync INTEGER
      )
    ''');

    // Cached user data
    await db.execute('''
      CREATE TABLE cached_user (
        id TEXT PRIMARY KEY,
        data TEXT,
        last_sync INTEGER
      )
    ''');

    // Offline queue for submissions
    await db.execute('''
      CREATE TABLE offline_queue (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        type TEXT,
        data TEXT,
        created_at INTEGER
      )
    ''');
  }

  // Save course data
  Future<void> saveCourses(List<Map<String, dynamic>> courses) async {
    final db = await database;
    final batch = db.batch();

    for (var course in courses) {
      batch.insert('cached_courses', {
        'id': course['id'],
        'semester_id': course['semester_id'],
        'data': jsonEncode(course),
        'last_sync': DateTime.now().millisecondsSinceEpoch,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }

    await batch.commit();
  }

  // Get cached courses
  Future<List<Map<String, dynamic>>> getCachedCourses(String semesterId) async {
    final db = await database;
    final results = await db.query(
      'cached_courses',
      where: 'semester_id = ?',
      whereArgs: [semesterId],
    );

    return results.map((row) {
      return jsonDecode(row['data'] as String) as Map<String, dynamic>;
    }).toList();
  }

  // Save announcements
  Future<void> saveAnnouncements(
    String courseId,
    List<Map<String, dynamic>> announcements,
  ) async {
    final db = await database;
    final batch = db.batch();

    for (var announcement in announcements) {
      batch.insert('cached_announcements', {
        'id': announcement['id'],
        'course_id': courseId,
        'data': jsonEncode(announcement),
        'last_sync': DateTime.now().millisecondsSinceEpoch,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }

    await batch.commit();
  }

  // Get cached announcements
  Future<List<Map<String, dynamic>>> getCachedAnnouncements(
    String courseId,
  ) async {
    final db = await database;
    final results = await db.query(
      'cached_announcements',
      where: 'course_id = ?',
      whereArgs: [courseId],
    );

    return results.map((row) {
      return jsonDecode(row['data'] as String) as Map<String, dynamic>;
    }).toList();
  }

  // Add to offline queue
  Future<void> addToOfflineQueue(String type, Map<String, dynamic> data) async {
    final db = await database;
    await db.insert('offline_queue', {
      'type': type,
      'data': jsonEncode(data),
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
  }

  // Process offline queue
  Future<List<Map<String, dynamic>>> getOfflineQueue() async {
    final db = await database;
    final results = await db.query('offline_queue', orderBy: 'created_at ASC');

    return results.map((row) {
      return {
        'id': row['id'],
        'type': row['type'],
        'data': jsonDecode(row['data'] as String),
      };
    }).toList();
  }

  // Clear offline queue item
  Future<void> removeFromOfflineQueue(int id) async {
    final db = await database;
    await db.delete('offline_queue', where: 'id = ?', whereArgs: [id]);
  }

  // Check if data needs sync (older than 1 hour)
  Future<bool> needsSync(String table, String id) async {
    final db = await database;
    final results = await db.query(
      table,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (results.isEmpty) return true;

    final lastSync = results.first['last_sync'] as int;
    final hourAgo = DateTime.now()
        .subtract(const Duration(hours: 1))
        .millisecondsSinceEpoch;

    return lastSync < hourAgo;
  }

  // Clear all cached data
  Future<void> clearCache() async {
    final db = await database;
    await db.delete('cached_courses');
    await db.delete('cached_announcements');
    await db.delete('cached_assignments');
    await db.delete('cached_materials');
    await db.delete('cached_user');
  }
}
