import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/case_model.dart';

abstract interface class CaseService {
  Future<List<CaseModel>> getMyCases();

  Future<CaseModel?> getCaseById(String caseId);

  Future<void> createCase({
    required String caseNumber,
    required String title,
    String? description,
  });
}

class SupabaseCaseService implements CaseService {
  SupabaseCaseService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  @override
  Future<List<CaseModel>> getMyCases() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw const CaseServiceException('Please sign in to view cases.');
    }

    final response = await _client
        .from('cases')
        .select()
        .eq('created_by', user.id)
        .order('created_at', ascending: false);

    return (response as List)
        .map((row) => CaseModel.fromMap(Map<String, dynamic>.from(row)))
        .toList();
  }

  @override
  Future<CaseModel?> getCaseById(String caseId) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw const CaseServiceException('Please sign in to view this case.');
    }

    final response = await _client
        .from('cases')
        .select()
        .eq('id', caseId)
        .eq('created_by', user.id)
        .maybeSingle();

    if (response == null) {
      return null;
    }

    return CaseModel.fromMap(response);
  }

  @override
  Future<void> createCase({
    required String caseNumber,
    required String title,
    String? description,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw const CaseServiceException(
          'Please sign in before creating a case.');
    }

    try {
      await _client.from('cases').insert({
        'case_number': caseNumber.trim(),
        'title': title.trim(),
        'description':
            description?.trim().isEmpty ?? true ? null : description!.trim(),
        'created_by': user.id,
      });
    } on PostgrestException catch (error) {
      if (error.code == '23505') {
        throw const CaseServiceException('Case number already exists.');
      }
      throw const CaseServiceException(
        'The case could not be saved. Please try again.',
      );
    } catch (_) {
      throw const CaseServiceException(
        'The case could not be saved. Please try again.',
      );
    }
  }
}

class CaseServiceException implements Exception {
  const CaseServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}
