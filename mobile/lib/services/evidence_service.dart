import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/evidence_record.dart';
import '../models/test_session.dart';
import 'evidence_hash_service.dart';

abstract interface class EvidenceService {
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
  });
}

class SupabaseEvidenceService implements EvidenceService {
  SupabaseEvidenceService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;
  static const _bucket = 'evidence';
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
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw const EvidenceServiceException(
          'Please sign in before saving evidence.');
    }
    if (session.operatorId != user.id) {
      throw const EvidenceServiceException(
          'This test session is not owned by you.');
    }

    final hash = _hashService.sha256Bytes(imageBytes);
    final fileName = '${DateTime.now().microsecondsSinceEpoch}.jpg';
    final imagePath = '${user.id}/${session.id}/$fileName';

    try {
      await _client.storage.from(_bucket).uploadBinary(
            imagePath,
            imageBytes,
            fileOptions: const FileOptions(
              contentType: 'image/jpeg',
              upsert: false,
            ),
          );

      final response = await _client
          .from('evidence_records')
          .insert({
            'test_id': session.id,
            'operator_id': user.id,
            'captured_at': capturedAt.toUtc().toIso8601String(),
            'latitude': latitude,
            'longitude': longitude,
            'gps_accuracy': gpsAccuracy,
            'image_path': imagePath,
            'image_sha256': hash,
            'image_quality_score': imageQualityScore,
            'blur_score': sharpnessScore,
            'brightness_score': brightnessScore,
            'legal_label': 'INDICATIVE ONLY - LABORATORY CONFIRMATION REQUIRED',
          })
          .select()
          .single();

      return EvidenceRecord.fromMap(response);
    } on PostgrestException catch (_) {
      throw const EvidenceServiceException(
        'The evidence record could not be saved. Please try again.',
      );
    } on StorageException catch (_) {
      throw const EvidenceServiceException(
        'The evidence image could not be uploaded. Please try again.',
      );
    } catch (_) {
      throw const EvidenceServiceException(
        'Evidence could not be saved. Please try again.',
      );
    }
  }
}

class EvidenceServiceException implements Exception {
  const EvidenceServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}
