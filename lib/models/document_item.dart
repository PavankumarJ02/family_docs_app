class DocumentItem {
  final int id;
  final int memberId;
  final int categoryId;
  final String fileName;
  final String filePath;
  final int size;
  final String createdAt;
  final String syncStatus;

  const DocumentItem({
    required this.id,
    required this.memberId,
    required this.categoryId,
    required this.fileName,
    required this.filePath,
    required this.size,
    required this.createdAt,
    required this.syncStatus,
  });

  factory DocumentItem.fromMap(Map<String, dynamic> map) {
    return DocumentItem(
      id: map['id'] as int,
      memberId: (map['member_id'] as int?) ?? 0,
      categoryId: (map['category_id'] as int?) ?? 0,
      fileName: (map['file_name'] as String?) ?? 'Unnamed Document',
      filePath: (map['file_path'] as String?) ?? '',
      size: (map['size'] as int?) ?? 0,
      createdAt:
          (map['created_at'] as String?) ?? DateTime.now().toIso8601String(),
      syncStatus: (map['sync_status'] as String?) ?? 'local_only',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'member_id': memberId,
      'category_id': categoryId,
      'file_name': fileName,
      'file_path': filePath,
      'size': size,
      'created_at': createdAt,
      'sync_status': syncStatus,
    };
  }

  String get formattedSize {
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String get fileExtension {
    final dotIndex = fileName.lastIndexOf('.');
    if (dotIndex != -1 && dotIndex < fileName.length - 1) {
      return fileName.substring(dotIndex + 1).toLowerCase();
    }
    return '';
  }

  bool get isPdf => fileExtension == 'pdf';
  bool get isImage => ['jpg', 'jpeg', 'png', 'webp'].contains(fileExtension);

  String get formattedDate {
    try {
      final date = DateTime.parse(createdAt);
      return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    } catch (_) {
      return createdAt.split('T')[0];
    }
  }
}
