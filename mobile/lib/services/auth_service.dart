import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/profile.dart';

abstract interface class AuthService {
  User? get currentUser;

  Session? get currentSession;

  Stream<AuthState> get authStateChanges;

  Future<AuthResponse> signInWithEmailPassword({
    required String email,
    required String password,
  });

  Future<void> signOut();

  Future<Profile?> getCurrentProfile();
}

class SupabaseAuthService implements AuthService {
  SupabaseAuthService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  @override
  User? get currentUser => _client.auth.currentUser;

  @override
  Session? get currentSession => _client.auth.currentSession;

  @override
  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  @override
  Future<AuthResponse> signInWithEmailPassword({
    required String email,
    required String password,
  }) {
    return _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  @override
  Future<void> signOut() => _client.auth.signOut();

  @override
  Future<Profile?> getCurrentProfile() async {
    final user = currentUser;
    if (user == null) {
      return null;
    }

    final response = await _client
        .from('profiles')
        .select('id, display_name, role')
        .eq('id', user.id)
        .maybeSingle();

    if (response == null) {
      return null;
    }

    return Profile.fromMap(response);
  }
}
