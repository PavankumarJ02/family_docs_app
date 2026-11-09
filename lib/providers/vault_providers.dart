import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../db/database_helper.dart';
import '../models/member.dart';
import '../models/category_item.dart';
import '../models/document_item.dart';

/// Database helper instance provider
final databaseHelperProvider = Provider<DatabaseHelper>((ref) {
  return DatabaseHelper.instance;
});

/// Vault summary metrics model
class VaultMetrics {
  final int totalDocuments;
  final int totalMembers;
  final int totalStorageBytes;

  const VaultMetrics({
    this.totalDocuments = 0,
    this.totalMembers = 0,
    this.totalStorageBytes = 0,
  });

  String get formattedStorage {
    if (totalStorageBytes < 1024) return '$totalStorageBytes B';
    if (totalStorageBytes < 1024 * 1024) {
      return '${(totalStorageBytes / 1024).toStringAsFixed(1)} KB';
    }
    if (totalStorageBytes < 1024 * 1024 * 1024) {
      return '${(totalStorageBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(totalStorageBytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}

/// Provides overall vault metrics
final vaultMetricsProvider = FutureProvider<VaultMetrics>((ref) async {
  final db = ref.watch(databaseHelperProvider);
  final totalDocs = await db.getTotalDocumentCount();
  final members = await db.getMembers();
  final totalBytes = await db.getTotalStorageBytes();

  return VaultMetrics(
    totalDocuments: totalDocs,
    totalMembers: members.length,
    totalStorageBytes: totalBytes,
  );
});

/// Provides family members with document counts
final membersListProvider = FutureProvider<List<Member>>((ref) async {
  final db = ref.watch(databaseHelperProvider);
  final rawMembers = await db.getMembers();

  final members = <Member>[];
  for (var i = 0; i < rawMembers.length; i++) {
    final raw = rawMembers[i];
    final memberId = raw['id'] as int;
    final count = await db.getMemberDocumentCount(memberId);
    // Designate first member as Admin if not explicitly given
    final role = i == 0 ? 'Admin' : 'Member';
    members.add(Member.fromMap(raw, documentCount: count).copyWithRole(role));
  }
  return members;
});

extension MemberCopyWith on Member {
  Member copyWithRole(String newRole) {
    return Member(
      id: id,
      name: name,
      role: newRole,
      documentCount: documentCount,
    );
  }
}

/// Provides recent documents for main dashboard
final recentDocumentsProvider = FutureProvider<List<DocumentItem>>((ref) async {
  final db = ref.watch(databaseHelperProvider);
  final rawDocs = await db.getRecentDocuments(limit: 6);
  return rawDocs.map((m) => DocumentItem.fromMap(m)).toList();
});

/// Provides categories for a specific member
final memberCategoriesProvider = FutureProvider.family<List<CategoryItem>, int>(
  (ref, memberId) async {
    final db = ref.watch(databaseHelperProvider);
    final rawCategories = await db.getCategories(memberId);

    final categories = <CategoryItem>[];
    for (final raw in rawCategories) {
      final catId = raw['id'] as int;
      final count = await db.getCategoryDocumentCount(catId);
      categories.add(CategoryItem.fromMap(raw, documentCount: count));
    }
    return categories;
  },
);

/// Provides documents for a specific category
final categoryDocumentsProvider =
    FutureProvider.family<List<DocumentItem>, ({int memberId, int categoryId})>(
      (ref, arg) async {
        final db = await ref.watch(databaseHelperProvider).database;
        final data = await db.query(
          'documents',
          where: 'member_id = ? AND category_id = ?',
          whereArgs: [arg.memberId, arg.categoryId],
          orderBy: 'created_at DESC',
        );
        return data.map((m) => DocumentItem.fromMap(m)).toList();
      },
    );

/// Search query provider
final searchQueryProvider = StateProvider<String>((ref) => '');

/// Search results provider
final searchResultsProvider = FutureProvider<List<DocumentItem>>((ref) async {
  final query = ref.watch(searchQueryProvider).trim();
  if (query.isEmpty) return [];

  final db = ref.watch(databaseHelperProvider);
  final results = await db.searchDocuments(query);
  return results.map((m) => DocumentItem.fromMap(m)).toList();
});
