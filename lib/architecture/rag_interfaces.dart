/// Future RAG (Retrieval-Augmented Generation) & Encrypted Intelligence
/// architecture boundaries for Family Docs 2.0+.
///
/// Phase 2 defines these clean interfaces and data contracts ONLY.
/// No vector database, embeddings, or cloud/local LLM calls are executed yet.
/// Plaintext OCR content is never persisted.
library;

enum OcrProcessingStatus { pending, inProgress, completed, failed, manualOnly }

enum VaultSpaceType { personal, sharedFamily }

class RagAccessPermissions {
  final int ownerMemberId;
  final VaultSpaceType spaceType;
  final List<int> authorizedMemberIds;

  const RagAccessPermissions({
    required this.ownerMemberId,
    required this.spaceType,
    this.authorizedMemberIds = const [],
  });
}

class RagDocumentDescriptor {
  final String documentUuid;
  final int documentId;
  final int memberId;
  final int categoryId;
  final String vaultId;
  final int pageCount;
  final OcrProcessingStatus ocrStatus;
  final String? docType;
  final String? confirmedExpiryDate;
  final int version;
  final RagAccessPermissions permissions;

  const RagDocumentDescriptor({
    required this.documentUuid,
    required this.documentId,
    required this.memberId,
    required this.categoryId,
    required this.vaultId,
    required this.pageCount,
    required this.ocrStatus,
    this.docType,
    this.confirmedExpiryDate,
    this.version = 1,
    required this.permissions,
  });
}

class DocumentTextChunk {
  final String chunkId;
  final String documentUuid;
  final int pageNumber;
  final int chunkIndex;
  final String content; // Ephemeral in-memory or encrypted payload in future

  const DocumentTextChunk({
    required this.chunkId,
    required this.documentUuid,
    required this.pageNumber,
    required this.chunkIndex,
    required this.content,
  });
}

/// Port 1: Ephemeral On-Device OCR Processing
abstract class OcrProcessingPort {
  Future<List<String>> extractPageTexts(String resolvedFilePath);
}

/// Port 2: Document Classification
abstract class DocumentClassificationPort {
  Future<String> classifyDocument(String ephemeralText);
}

/// Port 3: Structured Metadata Extraction (Masked IDs, Issue/Expiry Dates)
abstract class MetadataExtractionPort {
  Future<Map<String, String?>> extractMetadata(String ephemeralText);
}

/// Port 4: Semantic Chunking (Future Encrypted Index / Vector Pipeline)
abstract class TextChunkerPort {
  List<DocumentTextChunk> chunkPages({
    required String documentUuid,
    required List<String> pageTexts,
    int maxChunkChars = 800,
    int overlapChars = 100,
  });
}

/// Port 5: Encrypted Retrieval (Future Phase 4/5 RAG)
abstract class EncryptedRetrievalPort {
  Future<List<DocumentTextChunk>> retrieveRelevantChunks({
    required String query,
    required int requestingMemberId,
    int topK = 5,
  });
}
