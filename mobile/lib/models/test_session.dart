class TestSession {
  const TestSession({
    required this.id,
    required this.testNumber,
    required this.caseId,
    required this.kitId,
    required this.operatorId,
    required this.sessionNonce,
    required this.reagentProtocol,
    required this.startedAt,
    required this.capturedAt,
    required this.reactionTimeSeconds,
    required this.latitude,
    required this.longitude,
    required this.gpsAccuracy,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String testNumber;
  final String caseId;
  final String? kitId;
  final String operatorId;
  final String sessionNonce;
  final String? reagentProtocol;
  final DateTime? startedAt;
  final DateTime? capturedAt;
  final int? reactionTimeSeconds;
  final double? latitude;
  final double? longitude;
  final double? gpsAccuracy;
  final String status;
  final DateTime createdAt;

  factory TestSession.fromMap(Map<String, dynamic> map) {
    return TestSession(
      id: map['id'] as String? ?? '',
      testNumber: map['test_number'] as String? ?? '',
      caseId: map['case_id'] as String? ?? '',
      kitId: map['kit_id'] as String?,
      operatorId: map['operator_id'] as String? ?? '',
      sessionNonce: map['session_nonce'] as String? ?? '',
      reagentProtocol: map['reagent_protocol'] as String?,
      startedAt: _parseDateTime(map['started_at']),
      capturedAt: _parseDateTime(map['captured_at']),
      reactionTimeSeconds: _parseInt(map['reaction_time_seconds']),
      latitude: _parseDouble(map['latitude']),
      longitude: _parseDouble(map['longitude']),
      gpsAccuracy: _parseDouble(map['gps_accuracy']),
      status: map['status'] as String? ?? 'CREATED',
      createdAt: _parseDateTime(map['created_at']) ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  static DateTime? _parseDateTime(Object? value) {
    if (value is DateTime) {
      return value.toLocal();
    }
    if (value is String) {
      return DateTime.tryParse(value)?.toLocal();
    }
    return null;
  }

  static int? _parseInt(Object? value) {
    if (value is int) {
      return value;
    }
    return int.tryParse('$value');
  }

  static double? _parseDouble(Object? value) {
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse('$value');
  }
}
