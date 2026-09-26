class EvidenceRecord {
  const EvidenceRecord({
    required this.id,
    required this.testId,
    required this.operatorId,
    required this.deviceId,
    required this.capturedAt,
    required this.latitude,
    required this.longitude,
    required this.gpsAccuracy,
    required this.imagePath,
    required this.imageSha256,
    required this.imageQualityScore,
    required this.blurScore,
    required this.brightnessScore,
    required this.glareScore,
    required this.referenceCardStatus,
    required this.calibrationStatus,
    required this.calibrationError,
    required this.result,
    required this.confidence,
    required this.modelVersion,
    required this.previousRecordHash,
    required this.recordHash,
    required this.signature,
    this.evidenceStatus = 'CAPTURED',
    this.normalizedImagePath,
    this.analysisStatus,
    this.analysisResult,
    this.analysisConfidence,
    this.analysisUncertainty,
    this.analysisModelVersion,
    this.analysisFeatures,
    this.analysisExplanation,
    this.analysisCompletedAt,
    this.signatureAlgorithm,
    this.keyId,
    required this.legalLabel,
    required this.createdAt,
  });

  final String id;
  final String testId;
  final String operatorId;
  final String? deviceId;
  final DateTime? capturedAt;
  final double? latitude;
  final double? longitude;
  final double? gpsAccuracy;
  final String? imagePath;
  final String? imageSha256;
  final double? imageQualityScore;
  final double? blurScore;
  final double? brightnessScore;
  final double? glareScore;
  final String? referenceCardStatus;
  final String? calibrationStatus;
  final double? calibrationError;
  final String? result;
  final double? confidence;
  final String? modelVersion;
  final String? previousRecordHash;
  final String? recordHash;
  final String? signature;
  final String evidenceStatus;
  final String? normalizedImagePath;
  final String? analysisStatus;
  final String? analysisResult;
  final double? analysisConfidence;
  final double? analysisUncertainty;
  final String? analysisModelVersion;
  final Map<String, dynamic>? analysisFeatures;
  final Map<String, dynamic>? analysisExplanation;
  final DateTime? analysisCompletedAt;
  final String? signatureAlgorithm;
  final String? keyId;
  final String? legalLabel;
  final DateTime createdAt;

  factory EvidenceRecord.localPending({
    required String operationId,
    required String testId,
    required String operatorId,
    required DateTime capturedAt,
    required double? latitude,
    required double? longitude,
    required double? gpsAccuracy,
    required String imageSha256,
    required double imageQualityScore,
    required double blurScore,
    required double brightnessScore,
  }) {
    return EvidenceRecord(
      id: 'local:$operationId',
      testId: testId,
      operatorId: operatorId,
      deviceId: null,
      capturedAt: capturedAt,
      latitude: latitude,
      longitude: longitude,
      gpsAccuracy: gpsAccuracy,
      imagePath: null,
      imageSha256: imageSha256,
      imageQualityScore: imageQualityScore,
      blurScore: blurScore,
      brightnessScore: brightnessScore,
      glareScore: null,
      referenceCardStatus: null,
      calibrationStatus: null,
      calibrationError: null,
      result: null,
      confidence: null,
      modelVersion: null,
      previousRecordHash: null,
      recordHash: null,
      signature: null,
      evidenceStatus: 'LOCAL_PENDING_UPLOAD',
      normalizedImagePath: null,
      analysisStatus: null,
      analysisResult: null,
      analysisConfidence: null,
      analysisUncertainty: null,
      analysisModelVersion: null,
      analysisFeatures: null,
      analysisExplanation: null,
      analysisCompletedAt: null,
      signatureAlgorithm: null,
      keyId: null,
      legalLabel: 'LOCAL CAPTURE - SERVER CONFIRMATION REQUIRED',
      createdAt: capturedAt,
    );
  }

  factory EvidenceRecord.fromMap(Map<String, dynamic> map) {
    return EvidenceRecord(
      id: map['id'] as String? ?? '',
      testId: map['test_id'] as String? ?? '',
      operatorId: map['operator_id'] as String? ?? '',
      deviceId: map['device_id'] as String?,
      capturedAt: _date(map['captured_at']),
      latitude: _double(map['latitude']),
      longitude: _double(map['longitude']),
      gpsAccuracy: _double(map['gps_accuracy']),
      imagePath: map['image_path'] as String?,
      imageSha256: map['image_sha256'] as String?,
      imageQualityScore: _double(map['image_quality_score']),
      blurScore: _double(map['blur_score']),
      brightnessScore: _double(map['brightness_score']),
      glareScore: _double(map['glare_score']),
      referenceCardStatus: map['reference_card_status'] as String?,
      calibrationStatus: map['calibration_status'] as String?,
      calibrationError: _double(map['calibration_error']),
      result: map['result'] as String?,
      confidence: _double(map['confidence']),
      modelVersion: map['model_version'] as String?,
      previousRecordHash: map['previous_record_hash'] as String?,
      recordHash: map['record_hash'] as String?,
      signature: map['signature'] as String?,
      evidenceStatus: map['evidence_status'] as String? ?? 'CAPTURED',
      normalizedImagePath: map['normalized_image_path'] as String?,
      analysisStatus: map['analysis_status'] as String?,
      analysisResult: map['analysis_result'] as String?,
      analysisConfidence: _double(map['analysis_confidence']),
      analysisUncertainty: _double(map['analysis_uncertainty']),
      analysisModelVersion: map['analysis_model_version'] as String?,
      analysisFeatures: _map(map['analysis_features']),
      analysisExplanation: _map(map['analysis_explanation']),
      analysisCompletedAt: _date(map['analysis_completed_at']),
      signatureAlgorithm: map['signature_algorithm'] as String?,
      keyId: map['key_id'] as String?,
      legalLabel: map['legal_label'] as String?,
      createdAt:
          _date(map['created_at']) ?? DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  static DateTime? _date(Object? value) {
    if (value is DateTime) return value.toLocal();
    if (value is String) return DateTime.tryParse(value)?.toLocal();
    return null;
  }

  static double? _double(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse('$value');
  }

  static Map<String, dynamic>? _map(Object? value) {
    if (value is Map) return Map<String, dynamic>.from(value);
    return null;
  }
}
