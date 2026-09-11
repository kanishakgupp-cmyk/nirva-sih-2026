import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/kit.dart';

abstract interface class KitService {
  Future<Kit?> findKitByCode(String kitCode);
}

class SupabaseKitService implements KitService {
  SupabaseKitService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  @override
  Future<Kit?> findKitByCode(String kitCode) async {
    try {
      final response = await _client
          .from('kits')
          .select()
          .eq('kit_code', kitCode.trim())
          .maybeSingle();
      if (response == null) {
        return null;
      }
      return Kit.fromMap(response);
    } on PostgrestException catch (_) {
      throw const KitServiceException(
        'Kit verification is unavailable. Please try again.',
      );
    } catch (_) {
      throw const KitServiceException(
        'Kit verification is unavailable. Please try again.',
      );
    }
  }
}

class KitServiceException implements Exception {
  const KitServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}
