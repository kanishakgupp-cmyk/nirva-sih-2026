import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:nirva/models/profile.dart';
import 'package:nirva/screens/home_screen.dart';
import 'package:nirva/screens/login_screen.dart';
import 'package:nirva/services/auth_service.dart';

class FakeAuthService implements AuthService {
  @override
  User? get currentUser => null;

  @override
  Session? get currentSession => null;

  @override
  Stream<AuthState> get authStateChanges => const Stream<AuthState>.empty();

  @override
  Future<AuthResponse> signInWithEmailPassword({
    required String email,
    required String password,
  }) {
    throw UnsupportedError('Sign-in is not used in widget rendering tests.');
  }

  @override
  Future<void> signOut() async {}

  @override
  Future<Profile?> getCurrentProfile() async => const Profile(
        id: 'test-user',
        displayName: 'Test Officer',
        role: ProfileRole.officer,
      );
}

void main() {
  testWidgets('login screen renders', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: LoginScreen(authService: FakeAuthService())),
    );

    expect(find.text('NIRVA'), findsOneWidget);
    expect(find.text('Field Evidence & Verification'), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Sign In'), findsOneWidget);
    expect(
      find.text('INDICATIVE ONLY - LABORATORY CONFIRMATION REQUIRED'),
      findsOneWidget,
    );
  });

  testWidgets('empty login fields show validation messages', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: LoginScreen(authService: FakeAuthService())),
    );

    await tester.tap(find.text('Sign In'));
    await tester.pump();

    expect(find.text('Enter your email address.'), findsOneWidget);
    expect(find.text('Enter your password.'), findsOneWidget);
  });

  testWidgets('authenticated shell renders officer actions', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: HomeScreen(authService: FakeAuthService())),
    );
    await tester.pumpAndSettle();

    expect(find.text('NIRVA'), findsOneWidget);
    expect(find.text('Welcome, Test Officer'), findsOneWidget);
    expect(find.text('OFFICER'), findsOneWidget);
    expect(find.text('Cases - Coming in next phase'), findsOneWidget);
    expect(find.text('Start Test - Coming in next phase'), findsOneWidget);
    expect(
      find.text('Evidence History - Coming in next phase'),
      findsOneWidget,
    );
    expect(find.byTooltip('Sign out'), findsOneWidget);
  });

  testWidgets('sign out action can be invoked without credentials',
      (tester) async {
    final authService = FakeAuthService();
    await tester.pumpWidget(
      MaterialApp(home: HomeScreen(authService: authService)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Sign out'));
    await tester.pump();

    expect(find.text('Welcome, Test Officer'), findsOneWidget);
  });
}
