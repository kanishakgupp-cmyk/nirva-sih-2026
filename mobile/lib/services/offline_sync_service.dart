import 'dart:math';
import 'dart:typed_data';

import '../models/evidence_record.dart';
import '../models/test_session.dart';
import 'evidence_hash_service.dart';
import 'evidence_service.dart';
import 'offline_evidence_queue.dart';

class OfflineFirstEvidenceService implements EvidenceService {
  OfflineFirstEvidenceService({
    EvidenceService? remote,
    OfflineEvidenceQueue? queue,
  })  : _remote = remote ?? FastApiEvidenceService(),
        _queue = queue ?? OfflineEvidenceQueue();

  final EvidenceService _remote;
  final OfflineEvidenceQueue _queue;
  static const _hashService = EvidenceHashService();

  @override
  Future<EvidenceRecord> createEvidenceRecord({
    required TestSession session,
    required Uint8List imageBytes,
    required DateTime capturedAt,
    required double? latitude,
    required double? longitude,
    required double? gpsAccuracy,
    required double imageQualityScore,
    required double sharpnessScore,
    required double brightnessScore,
    String? clientOperationId,
  }) async {
    final operationId = clientOperationId ?? _newOperationId();
    try {
      return await _remote.createEvidenceRecord(
        session: session,
        imageBytes: imageBytes,
        capturedAt: capturedAt,
        latitude: latitude,
        longitude: longitude,
        gpsAccuracy: gpsAccuracy,
        imageQualityScore: imageQualityScore,
        sharpnessScore: sharpnessScore,
        brightnessScore: brightnessScore,
        clientOperationId: operationId,
      );
    } on EvidenceServiceException catch (error) {
      if (!error.recoverable) rethrow;
      final item = PendingEvidence(
        operationId: operationId,
        testId: session.id,
        operatorId: session.operatorId,
        sessionData: {
          'id': session.id,
          'test_number': session.testNumber,
          'case_id': session.caseId,
          'kit_id': session.kitId,
          'operator_id': session.operatorId,
          'session_nonce': session.sessionNonce,
          'reagent_protocol': session.reagentProtocol,
          'started_at': session.startedAt?.toUtc().toIso8601String(),
          'captured_at': session.capturedAt?.toUtc().toIso8601String(),
          'reaction_time_seconds': session.reactionTimeSeconds,
          'latitude': session.latitude,
          'longitude': session.longitude,
          'gps_accuracy': session.gpsAccuracy,
          'status': session.status,
          'created_at': session.createdAt.toUtc().toIso8601String(),
        },
        imageBytes: imageBytes,
        imageSha256: _hashService.sha256Bytes(imageBytes),
        capturedAt: capturedAt,
        latitude: latitude,
        longitude: longitude,
        gpsAccuracy: gpsAccuracy,
        imageQualityScore: imageQualityScore,
        blurScore: sharpnessScore,
        brightnessScore: brightnessScore,
        createdAt: DateTime.now().toUtc(),
        retryCount: 0,
        state: EvidenceSyncState.retryPending,
        lastError: error.message,
      );
      await _queue.enqueue(item);
      return EvidenceRecord.localPending(
        operationId: operationId,
        testId: session.id,
        operatorId: session.operatorId,
        capturedAt: capturedAt,
        latitude: latitude,
        longitude: longitude,
        gpsAccuracy: gpsAccuracy,
        imageSha256: item.imageSha256,
        imageQualityScore: imageQualityScore,
        blurScore: sharpnessScore,
        brightnessScore: brightnessScore,
      );
    }
  }

  Future<SyncResult> syncPending({int maxAttempts = 3}) async {
    final items = await _queue.list();
    var uploaded = 0;
    var failed = 0;
    for (final item in items) {
      if (item.retryCount >= maxAttempts) {
        continue;
      }
      await _queue.replace(item.copyWith(state: EvidenceSyncState.uploading));
      final hash = _hashService.sha256Bytes(item.imageBytes);
      if (hash != item.imageSha256) {
        await _queue.replace(item.copyWith(
          state: EvidenceSyncState.syncFailed,
          lastError: 'Local image hash changed; upload was blocked.',
        ));
        failed++;
        continue;
      }
      try {
        await _remote.createEvidenceRecord(
          session: TestSession.fromMap(item.sessionData),
          imageBytes: item.imageBytes,
          capturedAt: item.capturedAt,
          latitude: item.latitude,
          longitude: item.longitude,
          gpsAccuracy: item.gpsAccuracy,
          imageQualityScore: item.imageQualityScore,
          sharpnessScore: item.blurScore,
          brightnessScore: item.brightnessScore,
          clientOperationId: item.operationId,
        );
        await _queue.remove(item.operationId);
        uploaded++;
      } on EvidenceServiceException catch (error) {
        final nextRetry = item.retryCount + 1;
        await _queue.replace(item.copyWith(
          retryCount: nextRetry,
          state: error.recoverable && nextRetry < maxAttempts
              ? EvidenceSyncState.retryPending
              : EvidenceSyncState.syncFailed,
          lastError: error.message,
        ));
        failed++;
      }
    }
    return SyncResult(uploaded: uploaded, failed: failed);
  }

  Future<void> retryFailed() async {
    for (final item in await _queue.list()) {
      if (item.state == EvidenceSyncState.syncFailed) {
        await _queue.replace(item.copyWith(
          retryCount: 0,
          state: EvidenceSyncState.retryPending,
          lastError: null,
        ));
      }
    }
  }

  static String _newOperationId() {
    final random = Random.secure().nextInt(1 << 32);
    return 'op-${DateTime.now().microsecondsSinceEpoch}-$random';
  }
}

class SyncResult {
  const SyncResult({required this.uploaded, required this.failed});

  final int uploaded;
  final int failed;
}
