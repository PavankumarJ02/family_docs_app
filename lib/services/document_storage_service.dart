import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Service responsible for collision-free file storage,
/// physical lifecycle management, and iOS-safe path resolution.
class DocumentStorageService {
  final Future<Directory> Function() _getDocsDir;

  DocumentStorageService({Future<Directory> Function()? getDocsDir})
    : _getDocsDir = getDocsDir ?? getApplicationDocumentsDirectory;

  /// Sanitizes user-facing file name removing invalid OS path characters.
  static String sanitizeFileName(String name) {
    // Replace OS path separators and illegal characters with an underscore
    return name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
  }

  /// Generates a collision-free stored file name while preserving extension.
  static String generateUniqueFileName(String originalName) {
    final sanitized = sanitizeFileName(originalName);
    final timestamp = DateTime.now().microsecondsSinceEpoch;
    return '${timestamp}_$sanitized';
  }

  /// Copies an imported source file into the app sandbox with collision prevention.
  /// Returns a record with the stored relative path, full resolved path, and file size in bytes.
  Future<({String relativePath, String fullPath, int sizeBytes})> saveDocument({
    required File sourceFile,
    required int memberId,
    required int categoryId,
    required String originalName,
  }) async {
    final docsDir = await _getDocsDir();
    final relativeSubdir = p.join(
      'docs',
      'member_$memberId',
      'category_$categoryId',
    );
    final targetDir = Directory(p.join(docsDir.path, relativeSubdir));

    if (!await targetDir.exists()) {
      await targetDir.create(recursive: true);
    }

    final uniqueName = generateUniqueFileName(originalName);
    final relativePath = p.join(relativeSubdir, uniqueName);
    final fullPath = p.join(targetDir.path, uniqueName);

    final savedFile = await sourceFile.copy(fullPath);
    final size = await savedFile.length();

    return (relativePath: relativePath, fullPath: fullPath, sizeBytes: size);
  }

  /// Resolves any stored path (legacy absolute or new relative) to an existing file.
  /// Handles iOS container UUID changes between app updates.
  Future<String> resolveFilePath(String storedPath) async {
    if (storedPath.isEmpty) return '';

    // 1. Direct check: If file exists at stored path as-is (e.g. Android absolute path)
    final directFile = File(storedPath);
    if (await directFile.exists()) {
      return p.normalize(directFile.path);
    }

    final docsDir = await _getDocsDir();

    // 2. Relative path check: Join with current application documents directory
    final relativeFile = File(p.normalize(p.join(docsDir.path, storedPath)));
    if (await relativeFile.exists()) {
      return relativeFile.path;
    }

    // 3. iOS Container Migration:
    // When an iOS container UUID changes after app update/reinstall:
    // Pattern: /var/mobile/Containers/Data/Application/<OLD_UUID>/Documents/...
    const markers = [
      'Documents/',
      'Documents\\',
      'app_flutter/',
      'app_flutter\\',
    ];
    for (final marker in markers) {
      final index = storedPath.indexOf(marker);
      if (index != -1) {
        final subPath = storedPath.substring(index + marker.length);
        final candidate = File(p.normalize(p.join(docsDir.path, subPath)));
        if (await candidate.exists()) {
          return candidate.path;
        }
      }
    }

    // Fallback: Return best resolved candidate path
    return p.normalize(p.join(docsDir.path, storedPath));
  }

  /// Safely deletes a physical file given its stored or resolved path.
  Future<bool> deletePhysicalFile(String storedPath) async {
    try {
      final resolved = await resolveFilePath(storedPath);
      final file = File(resolved);
      if (await file.exists()) {
        await file.delete();
        return true;
      }
    } catch (_) {
      // Ignore OS file-access exceptions to avoid crashing DB operations
    }
    return false;
  }
}
