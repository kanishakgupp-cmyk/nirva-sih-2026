import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/evidence_record.dart';
import '../models/test_session.dart';
import 'api_client.dart';
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
    String? clientOperationId,
  });
}

class FastApiEvidenceService implements EvidenceService {
  FastApiEvidenceService({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

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
    try {
      final response = await _apiClient.postMultipart(
        '/api/v1/evidence',
        fields: {
          'test_id': session.id,
          if (clientOperationId != null)
            'client_operation_id': clientOperationId,
          'captured_at': capturedAt.toUtc().toIso8601String(),
          'image_quality_score': imageQualityScore.toString(),
          'blur_score': sharpnessScore.toString(),
          'brightness_score': brightnessScore.toString(),
          if (latitude != null) 'latitude': latitude.toString(),
          if (longitude != null) 'longitude': longitude.toString(),
          if (gpsAccuracy != null) 'gps_accuracy': gpsAccuracy.toString(),
        },
        bytes: imageBytes,
        filename: 'evidence.jpg',
        contentType: 'image/jpeg',
      );
      return EvidenceRecord.fromMap(response);
    } on ApiClientException catch (error) {
      final recoverable = error.category == ApiErrorCategory.networkError ||
          error.statusCode == 408 ||
          error.statusCode == 429 ||
          (error.statusCode != null && error.statusCode! >= 500);
      throw EvidenceServiceException(
        error.userMessage,
        recoverable: recoverable,
      );
    } catch (_) {
      throw const EvidenceServiceException(
        'Evidence could not be saved. Please try again.',
      );
    }
  }
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
    String? clientOperationId,
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
            'evidence_status': 'CAPTURED',
            'legal_label': 'INDICATIVE ONLY - LABORATORY CONFIRMATION REQUIRED',
          })
          .select()
          .single();

      await _client.from('audit_events').insert({
        'test_id': session.id,
        'operator_id': user.id,
        'event_type': 'IMAGE_CAPTURED',
        'event_data': {
          'image_sha256': hash,
          'gps_available': latitude != null && longitude != null,
        },
      });
      await _client.from('audit_events').insert({
        'test_id': session.id,
        'operator_id': user.id,
        'event_type': 'GPS_CAPTURED',
        'event_data': {'available': latitude != null && longitude != null},
      });

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
  const EvidenceServiceException(this.message, {this.recoverable = false});

  final String message;
  final bool recoverable;

  @override
  String toString() => message;
}
