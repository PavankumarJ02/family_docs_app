/// Supported document types for Phase 2 deterministic local classification.
class DocumentTypes {
  static const String aadhaar = 'Aadhaar';
  static const String pan = 'PAN';
  static const String passport = 'Passport';
  static const String voterId = 'Voter ID';
  static const String drivingLicence = 'Driving Licence';
  static const String insurance = 'Insurance';
  static const String education = 'Education Certificate';
  static const String medical = 'Medical Report';
  static const String bank = 'Bank Document';
  static const String other = 'Other';

  static const List<String> all = [
    aadhaar,
    pan,
    passport,
    voterId,
    drivingLicence,
    insurance,
    education,
    medical,
    bank,
    other,
  ];
}

class ClassificationResult {
  final String suggestedType;
  final double confidence;
  final bool isLowConfidence;
  final String? maskedIdentifier;
  final List<String> matchedSignals;

  const ClassificationResult({
    required this.suggestedType,
    required this.confidence,
    required this.isLowConfidence,
    this.maskedIdentifier,
    this.matchedSignals = const [],
  });
}

/// On-device deterministic document classification & privacy-preserving
/// identifier masking engine.
/// Pattern matching is assistive only and never treated as official verification.
class DocumentClassifierService {
  static const double lowConfidenceThreshold = 0.45;

  ClassificationResult classify(String rawText) {
    if (rawText.trim().isEmpty) {
      return const ClassificationResult(
        suggestedType: DocumentTypes.other,
        confidence: 0.0,
        isLowConfidence: true,
      );
    }

    final upper = rawText.toUpperCase();
    final scores = <String, double>{for (final t in DocumentTypes.all) t: 0.0};
    final signals = <String, List<String>>{
      for (final t in DocumentTypes.all) t: <String>[],
    };
    final maskedIds = <String, String>{};

    // 1. Aadhaar
    if (upper.contains('AADHAAR') ||
        upper.contains('UNIQUE IDENTIFICATION AUTHORITY') ||
        upper.contains('UIDAI') ||
        upper.contains('MERA AADHAAR')) {
      scores[DocumentTypes.aadhaar] = scores[DocumentTypes.aadhaar]! + 0.55;
      signals[DocumentTypes.aadhaar]!.add('UIDAI/Aadhaar keyword');
    }
    final aadhaarMatch = RegExp(
      r'\b([2-9][0-9]{3}[\s-]?[0-9]{4}[\s-]?[0-9]{4})\b',
    ).firstMatch(upper);
    if (aadhaarMatch != null) {
      final digits = aadhaarMatch.group(1)!.replaceAll(RegExp(r'[\s-]'), '');
      final validChecksum = verifyVerhoeff(digits);
      scores[DocumentTypes.aadhaar] =
          scores[DocumentTypes.aadhaar]! + (validChecksum ? 0.40 : 0.25);
      signals[DocumentTypes.aadhaar]!.add(
        validChecksum ? '12-digit ID (Verhoeff valid)' : '12-digit pattern',
      );
      maskedIds[DocumentTypes.aadhaar] =
          'XXXX-XXXX-${digits.substring(digits.length - 4)}';
    }

    // 2. PAN
    if (upper.contains('INCOME TAX DEPARTMENT') ||
        upper.contains('PERMANENT ACCOUNT NUMBER') ||
        upper.contains('GOVT. OF INDIA') && upper.contains('PAN')) {
      scores[DocumentTypes.pan] = scores[DocumentTypes.pan]! + 0.50;
      signals[DocumentTypes.pan]!.add('Income Tax / PAN label');
    }
    final panMatch = RegExp(r'\b([A-Z]{5}[0-9]{4}[A-Z])\b').firstMatch(upper);
    if (panMatch != null) {
      final pan = panMatch.group(1)!;
      scores[DocumentTypes.pan] = scores[DocumentTypes.pan]! + 0.45;
      signals[DocumentTypes.pan]!.add('PAN format');
      maskedIds[DocumentTypes.pan] =
          '${pan.substring(0, 2)}XXX${pan.substring(5)}';
    }

    // 3. Passport
    if (upper.contains('PASSPORT') ||
        upper.contains('REPUBLIC OF INDIA') && upper.contains('NATIONALITY') ||
        upper.contains('P<IND')) {
      scores[DocumentTypes.passport] = scores[DocumentTypes.passport]! + 0.55;
      signals[DocumentTypes.passport]!.add('Passport/MRZ header');
    }
    final passportMatch = RegExp(r'\b([A-Z][0-9]{7})\b').firstMatch(upper);
    if (passportMatch != null && scores[DocumentTypes.passport]! > 0) {
      final pp = passportMatch.group(1)!;
      scores[DocumentTypes.passport] = scores[DocumentTypes.passport]! + 0.35;
      signals[DocumentTypes.passport]!.add('Passport number format');
      maskedIds[DocumentTypes.passport] =
          '${pp.substring(0, 1)}XXXX${pp.substring(5)}';
    }

    // 4. Voter ID
    if (upper.contains('ELECTION COMMISSION') ||
        upper.contains('ELECTOR PHOTO IDENTITY') ||
        upper.contains('EPIC') ||
        upper.contains('VOTER')) {
      scores[DocumentTypes.voterId] = scores[DocumentTypes.voterId]! + 0.55;
      signals[DocumentTypes.voterId]!.add('Election Commission label');
    }
    final voterMatch = RegExp(r'\b([A-Z]{3}[0-9]{7})\b').firstMatch(upper);
    if (voterMatch != null && scores[DocumentTypes.voterId]! > 0) {
      final vid = voterMatch.group(1)!;
      scores[DocumentTypes.voterId] = scores[DocumentTypes.voterId]! + 0.35;
      signals[DocumentTypes.voterId]!.add('EPIC format');
      maskedIds[DocumentTypes.voterId] =
          '${vid.substring(0, 3)}XXXX${vid.substring(7)}';
    }

    // 5. Driving Licence
    if (upper.contains('DRIVING LICENCE') ||
        upper.contains('DRIVING LICENSE') ||
        upper.contains('MOTOR VEHICLES') ||
        upper.contains('TRANSPORT DEPARTMENT')) {
      scores[DocumentTypes.drivingLicence] =
          scores[DocumentTypes.drivingLicence]! + 0.55;
      signals[DocumentTypes.drivingLicence]!.add('Driving Licence label');
    }
    final dlMatch = RegExp(
      r'\b([A-Z]{2}[0-9]{2}[\s-]?[0-9]{4}[0-9]{7})\b',
    ).firstMatch(upper);
    if (dlMatch != null) {
      final dl = dlMatch.group(1)!.replaceAll(RegExp(r'[\s-]'), '');
      scores[DocumentTypes.drivingLicence] =
          scores[DocumentTypes.drivingLicence]! + 0.35;
      signals[DocumentTypes.drivingLicence]!.add('DL number format');
      maskedIds[DocumentTypes.drivingLicence] =
          '${dl.substring(0, 4)}XXXXXXX${dl.substring(dl.length - 4)}';
    }

    // 6. Insurance
    if (upper.contains('INSURANCE') ||
        upper.contains('POLICY NO') ||
        upper.contains('POLICY NUMBER') ||
        upper.contains('SUM INSURED') ||
        upper.contains('PREMIUM')) {
      scores[DocumentTypes.insurance] = scores[DocumentTypes.insurance]! + 0.65;
      signals[DocumentTypes.insurance]!.add('Insurance policy terms');
    }

    // 7. Education Certificate
    if (upper.contains('UNIVERSITY') ||
        upper.contains('DEGREE') ||
        upper.contains('MARKSHEET') ||
        upper.contains('TRANSCRIPT') ||
        upper.contains('BOARD OF SECONDARY') ||
        upper.contains('CERTIFICATE OF MERIT') ||
        upper.contains('CGPA') ||
        upper.contains('GRADE SHEET')) {
      scores[DocumentTypes.education] = scores[DocumentTypes.education]! + 0.65;
      signals[DocumentTypes.education]!.add('Academic/Education terms');
    }

    // 8. Medical Report
    if (upper.contains('DIAGNOSTIC') ||
        upper.contains('LABORATORY') ||
        upper.contains('PATHOLOGY') ||
        upper.contains('PRESCRIPTION') ||
        upper.contains('HOSPITAL') ||
        upper.contains('PATIENT NAME') ||
        upper.contains('HEMOGLOBIN') ||
        upper.contains('CLINICAL')) {
      scores[DocumentTypes.medical] = scores[DocumentTypes.medical]! + 0.65;
      signals[DocumentTypes.medical]!.add('Medical/Clinical terms');
    }

    // 9. Bank Document
    if (upper.contains('ACCOUNT STATEMENT') ||
        upper.contains('IFSC') ||
        upper.contains('PASSBOOK') ||
        upper.contains('BRANCH CODE') ||
        upper.contains('SAVINGS ACCOUNT') ||
        upper.contains('CHEQUE')) {
      scores[DocumentTypes.bank] = scores[DocumentTypes.bank]! + 0.65;
      signals[DocumentTypes.bank]!.add('Banking/IFSC terms');
    }

    // Pick highest scoring type
    String bestType = DocumentTypes.other;
    double bestScore = 0.0;
    for (final entry in scores.entries) {
      if (entry.value > bestScore) {
        bestScore = entry.value;
        bestType = entry.key;
      }
    }

    final clamped = bestScore.clamp(0.0, 0.99);
    final isLow = clamped < lowConfidenceThreshold;

    return ClassificationResult(
      suggestedType: isLow ? DocumentTypes.other : bestType,
      confidence: clamped,
      isLowConfidence: isLow,
      maskedIdentifier: isLow ? null : maskedIds[bestType],
      matchedSignals: signals[bestType] ?? const [],
    );
  }

  /// Verhoeff checksum validation for 12-digit Aadhaar numbers.
  static bool verifyVerhoeff(String num) {
    if (!RegExp(r'^\d{12}$').hasMatch(num)) return false;

    const d = [
      [0, 1, 2, 3, 4, 5, 6, 7, 8, 9],
      [1, 2, 3, 4, 0, 6, 7, 8, 9, 5],
      [2, 3, 4, 0, 1, 7, 8, 9, 5, 6],
      [3, 4, 0, 1, 2, 8, 9, 5, 6, 7],
      [4, 0, 1, 2, 3, 9, 5, 6, 7, 8],
      [5, 9, 8, 7, 6, 0, 4, 3, 2, 1],
      [6, 5, 9, 8, 7, 1, 0, 4, 3, 2],
      [7, 6, 5, 9, 8, 2, 1, 0, 4, 3],
      [8, 7, 6, 5, 9, 3, 2, 1, 0, 4],
      [9, 8, 7, 6, 5, 4, 3, 2, 1, 0],
    ];
    const p = [
      [0, 1, 2, 3, 4, 5, 6, 7, 8, 9],
      [1, 5, 7, 6, 2, 8, 3, 0, 9, 4],
      [5, 8, 0, 3, 7, 9, 6, 1, 4, 2],
      [8, 9, 1, 6, 0, 4, 3, 5, 2, 7],
      [9, 4, 5, 3, 1, 2, 6, 8, 7, 0],
      [4, 2, 8, 6, 5, 7, 3, 9, 0, 1],
      [2, 7, 9, 3, 8, 0, 6, 4, 1, 5],
      [7, 0, 4, 6, 9, 1, 3, 2, 5, 8],
    ];

    var c = 0;
    final reversed = num.split('').reversed.map(int.parse).toList();
    for (var i = 0; i < reversed.length; i++) {
      c = d[c][p[i % 8][reversed[i]]];
    }
    return c == 0;
  }
}
