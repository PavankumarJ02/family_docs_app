import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:family_docs_app/db/database_helper.dart';
import 'package:family_docs_app/services/ocr_search_repository.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('Stage B & I - Legacy v1->v2 Migration & Intelligent Search', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('db_mig_test_');
    });

    tearDown(() async {
      await DatabaseHelper.configureForTesting(null);
      if (await tempDir.exists()) await tempDir.delete(recursive: true);
    });

    test(
      'Migrates legacy v1 database non-destructively to v2 with relative paths',
      () async {
        final dbPath = p.join(tempDir.path, 'legacy_v1.db');

        // 1. Create an authentic v1 database with an iOS absolute path record
        final rawDb = await openDatabase(
          dbPath,
          version: 1,
          onCreate: (db, version) async {
            await db.execute(
              'CREATE TABLE members (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL)',
            );
            await db.execute(
              'CREATE TABLE categories (id INTEGER PRIMARY KEY AUTOINCREMENT, member_id INTEGER, name TEXT)',
            );
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
        final mId = await rawDb.insert('members', {'name': 'Rahul'});
        final cId = await rawDb.insert('categories', {
          'member_id': mId,
          'name': 'Identity',
        });
        await rawDb.insert('documents', {
          'member_id': mId,
          'category_id': cId,
          'file_name': 'passport.pdf',
          'file_path':
              '/var/mobile/Containers/Data/Application/OLD-UUID-999/Documents/member_1/category_1/passport.pdf',
          'size': 2048,
          'created_at': '2026-01-01T10:00:00.000',
          'sync_status': 'local_only',
        });
        await rawDb.close();

        // 2. Open with DatabaseHelper (triggers v1 -> v2 migration)
        await DatabaseHelper.configureForTesting(dbPath);
        final docs = await DatabaseHelper.instance.getAllDocuments();

        expect(docs.length, equals(1));
        final migrated = docs.first;
        expect(migrated['file_name'], equals('passport.pdf'));
        // Path converted to portable relative path
        expect(
          migrated['file_path'],
          equals('member_1/category_1/passport.pdf'),
        );
        // UUID backfilled
        expect((migrated['uuid'] as String?)?.isNotEmpty, isTrue);
      },
    );

    test(
      'Intelligent Search filters by filename, member, category, docType, and fileType',
      () async {
        final dbPath = p.join(tempDir.path, 'search_v2.db');
        await DatabaseHelper.configureForTesting(dbPath);

        final m1 = await DatabaseHelper.instance.addMember('Rahul');
        final m2 = await DatabaseHelper.instance.addMember('Priya');
        final c1 = await DatabaseHelper.instance.addCategory(m1, 'Identity');
        final c2 = await DatabaseHelper.instance.addCategory(m2, 'Medical');

        await DatabaseHelper.instance.addDocument({
          'member_id': m1,
          'category_id': c1,
          'file_name': 'rahul_passport.pdf',
          'file_path': 'docs/member_1/category_1/uuid1.pdf',
          'size': 1024,
          'created_at': '2026-05-01T10:00:00.000',
          'sync_status': 'local_only',
          'doc_type': 'Passport',
          'expiry_date': '2030-05-01',
          'expiry_confirmed': 1,
        });

        await DatabaseHelper.instance.addDocument({
          'member_id': m2,
          'category_id': c2,
          'file_name': 'priya_lab_report.jpg',
          'file_path': 'docs/member_2/category_2/uuid2.jpg',
          'size': 512,
          'created_at': '2026-05-02T10:00:00.000',
          'sync_status': 'local_only',
          'doc_type': 'Medical Report',
        });

        final repo = MetadataOnlySearchRepository();

        // 1. Filename query
        final byName = await repo.search(
          const SearchFilterCriteria(query: 'passport'),
        );
        expect(byName.length, equals(1));
        expect(byName.first.fileName, equals('rahul_passport.pdf'));

        // 2. Member filter
        final byMember = await repo.search(SearchFilterCriteria(memberId: m2));
        expect(byMember.length, equals(1));
        expect(byMember.first.fileName, equals('priya_lab_report.jpg'));

        // 3. DocType filter
        final byDocType = await repo.search(
          const SearchFilterCriteria(docType: 'Passport'),
        );
        expect(byDocType.length, equals(1));

        // 4. FileType filter
        final byImage = await repo.search(
          const SearchFilterCriteria(fileType: 'image'),
        );
        expect(byImage.length, equals(1));

        // 5. Empty results
        final none = await repo.search(
          const SearchFilterCriteria(query: 'nonexistent_xyz'),
        );
        expect(none, isEmpty);
      },
    );
  });
}
