import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:family_docs_app/services/document_storage_service.dart';

void main() {
  late Directory tempAppDir;
  late DocumentStorageService storageService;

  setUp(() async {
    tempAppDir = await Directory.systemTemp.createTemp('family_docs_test_');
    storageService = DocumentStorageService(getDocsDir: () async => tempAppDir);
  });

  tearDown(() async {
    if (await tempAppDir.exists()) {
      await tempAppDir.delete(recursive: true);
    }
  });

  group('DocumentStorageService - Data Integrity & Silent Overwrite Prevention', () {
    test(
      'Importing two files with identical names creates distinct physical files without overwriting',
      () async {
        // Create two separate source files with the SAME filename but DIFFERENT contents
        final sourceDir = await Directory.systemTemp.createTemp(
          'source_files_',
        );
        final file1 = File(p.join(sourceDir.path, 'passport.pdf'));
        await file1.writeAsString('Passport Content Version 1');

        final file2 = File(p.join(sourceDir.path, 'passport_copy.pdf'));
        await file2.writeAsString(
          'Passport Content Version 2 - Different document',
        );

        // Import document 1 as "passport.pdf"
        final result1 = await storageService.saveDocument(
          sourceFile: file1,
          memberId: 1,
          categoryId: 1,
          originalName: 'passport.pdf',
        );

        // Micro-sleep to ensure distinct microsecond timestamp
        await Future.delayed(const Duration(milliseconds: 2));

        // Import document 2 ALSO as "passport.pdf"
        final result2 = await storageService.saveDocument(
          sourceFile: file2,
          memberId: 1,
          categoryId: 1,
          originalName: 'passport.pdf',
        );

        // 1. Both stored paths must be different
        expect(result1.fullPath, isNot(equals(result2.fullPath)));
        expect(result1.relativePath, isNot(equals(result2.relativePath)));

        // 2. Both physical files must exist on disk
        expect(File(result1.fullPath).existsSync(), isTrue);
        expect(File(result2.fullPath).existsSync(), isTrue);

        // 3. Document 1 content must NOT be overwritten by document 2
        final content1 = await File(result1.fullPath).readAsString();
        final content2 = await File(result2.fullPath).readAsString();
        expect(content1, equals('Passport Content Version 1'));
        expect(
          content2,
          equals('Passport Content Version 2 - Different document'),
        );

        await sourceDir.delete(recursive: true);
      },
    );

    test(
      'Importing multiple documents in the same category maintains directory structure',
      () async {
        final sourceDir = await Directory.systemTemp.createTemp('multi_docs_');
        final fileA = File(p.join(sourceDir.path, 'aadhaar.pdf'))
          ..writeAsStringSync('Aadhaar Data');
        final fileB = File(p.join(sourceDir.path, 'pan.jpg'))
          ..writeAsStringSync('PAN Image Data');

        final resA = await storageService.saveDocument(
          sourceFile: fileA,
          memberId: 2,
          categoryId: 5,
          originalName: 'aadhaar.pdf',
        );
        final resB = await storageService.saveDocument(
          sourceFile: fileB,
          memberId: 2,
          categoryId: 5,
          originalName: 'pan.jpg',
        );

        expect(File(resA.fullPath).existsSync(), isTrue);
        expect(File(resB.fullPath).existsSync(), isTrue);
        expect(
          resA.relativePath.startsWith(
            p.join('docs', 'member_2', 'category_5'),
          ),
          isTrue,
        );
        expect(
          resB.relativePath.startsWith(
            p.join('docs', 'member_2', 'category_5'),
          ),
          isTrue,
        );

        await sourceDir.delete(recursive: true);
      },
    );

    test('Deleting a document removes the physical file cleanly', () async {
      final sourceDir = await Directory.systemTemp.createTemp('delete_test_');
      final file = File(p.join(sourceDir.path, 'temp.pdf'))
        ..writeAsStringSync('To be deleted');

      final saved = await storageService.saveDocument(
        sourceFile: file,
        memberId: 1,
        categoryId: 1,
        originalName: 'temp.pdf',
      );

      expect(File(saved.fullPath).existsSync(), isTrue);

      // Delete via relative path
      final deleted = await storageService.deletePhysicalFile(
        saved.relativePath,
      );
      expect(deleted, isTrue);
      expect(File(saved.fullPath).existsSync(), isFalse);

      await sourceDir.delete(recursive: true);
    });

    test(
      'iOS Container Migration resolves file when container UUID changes',
      () async {
        // Simulate an old iOS path from a previous container UUID:
        // /var/mobile/Containers/Data/Application/OLD-UUID-1234/Documents/docs/member_1/category_2/doc.pdf
        // Create the file in the new container tempAppDir:
        final targetSubdir = Directory(
          p.join(tempAppDir.path, 'docs', 'member_1', 'category_2'),
        );
        await targetSubdir.create(recursive: true);
        final actualFile = File(p.join(targetSubdir.path, 'sample.pdf'))
          ..writeAsStringSync('iOS content');

        // Old simulated path that does not exist at that literal location
        final oldIosPath =
            '/var/mobile/Containers/Data/Application/OLD-UUID-1234/Documents/docs/member_1/category_2/sample.pdf';

        final resolved = await storageService.resolveFilePath(oldIosPath);
        expect(p.normalize(resolved), equals(p.normalize(actualFile.path)));
        expect(File(resolved).existsSync(), isTrue);
      },
    );

    test('Special characters in original filenames are sanitized', () {
      final sanitized = DocumentStorageService.sanitizeFileName(
        'file:with/illegal?chars*<name>.pdf',
      );
      expect(sanitized.contains(':'), isFalse);
      expect(sanitized.contains('/'), isFalse);
      expect(sanitized.contains('?'), isFalse);
      expect(sanitized.contains('*'), isFalse);
      expect(sanitized.contains('<'), isFalse);
      expect(sanitized.contains('>'), isFalse);
      expect(sanitized.endsWith('.pdf'), isTrue);
    });
  });
}
