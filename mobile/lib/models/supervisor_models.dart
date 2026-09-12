class SupervisorOverview {
  const SupervisorOverview({
    required this.totalCases,
    required this.totalTestSessions,
    required this.totalEvidenceRecords,
    required this.pendingReview,
    required this.analyzedEvidence,
    required this.finalizedEvidence,
    required this.flaggedEvidence,
    required this.returnedEvidence,
  });

  final int totalCases;
  final int totalTestSessions;
  final int totalEvidenceRecords;
  final int pendingReview;
  final int analyzedEvidence;
  final int finalizedEvidence;
  final int flaggedEvidence;
  final int returnedEvidence;

  factory SupervisorOverview.fromMap(Map<String, dynamic> map) {
    return SupervisorOverview(
      totalCases: map['total_cases'] as int? ?? 0,
      totalTestSessions: map['total_test_sessions'] as int? ?? 0,
      totalEvidenceRecords: map['total_evidence_records'] as int? ?? 0,
      pendingReview: map['pending_review'] as int? ?? 0,
      analyzedEvidence: map['analyzed_evidence'] as int? ?? 0,
      finalizedEvidence: map['finalized_evidence'] as int? ?? 0,
      flaggedEvidence: map['flagged_evidence'] as int? ?? 0,
      returnedEvidence: map['returned_evidence'] as int? ?? 0,
    );
  }
}

class SupervisorEvidenceSummary {
  const SupervisorEvidenceSummary({
    required this.id,
    required this.testId,
    required this.testNumber,
    required this.caseNumber,
    required this.operator,
    required this.capturedAt,
    required this.evidenceStatus,
    required this.reviewStatus,
    this.reviewReason,
    required this.analysisResult,
    required this.confidence,
    required this.integrityStatus,
    required this.finalized,
  });

  final String id;
  final String testId;
  final String? testNumber;
  final String? caseNumber;
  final String? operator;
  final DateTime? capturedAt;
  final String evidenceStatus;
  final String reviewStatus;
  final String? reviewReason;
  final String? analysisResult;
  final double? confidence;
  final String integrityStatus;
  final bool finalized;

  factory SupervisorEvidenceSummary.fromMap(Map<String, dynamic> map) {
    return SupervisorEvidenceSummary(
      id: map['id'] as String? ?? '',
      testId: map['test_id'] as String? ?? '',
      testNumber: map['test_number'] as String?,
      caseNumber: map['case_number'] as String?,
      operator: map['operator'] as String?,
      capturedAt: _date(map['captured_at']),
      evidenceStatus: map['evidence_status'] as String? ?? 'CAPTURED',
      reviewStatus: map['review_status'] as String? ?? 'PENDING',
      reviewReason: map['review_reason'] as String?,
      analysisResult: map['analysis_result'] as String?,
      confidence: _double(map['confidence']),
      integrityStatus: map['integrity_status'] as String? ?? 'UNKNOWN',
      finalized: map['finalized'] as bool? ?? false,
    );
  }

  static DateTime? _date(Object? value) => value is String ? DateTime.tryParse(value) : null;
  static double? _double(Object? value) => value is num ? value.toDouble() : double.tryParse('$value');
}

class SupervisorEvidenceDetail extends SupervisorEvidenceSummary {
  const SupervisorEvidenceDetail({
    required super.id,
    required super.testId,
    required super.testNumber,
    required super.caseNumber,
    required super.operator,
    required super.capturedAt,
    required super.evidenceStatus,
    required super.reviewStatus,
    super.reviewReason,
    required super.analysisResult,
    required super.confidence,
    required super.integrityStatus,
    required super.finalized,
    required this.operatorId,
    required this.latitude,
    required this.longitude,
    required this.gpsAccuracy,
    required this.imageQualityScore,
    required this.blurScore,
    required this.brightnessScore,
    required this.imageSha256,
    required this.imageUrl,
    required this.analysisUncertainty,
    required this.modelVersion,
    required this.legalLabel,
    this.reviewedBy,
    this.reviewedAt,
    required this.auditHistory,
  });

  final String operatorId;
  final double? latitude;
  final double? longitude;
  final double? gpsAccuracy;
  final double? imageQualityScore;
  final double? blurScore;
  final double? brightnessScore;
  final String? imageSha256;
  final String? imageUrl;
  final double? analysisUncertainty;
  final String? modelVersion;
  final String? legalLabel;
  final String? reviewedBy;
  final DateTime? reviewedAt;
  final List<Map<String, dynamic>> auditHistory;

  factory SupervisorEvidenceDetail.fromMap(Map<String, dynamic> map) {
    final summary = SupervisorEvidenceSummary.fromMap(map);
    return SupervisorEvidenceDetail(
      id: summary.id,
      testId: summary.testId,
      testNumber: summary.testNumber,
      caseNumber: summary.caseNumber,
      operator: summary.operator,
      capturedAt: summary.capturedAt,
      evidenceStatus: summary.evidenceStatus,
      reviewStatus: summary.reviewStatus,
      reviewReason: summary.reviewReason,
      analysisResult: summary.analysisResult,
      confidence: summary.confidence,
      integrityStatus: summary.integrityStatus,
      finalized: summary.finalized,
      operatorId: map['operator_id'] as String? ?? '',
      latitude: SupervisorEvidenceSummary._double(map['latitude']),
      longitude: SupervisorEvidenceSummary._double(map['longitude']),
      gpsAccuracy: SupervisorEvidenceSummary._double(map['gps_accuracy']),
      imageQualityScore: SupervisorEvidenceSummary._double(map['image_quality_score']),
      blurScore: SupervisorEvidenceSummary._double(map['blur_score']),
      brightnessScore: SupervisorEvidenceSummary._double(map['brightness_score']),
      imageSha256: map['image_sha256'] as String?,
      imageUrl: map['image_url'] as String?,
      analysisUncertainty: SupervisorEvidenceSummary._double(map['analysis_uncertainty']),
      modelVersion: map['model_version'] as String?,
      legalLabel: map['legal_label'] as String?,
      reviewedBy: map['reviewed_by'] as String?,
      reviewedAt: SupervisorEvidenceSummary._date(map['reviewed_at']),
      auditHistory: (map['audit_history'] as List<dynamic>? ?? [])
          .map((event) => Map<String, dynamic>.from(event as Map))
          .toList(),
    );
  }
}