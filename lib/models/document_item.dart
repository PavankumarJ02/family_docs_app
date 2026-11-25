class DocumentItem {
  final int id;
  final String? uuid;
  final int memberId;
  final int categoryId;
  final String fileName;
  final String filePath;
  final int size;
  final String createdAt;
  final String syncStatus;
  final String? docType;
  final String? maskedId;
  final String? issueDate;
  final String? expiryDate;
  final bool expiryConfirmed;
  final String ocrStatus;
  final String? notes;

  const DocumentItem({
    required this.id,
    this.uuid,
    required this.memberId,
    required this.categoryId,
    required this.fileName,
    required this.filePath,
    required this.size,
    required this.createdAt,
    required this.syncStatus,
    this.docType,
    this.maskedId,
    this.issueDate,
    this.expiryDate,
    this.expiryConfirmed = false,
    this.ocrStatus = 'pending',
    this.notes,
  });

  factory DocumentItem.fromMap(Map<String, dynamic> map) {
    return DocumentItem(
      id: map['id'] as int,
      uuid: map['uuid'] as String?,
      memberId: (map['member_id'] as int?) ?? 0,
      categoryId: (map['category_id'] as int?) ?? 0,
      fileName: (map['file_name'] as String?) ?? 'Unnamed Document',
      filePath: (map['file_path'] as String?) ?? '',
      size: (map['size'] as int?) ?? 0,
      createdAt:
          (map['created_at'] as String?) ?? DateTime.now().toIso8601String(),
      syncStatus: (map['sync_status'] as String?) ?? 'local_only',
      docType: map['doc_type'] as String?,
      maskedId: map['masked_id'] as String?,
      issueDate: map['issue_date'] as String?,
      expiryDate: map['expiry_date'] as String?,
      expiryConfirmed: ((map['expiry_confirmed'] as int?) ?? 0) == 1,
      ocrStatus: (map['ocr_status'] as String?) ?? 'pending',
      notes: map['notes'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'uuid': uuid,
      'member_id': memberId,
      'category_id': categoryId,
      'file_name': fileName,
      'file_path': filePath,
      'size': size,
      'created_at': createdAt,
      'sync_status': syncStatus,
      'doc_type': docType,
      'masked_id': maskedId,
      'issue_date': issueDate,
      'expiry_date': expiryDate,
      'expiry_confirmed': expiryConfirmed ? 1 : 0,
      'ocr_status': ocrStatus,
      'notes': notes,
    };
  }

  DocumentItem copyWith({
    String? uuid,
    String? fileName,
    String? filePath,
    String? docType,
    String? maskedId,
    String? issueDate,
    String? expiryDate,
    bool? expiryConfirmed,
    String? ocrStatus,
    String? notes,
  }) {
    return DocumentItem(
      id: id,
      uuid: uuid ?? this.uuid,
      memberId: memberId,
      categoryId: categoryId,
      fileName: fileName ?? this.fileName,
      filePath: filePath ?? this.filePath,
      size: size,
      createdAt: createdAt,
      syncStatus: syncStatus,
      docType: docType ?? this.docType,
      maskedId: maskedId ?? this.maskedId,
      issueDate: issueDate ?? this.issueDate,
      expiryDate: expiryDate ?? this.expiryDate,
      expiryConfirmed: expiryConfirmed ?? this.expiryConfirmed,
      ocrStatus: ocrStatus ?? this.ocrStatus,
      notes: notes ?? this.notes,
    );
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

  DateTime? get parsedExpiryDate {
    if (expiryDate == null || expiryDate!.isEmpty) return null;
    try {
      return DateTime.parse(expiryDate!);
    } catch (_) {
      return null;
    }
  }

  int? get daysUntilExpiry {
    final exp = parsedExpiryDate;
    if (exp == null) return null;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(exp.year, exp.month, exp.day);
    return target.difference(today).inDays;
  }

  bool get isExpired {
    final days = daysUntilExpiry;
    return days != null && days < 0;
  }

  bool get isExpiringSoon {
    final days = daysUntilExpiry;
    return days != null && days >= 0 && days <= 30;
  }
}
