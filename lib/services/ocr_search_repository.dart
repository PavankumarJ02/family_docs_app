import '../db/database_helper.dart';
import '../models/document_item.dart';

class SearchFilterCriteria {
  final String query;
  final int? memberId;
  final int? categoryId;
  final String? docType;
  final String? fileType; // 'pdf' | 'image'
  final bool onlyWithExpiry;

  const SearchFilterCriteria({
    this.query = '',
    this.memberId,
    this.categoryId,
    this.docType,
    this.fileType,
    this.onlyWithExpiry = false,
  });

  bool get hasActiveFilters =>
      query.trim().isNotEmpty ||
      memberId != null ||
      categoryId != null ||
      (docType != null && docType!.isNotEmpty) ||
      (fileType != null && fileType!.isNotEmpty) ||
      onlyWithExpiry;
}

/// Abstract repository interface for document search.
/// Phase 2 uses [MetadataOnlySearchRepository].
/// Future phases can plug in an encrypted SQLite FTS5 index implementation
/// without changing UI or provider contracts.
abstract class OcrSearchRepository {
  Future<List<DocumentItem>> search(SearchFilterCriteria criteria);
}

class MetadataOnlySearchRepository implements OcrSearchRepository {
  final DatabaseHelper _db;

  MetadataOnlySearchRepository({DatabaseHelper? db})
    : _db = db ?? DatabaseHelper.instance;

  @override
  Future<List<DocumentItem>> search(SearchFilterCriteria criteria) async {
    final rows = await _db.searchDocuments(
      criteria.query,
      memberId: criteria.memberId,
      categoryId: criteria.categoryId,
      docType: criteria.docType,
      fileType: criteria.fileType,
      onlyWithExpiry: criteria.onlyWithExpiry,
    );
    return rows.map((m) => DocumentItem.fromMap(m)).toList();
  }
}
