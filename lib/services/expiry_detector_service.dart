class DateCandidate {
  final String normalizedIsoDate; // YYYY-MM-DD
  final String rawText;
  final String matchedLabel;
  final bool isExplicitExpiry;
  final bool isExplicitIssue;

  const DateCandidate({
    required this.normalizedIsoDate,
    required this.rawText,
    required this.matchedLabel,
    this.isExplicitExpiry = false,
    this.isExplicitIssue = false,
  });

  DateTime? get asDateTime => DateTime.tryParse(normalizedIsoDate);
}

class ExpiryDetectionResult {
  final DateCandidate? primaryExpiry;
  final DateCandidate? primaryIssue;
  final List<DateCandidate> allCandidates;
  final bool isAmbiguous;

  const ExpiryDetectionResult({
    this.primaryExpiry,
    this.primaryIssue,
    this.allCandidates = const [],
    this.isAmbiguous = false,
  });

  bool get hasExpiryCandidate => primaryExpiry != null;
}

/// Detects labeled expiry and issue dates from in-memory OCR text.
/// Never invents expiry dates or assumes unlabeled dates are expiry dates.
class ExpiryDetectorService {
  static const _months = <String, int>{
    'JAN': 1,
    'FEB': 2,
    'MAR': 3,
    'APR': 4,
    'MAY': 5,
    'JUN': 6,
    'JUL': 7,
    'AUG': 8,
    'SEP': 9,
    'SEPT': 9,
    'OCT': 10,
    'NOV': 11,
    'DEC': 12,
  };

  static final RegExp _expiryPattern = RegExp(
    r'(DATE\s+OF\s+EXPIRY|EXPIRY\s+DATE|VALID\s+UNTIL|VALID\s+UP\s*TO|VALID\s+UPTO|VALID\s+TILL|VALID\s+THRU|POLICY\s+END\s+DATE|EXPIRES\s+ON|EXP\.?\s*DATE)\s*[:\-]?\s*([0-9]{1,2}[\/\-\.\s](?:[0-9]{1,2}|[A-Za-z]{3,4})[\/\-\.\s][0-9]{2,4}|[0-9]{4}[\/\-][0-9]{1,2}[\/\-][0-9]{1,2})',
    caseSensitive: false,
  );

  static final RegExp _issuePattern = RegExp(
    r'(DATE\s+OF\s+ISSUE|ISSUE\s+DATE|ISSUED\s+ON|POLICY\s+START\s+DATE|VALID\s+FROM)\s*[:\-]?\s*([0-9]{1,2}[\/\-\.\s](?:[0-9]{1,2}|[A-Za-z]{3,4})[\/\-\.\s][0-9]{2,4}|[0-9]{4}[\/\-][0-9]{1,2}[\/\-][0-9]{1,2})',
    caseSensitive: false,
  );

  ExpiryDetectionResult detect(String rawText) {
    if (rawText.trim().isEmpty) {
      return const ExpiryDetectionResult();
    }

    final expiryCandidates = <DateCandidate>[];
    final issueCandidates = <DateCandidate>[];

    for (final m in _expiryPattern.allMatches(rawText)) {
      final label = m.group(1)?.trim() ?? 'Expiry';
      final rawDate = m.group(2)?.trim() ?? '';
      final iso = normalizeDate(rawDate);
      if (iso != null) {
        expiryCandidates.add(
          DateCandidate(
            normalizedIsoDate: iso,
            rawText: rawDate,
            matchedLabel: label,
            isExplicitExpiry: true,
          ),
        );
      }
    }

    for (final m in _issuePattern.allMatches(rawText)) {
      final label = m.group(1)?.trim() ?? 'Issue Date';
      final rawDate = m.group(2)?.trim() ?? '';
      final iso = normalizeDate(rawDate);
      if (iso != null) {
        issueCandidates.add(
          DateCandidate(
            normalizedIsoDate: iso,
            rawText: rawDate,
            matchedLabel: label,
            isExplicitIssue: true,
          ),
        );
      }
    }

    final uniqueExpiryIso = expiryCandidates
        .map((c) => c.normalizedIsoDate)
        .toSet();

    return ExpiryDetectionResult(
      primaryExpiry: expiryCandidates.isNotEmpty
          ? expiryCandidates.first
          : null,
      primaryIssue: issueCandidates.isNotEmpty ? issueCandidates.first : null,
      allCandidates: [...expiryCandidates, ...issueCandidates],
      isAmbiguous: uniqueExpiryIso.length > 1,
    );
  }

  /// Normalizes DD/MM/YYYY, DD-MM-YYYY, YYYY-MM-DD, and DD MMM YYYY into YYYY-MM-DD.
  static String? normalizeDate(String raw) {
    final cleaned = raw.trim().replaceAll(RegExp(r'\s+'), ' ');

    // 1. YYYY-MM-DD or YYYY/MM/DD
    final isoMatch = RegExp(
      r'^([0-9]{4})[\/\-]([0-9]{1,2})[\/\-]([0-9]{1,2})$',
    ).firstMatch(cleaned);
    if (isoMatch != null) {
      final y = int.parse(isoMatch.group(1)!);
      final m = int.parse(isoMatch.group(2)!);
      final d = int.parse(isoMatch.group(3)!);
      return _validateAndFormat(y, m, d);
    }

    // 2. DD/MM/YYYY, DD-MM-YYYY, DD.MM.YYYY
    final dmyMatch = RegExp(
      r'^([0-9]{1,2})[\/\-\.]([0-9]{1,2})[\/\-\.]([0-9]{2,4})$',
    ).firstMatch(cleaned);
    if (dmyMatch != null) {
      final d = int.parse(dmyMatch.group(1)!);
      final m = int.parse(dmyMatch.group(2)!);
      var y = int.parse(dmyMatch.group(3)!);
      if (y < 100) y += 2000;
      return _validateAndFormat(y, m, d);
    }

    // 3. DD MMM YYYY or DD-MMM-YYYY
    final textMonthMatch = RegExp(
      r'^([0-9]{1,2})[\s\-\.]([A-Za-z]{3,4})[\s\-\.]([0-9]{2,4})$',
    ).firstMatch(cleaned);
    if (textMonthMatch != null) {
      final d = int.parse(textMonthMatch.group(1)!);
      final monStr = textMonthMatch.group(2)!.toUpperCase();
      final m = _months[monStr];
      if (m == null) return null;
      var y = int.parse(textMonthMatch.group(3)!);
      if (y < 100) y += 2000;
      return _validateAndFormat(y, m, d);
    }

    return null;
  }

  static String? _validateAndFormat(int year, int month, int day) {
    if (year < 1900 ||
        year > 2150 ||
        month < 1 ||
        month > 12 ||
        day < 1 ||
        day > 31) {
      return null;
    }
    final dt = DateTime(year, month, day);
    if (dt.year != year || dt.month != month || dt.day != day) return null;
    return '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
  }
}
