import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._internal();
  static Database? _database;

  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  Future<Database> _initDB() async {
    final dbPath = await getDatabasesPath();
    return await openDatabase(
      join(dbPath, 'family_docs.db'),
      version: 1,
      onCreate: (db, version) async {
        // Members
        await db.execute('''
          CREATE TABLE members (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL
          )
        ''');

        // Categories
        await db.execute('''
          CREATE TABLE categories (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            member_id INTEGER,
            name TEXT
          )
        ''');

        // Documents
        await db.execute('''
          CREATE TABLE documents (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            member_id INTEGER,
            category_id INTEGER,
            file_name TEXT,
            file_path TEXT,
            size INTEGER,
            created_at TEXT,
            sync_status TEXT
          )
        ''');
      },
    );
  }

  // ---------- MEMBER ----------
  Future<int> addMember(String name) async {
    final db = await database;
    return await db.insert('members', {'name': name});
  }

  Future<List<Map<String, dynamic>>> getMembers() async {
    final db = await database;
    return await db.query('members');
  }

  Future<void> renameMember(int id, String newName) async {
    final db = await database;
    await db.update(
      'members',
      {'name': newName},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteMember(int id) async {
    final db = await database;
    // Find documents belonging to member to remove physical files
    final docs = await db.query(
      'documents',
      where: 'member_id = ?',
      whereArgs: [id],
    );
    for (final doc in docs) {
      final path = doc['file_path'] as String?;
      if (path != null) {
        try {
          final file = File(path);
          if (await file.exists()) {
            await file.delete();
          }
        } catch (_) {}
      }
    }
    // Delete documents, categories and member record
    await db.delete('documents', where: 'member_id = ?', whereArgs: [id]);
    await db.delete('categories', where: 'member_id = ?', whereArgs: [id]);
    await db.delete('members', where: 'id = ?', whereArgs: [id]);
  }

  // ---------- CATEGORY ----------
  Future<int> addCategory(int memberId, String name) async {
    final db = await database;
    return await db.insert('categories', {'member_id': memberId, 'name': name});
  }

  Future<List<Map<String, dynamic>>> getCategories(int memberId) async {
    final db = await database;
    return await db.query(
      'categories',
      where: 'member_id = ?',
      whereArgs: [memberId],
    );
  }

  Future<void> renameCategory(int id, String newName) async {
    final db = await database;
    await db.update(
      'categories',
      {'name': newName},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteCategory(int id) async {
    final db = await database;
    final docs = await db.query(
      'documents',
      where: 'category_id = ?',
      whereArgs: [id],
    );
    for (final doc in docs) {
      final path = doc['file_path'] as String?;
      if (path != null) {
        try {
          final file = File(path);
          if (await file.exists()) {
            await file.delete();
          }
        } catch (_) {}
      }
    }
    await db.delete('documents', where: 'category_id = ?', whereArgs: [id]);
    await db.delete('categories', where: 'id = ?', whereArgs: [id]);
  }

  // ---------- DOCUMENT ----------
  Future<int> addDocument(Map<String, dynamic> data) async {
    final db = await database;
    return await db.insert('documents', data);
  }

  Future<List<Map<String, dynamic>>> getAllDocuments() async {
    final db = await database;
    return await db.query('documents', orderBy: 'created_at DESC');
  }

  Future<List<Map<String, dynamic>>> getRecentDocuments({int limit = 5}) async {
    final db = await database;
    return await db.query(
      'documents',
      orderBy: 'created_at DESC',
      limit: limit,
    );
  }

  Future<List<Map<String, dynamic>>> searchDocuments(String query) async {
    final db = await database;
    return await db.query(
      'documents',
      where: 'file_name LIKE ?',
      whereArgs: ['%$query%'],
      orderBy: 'created_at DESC',
    );
  }

  Future<void> deleteDocument(int id, String filePath) async {
    final db = await database;
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}
    await db.delete('documents', where: 'id = ?', whereArgs: [id]);
  }

  // ---------- METRICS & COUNTS ----------
  Future<int> getMemberDocumentCount(int memberId) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM documents WHERE member_id = ?',
      [memberId],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<int> getCategoryDocumentCount(int categoryId) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM documents WHERE category_id = ?',
      [categoryId],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<int> getTotalDocumentCount() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM documents');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<int> getTotalStorageBytes() async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT SUM(size) as total FROM documents',
    );
    final val = result.first['total'];
    if (val == null) return 0;
    if (val is int) return val;
    if (val is num) return val.toInt();
    return 0;
  }
}
