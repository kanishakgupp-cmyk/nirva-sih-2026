import 'dart:convert';
import 'dart:typed_data';

import 'package:shared_preferences/shared_preferences.dart';

const _queueKey = 'nirva.pending_evidence.v1';

enum EvidenceSyncState {
  pendingUpload,
  uploading,
  retryPending,
  syncFailed,
}

class PendingEvidence {
  const PendingEvidence({
    required this.operationId,
    required this.testId,
    required this.operatorId,
    required this.sessionData,
    required this.imageBytes,
    required this.imageSha256,
    required this.capturedAt,
    required this.latitude,
    required this.longitude,
    required this.gpsAccuracy,
    required this.imageQualityScore,
    required this.blurScore,
    required this.brightnessScore,
    required this.createdAt,
    required this.retryCount,
    required this.state,
    this.lastError,
  });

  final String operationId;
  final String testId;
  final String operatorId;
  final Map<String, dynamic> sessionData;
  final Uint8List imageBytes;
  final String imageSha256;
  final DateTime capturedAt;
  final double? latitude;
  final double? longitude;
  final double? gpsAccuracy;
  final double imageQualityScore;
  final double blurScore;
  final double brightnessScore;
  final DateTime createdAt;
  final int retryCount;
  final EvidenceSyncState state;
  final String? lastError;

  PendingEvidence copyWith({
    int? retryCount,
    EvidenceSyncState? state,
    String? lastError,
  }) {
    return PendingEvidence(
      operationId: operationId,
      testId: testId,
      operatorId: operatorId,
      sessionData: sessionData,
      imageBytes: imageBytes,
      imageSha256: imageSha256,
      capturedAt: capturedAt,
      latitude: latitude,
      longitude: longitude,
      gpsAccuracy: gpsAccuracy,
      imageQualityScore: imageQualityScore,
      blurScore: blurScore,
      brightnessScore: brightnessScore,
      createdAt: createdAt,
      retryCount: retryCount ?? this.retryCount,
      state: state ?? this.state,
      lastError: lastError ?? this.lastError,
    );
  }

  Map<String, dynamic> toJson() => {
        'operation_id': operationId,
        'test_id': testId,
        'operator_id': operatorId,
        'session_data': sessionData,
        'image_base64': base64Encode(imageBytes),
        'image_sha256': imageSha256,
        'captured_at': capturedAt.toUtc().toIso8601String(),
        'latitude': latitude,
        'longitude': longitude,
        'gps_accuracy': gpsAccuracy,
        'image_quality_score': imageQualityScore,
        'blur_score': blurScore,
        'brightness_score': brightnessScore,
        'created_at': createdAt.toUtc().toIso8601String(),
        'retry_count': retryCount,
        'state': state.name,
        'last_error': lastError,
      };

  factory PendingEvidence.fromJson(Map<String, dynamic> json) {
    return PendingEvidence(
      operationId: json['operation_id'] as String,
      testId: json['test_id'] as String,
      operatorId: json['operator_id'] as String,
      sessionData: Map<String, dynamic>.from(json['session_data'] as Map),
      imageBytes: Uint8List.fromList(base64Decode(json['image_base64'] as String)),
      imageSha256: json['image_sha256'] as String,
      capturedAt: DateTime.parse(json['captured_at'] as String),
      latitude: _double(json['latitude']),
      longitude: _double(json['longitude']),
      gpsAccuracy: _double(json['gps_accuracy']),
      imageQualityScore: _double(json['image_quality_score']) ?? 0,
      blurScore: _double(json['blur_score']) ?? 0,
      brightnessScore: _double(json['brightness_score']) ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
      retryCount: json['retry_count'] as int? ?? 0,
      state: EvidenceSyncState.values.firstWhere(
        (value) => value.name == json['state'],
        orElse: () => EvidenceSyncState.pendingUpload,
      ),
      lastError: json['last_error'] as String?,
    );
  }

  static double? _double(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse('$value');
  }
}

class OfflineEvidenceQueue {
  OfflineEvidenceQueue({SharedPreferences? preferences})
      : _preferencesFuture = preferences == null
            ? SharedPreferences.getInstance()
            : Future.value(preferences);

  final Future<SharedPreferences> _preferencesFuture;

  Future<List<PendingEvidence>> list() async {
    final preferences = await _preferencesFuture;
    final values = preferences.getStringList(_queueKey) ?? const <String>[];
    final items = <PendingEvidence>[];
    for (final value in values) {
      try {
        items.add(PendingEvidence.fromJson(
            Map<String, dynamic>.from(jsonDecode(value) as Map)));
      } on Object {
        // Drop only unreadable queue entries; valid evidence remains queued.
      }
    }
    items.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return items;
  }

  Future<int> pendingCount() async => (await list()).length;

  Future<void> enqueue(PendingEvidence item) async {
    final items = await list();
    if (items.any((existing) => existing.operationId == item.operationId)) return;
    await _save([...items, item]);
  }

  Future<void> replace(PendingEvidence item) async {
    final items = await list();
    final updated = items
        .map((existing) =>
            existing.operationId == item.operationId ? item : existing)
        .toList();
    await _save(updated);
  }

  Future<void> remove(String operationId) async {
    final items = await list();
    await _save(items.where((item) => item.operationId != operationId).toList());
  }

  Future<void> _save(List<PendingEvidence> items) async {
    final preferences = await _preferencesFuture;
    await preferences.setStringList(
      _queueKey,
      items.map((item) => jsonEncode(item.toJson())).toList(),
    );
  }
}
