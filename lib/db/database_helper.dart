import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../services/document_storage_service.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._internal();
  static Database? _database;
  static String? _overrideDbPath;

  final DocumentStorageService _storage;

  DatabaseHelper._internal({DocumentStorageService? storage})
    : _storage = storage ?? DocumentStorageService();

  /// Allows unit tests to use an isolated database path or in-memory DB.
  static Future<void> configureForTesting(String? dbPath) async {
    if (_database != null && _database!.isOpen) {
      await _database!.close();
    }
    _database = null;
    _overrideDbPath = dbPath;
  }

  Future<Database> get database async {
    if (_database != null && _database!.isOpen) return _database!;
    _database = await _initDB();
    return _database!;
  }

  Future<Database> _initDB() async {
    final path =
        _overrideDbPath ?? join(await getDatabasesPath(), 'family_docs.db');
    return await openDatabase(
      path,
      version: 2,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE members (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        member_id INTEGER,
        name TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE documents (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        uuid TEXT,
        member_id INTEGER,
        category_id INTEGER,
        file_name TEXT,
        file_path TEXT,
        size INTEGER,
        created_at TEXT,
        sync_status TEXT,
        doc_type TEXT,
        masked_id TEXT,
        issue_date TEXT,
        expiry_date TEXT,
        expiry_confirmed INTEGER DEFAULT 0,
        ocr_status TEXT DEFAULT 'pending',
        notes TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE reminders (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        document_id INTEGER NOT NULL,
        notification_id INTEGER NOT NULL,
        reminder_date TEXT NOT NULL,
        reminder_type TEXT NOT NULL,
        is_active INTEGER DEFAULT 1,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_docs_member_cat ON documents (member_id, category_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_docs_type ON documents (doc_type)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_docs_expiry ON documents (expiry_date)',
    );
  }

  /// Backward-compatible, non-destructive migration from v1 to v2.
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      final columns = await db.rawQuery('PRAGMA table_info(documents)');
      final existingCols = columns.map((c) => c['name'] as String).toSet();

      final additions = <String, String>{
        'uuid': 'TEXT',
        'doc_type': 'TEXT',
        'masked_id': 'TEXT',
        'issue_date': 'TEXT',
        'expiry_date': 'TEXT',
        'expiry_confirmed': 'INTEGER DEFAULT 0',
        'ocr_status': "TEXT DEFAULT 'pending'",
        'notes': 'TEXT',
      };

      for (final entry in additions.entries) {
        if (!existingCols.contains(entry.key)) {
          await db.execute(
            'ALTER TABLE documents ADD COLUMN ${entry.key} ${entry.value}',
          );
        }
      }

      await db.execute('''
        CREATE TABLE IF NOT EXISTS reminders (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          document_id INTEGER NOT NULL,
          notification_id INTEGER NOT NULL,
          reminder_date TEXT NOT NULL,
          reminder_type TEXT NOT NULL,
          is_active INTEGER DEFAULT 1,
          created_at TEXT NOT NULL
        )
      ''');

      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_docs_member_cat ON documents (member_id, category_id)',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_docs_type ON documents (doc_type)',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_docs_expiry ON documents (expiry_date)',
      );

      // Non-destructively convert legacy absolute paths to relative subpaths
      // and backfill UUIDs without touching physical files on disk.
      final docs = await db.query('documents');
      const uuidGen = Uuid();
      for (final doc in docs) {
        final id = doc['id'] as int;
        final existingUuid = doc['uuid'] as String?;
        final rawPath = doc['file_path'] as String? ?? '';
        final relativePath = DocumentStorageService.extractRelativeSubpath(
          rawPath,
        );

        final updates = <String, dynamic>{};
        if (existingUuid == null || existingUuid.isEmpty) {
          updates['uuid'] = uuidGen.v4();
        }
        if (relativePath != null && relativePath != rawPath) {
          updates['file_path'] = relativePath;
        }
        if (updates.isNotEmpty) {
          await db.update(
            'documents',
            updates,
            where: 'id = ?',
            whereArgs: [id],
          );
        }
      }
    }
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
    final docs = await db.query(
      'documents',
      where: 'member_id = ?',
      whereArgs: [id],
    );
    for (final doc in docs) {
      final docId = doc['id'] as int;
      final path = doc['file_path'] as String?;
      if (path != null) {
        await _storage.deletePhysicalFile(path);
      }
      await db.delete(
        'reminders',
        where: 'document_id = ?',
        whereArgs: [docId],
      );
    }
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

  Future<List<Map<String, dynamic>>> getAllCategories() async {
    final db = await database;
    return await db.query('categories');
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
      final docId = doc['id'] as int;
      final path = doc['file_path'] as String?;
      if (path != null) {
        await _storage.deletePhysicalFile(path);
      }
      await db.delete(
        'reminders',
        where: 'document_id = ?',
        whereArgs: [docId],
      );
    }
    await db.delete('documents', where: 'category_id = ?', whereArgs: [id]);
    await db.delete('categories', where: 'id = ?', whereArgs: [id]);
  }

  // ---------- DOCUMENT ----------
  Future<int> addDocument(Map<String, dynamic> data) async {
    final db = await database;
    final payload = Map<String, dynamic>.from(data);
    payload['uuid'] ??= const Uuid().v4();
    return await db.insert('documents', payload);
  }

  Future<Map<String, dynamic>?> getDocumentById(int id) async {
    final db = await database;
    final res = await db.query('documents', where: 'id = ?', whereArgs: [id]);
    return res.isEmpty ? null : res.first;
  }

  Future<void> updateDocumentMetadata(
    int id,
    Map<String, dynamic> updates,
  ) async {
    final db = await database;
    await db.update('documents', updates, where: 'id = ?', whereArgs: [id]);
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

  Future<List<Map<String, dynamic>>> getDocumentsWithExpiry() async {
    final db = await database;
    return await db.query(
      'documents',
      where: 'expiry_date IS NOT NULL AND expiry_date != ""',
      orderBy: 'expiry_date ASC',
    );
  }

  Future<List<Map<String, dynamic>>> searchDocuments(
    String query, {
    int? memberId,
    int? categoryId,
    String? docType,
    String? fileType, // 'pdf' | 'image'
    bool onlyWithExpiry = false,
  }) async {
    final db = await database;
    final whereClauses = <String>[];
    final args = <Object?>[];

    final trimmed = query.trim();
    if (trimmed.isNotEmpty) {
      whereClauses.add('(file_name LIKE ? OR doc_type LIKE ? OR notes LIKE ?)');
      args.addAll(['%$trimmed%', '%$trimmed%', '%$trimmed%']);
    }
    if (memberId != null) {
      whereClauses.add('member_id = ?');
      args.add(memberId);
    }
    if (categoryId != null) {
      whereClauses.add('category_id = ?');
      args.add(categoryId);
    }
    if (docType != null && docType.isNotEmpty) {
      whereClauses.add('doc_type = ?');
      args.add(docType);
    }
    if (fileType == 'pdf') {
      whereClauses.add("LOWER(file_name) LIKE '%.pdf'");
    } else if (fileType == 'image') {
      whereClauses.add(
        "(LOWER(file_name) LIKE '%.jpg' OR LOWER(file_name) LIKE '%.jpeg' OR LOWER(file_name) LIKE '%.png' OR LOWER(file_name) LIKE '%.webp')",
      );
    }
    if (onlyWithExpiry) {
      whereClauses.add('expiry_date IS NOT NULL AND expiry_date != ""');
    }

    return await db.query(
      'documents',
      where: whereClauses.isEmpty ? null : whereClauses.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'created_at DESC',
    );
  }

  Future<void> deleteDocument(int id, String filePath) async {
    final db = await database;
    await _storage.deletePhysicalFile(filePath);
    await db.delete('reminders', where: 'document_id = ?', whereArgs: [id]);
    await db.delete('documents', where: 'id = ?', whereArgs: [id]);
  }

  // ---------- REMINDERS ----------
  Future<int> addReminder({
    required int documentId,
    required int notificationId,
    required String reminderDate,
    required String reminderType,
  }) async {
    final db = await database;
    return await db.insert('reminders', {
      'document_id': documentId,
      'notification_id': notificationId,
      'reminder_date': reminderDate,
      'reminder_type': reminderType,
      'is_active': 1,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<List<Map<String, dynamic>>> getRemindersForDocument(
    int documentId,
  ) async {
    final db = await database;
    return await db.query(
      'reminders',
      where: 'document_id = ? AND is_active = 1',
      whereArgs: [documentId],
      orderBy: 'reminder_date ASC',
    );
  }

  Future<void> deactivateRemindersForDocument(int documentId) async {
    final db = await database;
    await db.delete(
      'reminders',
      where: 'document_id = ?',
      whereArgs: [documentId],
    );
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
