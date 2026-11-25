import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

/// Exception thrown when an imported document fails validation.
class DocumentImportException implements Exception {
  final String message;
  const DocumentImportException(this.message);

  @override
  String toString() => 'DocumentImportException: $message';
}

/// Service responsible for UUID-based collision-free file storage,
/// import validation, physical lifecycle management, and iOS-safe path resolution.
class DocumentStorageService {
  static const Set<String> allowedExtensions = {
    'pdf',
    'jpg',
    'jpeg',
    'png',
    'webp',
  };

  static const int maxFileSizeBytes = 100 * 1024 * 1024; // 100 MB safety cap

  final Future<Directory> Function() _getDocsDir;
  final Uuid _uuid;

  DocumentStorageService({Future<Directory> Function()? getDocsDir, Uuid? uuid})
    : _getDocsDir = getDocsDir ?? getApplicationDocumentsDirectory,
      _uuid = uuid ?? const Uuid();

  /// Sanitizes user-facing file name removing invalid OS path characters.
  static String sanitizeFileName(String name) {
    return name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
  }

  /// Generates a UUID-based physical filename while preserving the extension.
  String generateUuidFileName(String originalName) {
    final ext = p.extension(originalName).toLowerCase();
    return '${_uuid.v4()}$ext';
  }

  /// Validates an imported source file before copying into the vault.
  Future<void> validateImport(File sourceFile, String originalName) async {
    if (!await sourceFile.exists()) {
      throw const DocumentImportException('Selected file does not exist.');
    }
    final size = await sourceFile.length();
    if (size <= 0) {
      throw const DocumentImportException('Selected file is empty (0 bytes).');
    }
    if (size > maxFileSizeBytes) {
      throw const DocumentImportException(
        'Selected file exceeds the 100 MB per-document limit.',
      );
    }
    final ext = p.extension(originalName).replaceFirst('.', '').toLowerCase();
    if (!allowedExtensions.contains(ext)) {
      throw DocumentImportException(
        'Unsupported file format ".$ext". Supported: PDF, JPG, PNG, WEBP.',
      );
    }
  }

  /// Copies an imported source file into the app sandbox using a UUID filename.
  /// Preserves the original filename for metadata display.
  Future<({String uuid, String relativePath, String fullPath, int sizeBytes})>
  saveDocument({
    required File sourceFile,
    required int memberId,
    required int categoryId,
    required String originalName,
  }) async {
    await validateImport(sourceFile, originalName);

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

    final docUuid = _uuid.v4();
    final ext = p.extension(originalName).toLowerCase();
    final physicalName = '$docUuid$ext';
    // Store POSIX-style relative path in SQLite for cross-platform consistency
    final relativePath = p.posix.join(
      'docs',
      'member_$memberId',
      'category_$categoryId',
      physicalName,
    );
    final fullPath = p.normalize(p.join(targetDir.path, physicalName));

    final savedFile = await sourceFile.copy(fullPath);
    final size = await savedFile.length();

    return (
      uuid: docUuid,
      relativePath: relativePath,
      fullPath: fullPath,
      sizeBytes: size,
    );
  }

  /// Saves raw bytes (e.g. a newly generated multi-page PDF) into the vault.
  Future<({String uuid, String relativePath, String fullPath, int sizeBytes})>
  saveDocumentBytes({
    required List<int> bytes,
    required int memberId,
    required int categoryId,
    required String originalName,
  }) async {
    if (bytes.isEmpty) {
      throw const DocumentImportException('Generated document is empty.');
    }
    if (bytes.length > maxFileSizeBytes) {
      throw const DocumentImportException(
        'Document exceeds the 100 MB per-document limit.',
      );
    }

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

    final docUuid = _uuid.v4();
    final ext = p.extension(originalName).toLowerCase();
    final physicalName = '$docUuid$ext';
    final relativePath = p.posix.join(
      'docs',
      'member_$memberId',
      'category_$categoryId',
      physicalName,
    );
    final fullPath = p.normalize(p.join(targetDir.path, physicalName));

    final savedFile = await File(fullPath).writeAsBytes(bytes, flush: true);
    final size = await savedFile.length();

    return (
      uuid: docUuid,
      relativePath: relativePath,
      fullPath: fullPath,
      sizeBytes: size,
    );
  }

  /// Converts a legacy absolute path into a portable relative path when possible.
  /// Returns null if the path cannot be safely stripped (caller keeps original).
  static String? extractRelativeSubpath(String rawPath) {
    if (rawPath.isEmpty) return null;
    if (!p.isAbsolute(rawPath) &&
        !rawPath.startsWith('/') &&
        !RegExp(r'^[a-zA-Z]:[\\/]').hasMatch(rawPath)) {
      return rawPath.replaceAll('\\', '/');
    }

    const markers = [
      'Documents/',
      'Documents\\',
      'app_flutter/',
      'app_flutter\\',
    ];
    for (final marker in markers) {
      final index = rawPath.indexOf(marker);
      if (index != -1) {
        return rawPath.substring(index + marker.length).replaceAll('\\', '/');
      }
    }
    return null;
  }

  /// Resolves any stored path (legacy absolute or new relative) to an existing file.
  /// Handles iOS container UUID changes between app updates.
  Future<String> resolveFilePath(String storedPath) async {
    if (storedPath.isEmpty) return '';

    final docsDir = await _getDocsDir();

    // 1. Relative path check first when storedPath is relative
    if (!p.isAbsolute(storedPath) &&
        !storedPath.startsWith('/') &&
        !RegExp(r'^[a-zA-Z]:[\\/]').hasMatch(storedPath)) {
      final relativeFile = File(p.normalize(p.join(docsDir.path, storedPath)));
      if (await relativeFile.exists()) {
        return relativeFile.path;
      }
    }

    // 2. Direct check: If file exists at stored path as-is (e.g. legacy Android path)
    final directFile = File(storedPath);
    if (await directFile.exists()) {
      return p.normalize(directFile.path);
    }

    // 3. iOS Container Migration: extract subpath after Documents/ or app_flutter/
    final extracted = extractRelativeSubpath(storedPath);
    if (extracted != null) {
      final candidate = File(p.normalize(p.join(docsDir.path, extracted)));
      if (await candidate.exists()) {
        return candidate.path;
      }
    }

    // Fallback: Return best resolved candidate path
    return p.normalize(p.join(docsDir.path, storedPath));
  }

  /// Safely deletes a physical file given its stored or resolved path.
  Future<bool> deletePhysicalFile(String storedPath) async {
    try {
      final resolved = await resolveFilePath(storedPath);
      if (resolved.isEmpty) return false;
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
