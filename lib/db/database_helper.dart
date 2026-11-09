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

  // ---------- DOCUMENT ----------
  Future<int> addDocument(Map<String, dynamic> data) async {
    final db = await database;
    return await db.insert('documents', data);
  }

  Future<List<Map<String, dynamic>>> searchDocuments(String query) async {
    final db = await database;
    return await db.query(
      'documents',
      where: 'file_name LIKE ?',
      whereArgs: ['%$query%'],
    );
  }
}
