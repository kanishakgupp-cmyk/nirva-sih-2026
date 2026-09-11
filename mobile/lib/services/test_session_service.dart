import 'dart:convert';
import 'dart:math';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/test_session.dart';

abstract interface class TestSessionService {
  Future<TestSession> createTestSession({required String caseId});

  Future<TestSession?> getTestSession(String testId);

  Future<void> attachKitToSession({
    required String testId,
    required String kitId,
  });

  Future<void> updateTestStatus({
    required String testId,
    required String status,
  });
}

class SupabaseTestSessionService implements TestSessionService {
  SupabaseTestSessionService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  @override
  Future<TestSession> createTestSession({required String caseId}) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw const TestSessionServiceException(
        'Please sign in before starting a test.',
      );
    }

    final response = await _client
        .from('test_sessions')
        .insert({
          'test_number': TestSessionValues.generateTestNumber(),
          'case_id': caseId,
          'operator_id': user.id,
          'session_nonce': TestSessionValues.generateSessionNonce(),
          'status': 'CREATED',
        })
        .select()
        .single();

    return TestSession.fromMap(response);
  }

  @override
  Future<TestSession?> getTestSession(String testId) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw const TestSessionServiceException(
        'Please sign in to view this test session.',
      );
    }

    final response = await _client
        .from('test_sessions')
        .select()
        .eq('id', testId)
        .eq('operator_id', user.id)
        .maybeSingle();

    if (response == null) {
      return null;
    }
    return TestSession.fromMap(response);
  }

  @override
  Future<void> attachKitToSession({
    required String testId,
    required String kitId,
  }) async {
    await _updateOwnedSession(testId, {'kit_id': kitId});
  }

  @override
  Future<void> updateTestStatus({
    required String testId,
    required String status,
  }) async {
    const validStatuses = {
      'CREATED',
      'RUNNING',
      'CAPTURED',
      'ANALYZED',
      'FINALIZED',
      'INVALID',
    };
    if (!validStatuses.contains(status)) {
      throw const TestSessionServiceException('Invalid test session status.');
    }
    await _updateOwnedSession(testId, {'status': status});
  }

  Future<void> _updateOwnedSession(
    String testId,
    Map<String, dynamic> values,
  ) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw const TestSessionServiceException(
        'Please sign in before updating this test session.',
      );
    }

    try {
      await _client
          .from('test_sessions')
          .update(values)
          .eq('id', testId)
          .eq('operator_id', user.id);
    } on PostgrestException catch (_) {
      throw const TestSessionServiceException(
        'The test session could not be updated. Please try again.',
      );
    } catch (_) {
      throw const TestSessionServiceException(
        'The test session could not be updated. Please try again.',
      );
    }
  }
}

class TestSessionValues {
  static String generateTestNumber() {
    final bytes = _secureBytes(6);
    final suffix = base64UrlEncode(bytes).replaceAll('=', '').toUpperCase();
    return 'NIRVA-TEST-$suffix';
  }

  static String generateSessionNonce() {
    return base64UrlEncode(_secureBytes(32));
  }

  static List<int> _secureBytes(int length) {
    final random = Random.secure();
    return List<int>.generate(length, (_) => random.nextInt(256));
  }
}

class TestSessionServiceException implements Exception {
  const TestSessionServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}
