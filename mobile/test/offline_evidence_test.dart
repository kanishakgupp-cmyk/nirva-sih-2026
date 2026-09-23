import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nirva/models/evidence_record.dart';
import 'package:nirva/models/test_session.dart';
import 'package:nirva/services/evidence_service.dart';
import 'package:nirva/services/offline_evidence_queue.dart';
import 'package:nirva/services/offline_sync_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('queues recoverable upload failures and syncs once connectivity returns', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final queue = OfflineEvidenceQueue(preferences: preferences);
    final remote = FakeRemoteEvidenceService(failuresBeforeSuccess: 1);
    final service = OfflineFirstEvidenceService(remote: remote, queue: queue);
    final session = buildSession();

    final local = await service.createEvidenceRecord(
      session: session,
      imageBytes: Uint8List.fromList([1, 2, 3]),
      capturedAt: DateTime.utc(2026, 9, 23),
      latitude: null,
      longitude: null,
      gpsAccuracy: null,
      imageQualityScore: 90,
      sharpnessScore: 80,
      brightnessScore: 75,
    );

    expect(local.evidenceStatus, 'LOCAL_PENDING_UPLOAD');
    expect(await queue.pendingCount(), 1);

    final result = await service.syncPending();

    expect(result.uploaded, 1);
    expect(result.failed, 0);
    expect(await queue.pendingCount(), 0);
    expect(remote.operationIds, hasLength(2));
    expect(remote.operationIds.first, remote.operationIds.last);
  });

  test('does not upload a queued item when its image hash changes', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final queue = OfflineEvidenceQueue(preferences: preferences);
    final remote = FakeRemoteEvidenceService();
    final item = PendingEvidence(
      operationId: 'op-tampered',
      testId: 'test-1',
      operatorId: 'operator-1',
      sessionData: buildSession().toMap(),
      imageBytes: Uint8List.fromList([9, 9, 9]),
      imageSha256: 'not-the-image-hash',
      capturedAt: DateTime.utc(2026, 9, 23),
      latitude: null,
      longitude: null,
      gpsAccuracy: null,
      imageQualityScore: 90,
      blurScore: 80,
      brightnessScore: 75,
      createdAt: DateTime.utc(2026, 9, 23),
      retryCount: 0,
      state: EvidenceSyncState.retryPending,
    );
    await queue.enqueue(item);

    final result = await OfflineFirstEvidenceService(
      remote: remote,
      queue: queue,
    ).syncPending();

    expect(result.failed, 1);
    expect(remote.operationIds, isEmpty);
    expect((await queue.list()).single.state, EvidenceSyncState.syncFailed);
  });
}

TestSession buildSession() {
  return TestSession(
    id: 'test-1',
    testNumber: 'NIRVA-TEST-1',
    caseId: 'case-1',
    kitId: 'kit-1',
    operatorId: 'operator-1',
    sessionNonce: 'nonce-1',
    reagentProtocol: null,
    startedAt: DateTime.utc(2026, 9, 23),
    capturedAt: null,
    reactionTimeSeconds: null,
    latitude: null,
    longitude: null,
    gpsAccuracy: null,
    status: 'RUNNING',
    createdAt: DateTime.utc(2026, 9, 23),
  );
}

class FakeRemoteEvidenceService implements EvidenceService {
  FakeRemoteEvidenceService({this.failuresBeforeSuccess = 0});

  int failuresBeforeSuccess;
  final operationIds = <String>[];

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
    operationIds.add(clientOperationId!);
    if (failuresBeforeSuccess > 0) {
      failuresBeforeSuccess--;
      throw const EvidenceServiceException(
        'The server could not be reached.',
        recoverable: true,
      );
    }
    return EvidenceRecord.fromMap({
      'id': 'server-evidence-1',
      'test_id': session.id,
      'operator_id': session.operatorId,
      'evidence_status': 'CAPTURED',
      'image_sha256': 'server-hash',
      'captured_at': capturedAt.toIso8601String(),
      'created_at': capturedAt.toIso8601String(),
    });
  }
}

extension on TestSession {
  Map<String, dynamic> toMap() => {
        'id': id,
        'test_number': testNumber,
        'case_id': caseId,
        'kit_id': kitId,
        'operator_id': operatorId,
        'session_nonce': sessionNonce,
        'reagent_protocol': reagentProtocol,
        'started_at': startedAt?.toIso8601String(),
        'captured_at': capturedAt?.toIso8601String(),
        'reaction_time_seconds': reactionTimeSeconds,
        'latitude': latitude,
        'longitude': longitude,
        'gps_accuracy': gpsAccuracy,
        'status': status,
        'created_at': createdAt.toIso8601String(),
      };
}
