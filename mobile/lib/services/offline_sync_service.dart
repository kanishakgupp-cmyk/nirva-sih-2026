import 'dart:math';

import 'package:flutter/foundation.dart';

import '../models/evidence_record.dart';
import '../models/test_session.dart';
import 'evidence_diagnostics.dart';
import 'evidence_hash_service.dart';
import 'evidence_service.dart';
import 'offline_evidence_queue.dart';

class OfflineFirstEvidenceService implements EvidenceService {
  OfflineFirstEvidenceService({
    EvidenceService? remote,
    OfflineEvidenceQueue? queue,
    EvidenceDiagnosticFailureCallback? onDiagnosticFailure,
  })  : _remote = remote ??
            FastApiEvidenceService(onDiagnosticFailure: onDiagnosticFailure),
        _queue = queue ??
            OfflineEvidenceQueue(onDiagnosticFailure: onDiagnosticFailure),
        _onDiagnosticFailure = onDiagnosticFailure;

  final EvidenceService _remote;
  final OfflineEvidenceQueue _queue;
  final EvidenceDiagnosticFailureCallback? _onDiagnosticFailure;
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
    logEvidenceStage(
      'OFFLINE_FIRST',
      'START',
      'bytes=${imageBytes.length} testId=${session.id}',
    );
    late final String operationId;
    try {
      operationId = clientOperationId ?? _newOperationId();
      logEvidenceStage(
        'OPERATION_ID',
        'SUCCESS',
        clientOperationId == null ? 'generated' : 'provided',
      );
    } catch (error, stackTrace) {
      reportEvidenceFailure(
        'OPERATION_ID',
        error,
        stackTrace,
        onDiagnosticFailure: _onDiagnosticFailure,
      );
      rethrow;
    }

    try {
      logEvidenceStage('ONLINE_UPLOAD_SELECTED', 'SUCCESS');
      final record = await _remote.createEvidenceRecord(
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
      logEvidenceStage(
        'OFFLINE_FIRST',
        'SUCCESS',
        'online record id=${record.id} status=${record.evidenceStatus}',
      );
      return record;
    } on EvidenceServiceException catch (error, stackTrace) {
      reportEvidenceFailure(
        'ONLINE_UPLOAD',
        error,
        stackTrace,
        onDiagnosticFailure: _onDiagnosticFailure,
      );
      if (!error.recoverable) rethrow;
      logEvidenceStage('QUEUE_FALLBACK_SELECTED', 'SUCCESS');

      late final String imageSha256;
      try {
        imageSha256 = _hashService.sha256Bytes(imageBytes);
        logEvidenceStage('HASH', 'SUCCESS', 'bytes=${imageBytes.length}');
      } catch (error, stackTrace) {
        reportEvidenceFailure(
          'HASH',
          error,
          stackTrace,
          onDiagnosticFailure: _onDiagnosticFailure,
        );
        rethrow;
      }

      late final PendingEvidence item;
      try {
        item = PendingEvidence(
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
          imageSha256: imageSha256,
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
        logEvidenceStage('PENDING_EVIDENCE_OBJECT', 'SUCCESS');
      } catch (error, stackTrace) {
        reportEvidenceFailure(
          'PENDING_EVIDENCE_OBJECT',
          error,
          stackTrace,
          onDiagnosticFailure: _onDiagnosticFailure,
        );
        rethrow;
      }

      try {
        logEvidenceStage('QUEUE_SAVE', 'START');
        await _queue.enqueue(item);
        logEvidenceStage('QUEUE_SAVE', 'SUCCESS');
      } catch (error, stackTrace) {
        reportEvidenceFailure(
          'QUEUE_SAVE',
          error,
          stackTrace,
          onDiagnosticFailure: _onDiagnosticFailure,
        );
        rethrow;
      }

      try {
        final record = EvidenceRecord.localPending(
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
        logEvidenceStage('LOCAL_PENDING_RECORD', 'SUCCESS', 'id=${record.id}');
        return record;
      } catch (error, stackTrace) {
        reportEvidenceFailure(
          'LOCAL_PENDING_RECORD',
          error,
          stackTrace,
          onDiagnosticFailure: _onDiagnosticFailure,
        );
        rethrow;
      }
    } catch (error, stackTrace) {
      reportEvidenceFailure(
        'OFFLINE_FIRST',
        error,
        stackTrace,
        onDiagnosticFailure: _onDiagnosticFailure,
      );
      rethrow;
    }
  }

  Future<SyncResult> syncPending({int maxAttempts = 3}) async {
    final items = await _queue.list();
    debugPrint('[SYNC_QUEUE_LOAD_SUCCESS] count=${items.length}');
    var uploaded = 0;
    var failed = 0;
    for (final item in items) {
      if (item.retryCount >= maxAttempts) {
        continue;
      }
      debugPrint('[SYNC_ITEM_START] operation=${item.operationId}');
      await _queue.replace(item.copyWith(state: EvidenceSyncState.uploading));
      late final String hash;
      try {
        hash = _hashService.sha256Bytes(item.imageBytes);
        debugPrint('[SYNC_IMAGE_HASH_SUCCESS] bytes=${item.imageBytes.length}');
      } catch (error, stackTrace) {
        debugPrint('[SYNC_IMAGE_HASH] ${error.runtimeType}: $error');
        debugPrintStack(stackTrace: stackTrace);
        rethrow;
      }
      if (hash != item.imageSha256) {
        await _queue.replace(item.copyWith(
          state: EvidenceSyncState.syncFailed,
          lastError: 'Local image hash changed; upload was blocked.',
        ));
        failed++;
        continue;
      }
      try {
        debugPrint('[SYNC_ONLINE_UPLOAD] operation=${item.operationId}');
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
        debugPrint('[SYNC_ITEM_SUCCESS] operation=${item.operationId}');
        uploaded++;
      } on EvidenceServiceException catch (error, stackTrace) {
        debugPrint(
          '[SYNC_ONLINE_UPLOAD_FAILURE] ${error.runtimeType}: $error',
        );
        debugPrintStack(stackTrace: stackTrace);
        final nextRetry = item.retryCount + 1;
        await _queue.replace(item.copyWith(
          retryCount: nextRetry,
          state: error.recoverable && nextRetry < maxAttempts
              ? EvidenceSyncState.retryPending
              : EvidenceSyncState.syncFailed,
          lastError: error.message,
        ));
        failed++;
      } catch (error, stackTrace) {
        debugPrint('[SYNC_ITEM_FAILURE] ${error.runtimeType}: $error');
        debugPrintStack(stackTrace: stackTrace);
        rethrow;
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
    final random = Random.secure().nextInt(0x7FFFFFFF);
    return 'op-${DateTime.now().microsecondsSinceEpoch}-$random';
  }
}

class SyncResult {
  const SyncResult({required this.uploaded, required this.failed});

  final int uploaded;
  final int failed;
}
