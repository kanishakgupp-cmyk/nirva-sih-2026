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
  final String? legalLabel;
  final DateTime createdAt;

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
}
