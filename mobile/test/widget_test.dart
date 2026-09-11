import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:nirva/models/profile.dart';
import 'package:nirva/models/case_model.dart';
import 'package:nirva/screens/case_details_screen.dart';
import 'package:nirva/screens/case_list_screen.dart';
import 'package:nirva/screens/create_case_screen.dart';
import 'package:nirva/screens/home_screen.dart';
import 'package:nirva/screens/login_screen.dart';
import 'package:nirva/services/auth_service.dart';
import 'package:nirva/services/case_service.dart';

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

class FakeCaseService implements CaseService {
  FakeCaseService({this.cases = const []});

  final List<CaseModel> cases;

  @override
  Future<List<CaseModel>> getMyCases() async => cases;

  @override
  Future<CaseModel?> getCaseById(String caseId) async {
    for (final caseItem in cases) {
      if (caseItem.id == caseId) {
        return caseItem;
      }
    }
    return null;
  }

  @override
  Future<void> createCase({
    required String caseNumber,
    required String title,
    String? description,
  }) async {}
}

void main() {
  final sampleCase = CaseModel(
    id: 'case-1',
    caseNumber: 'CASE-001',
    title: 'Sample case',
    description: 'A safe test description.',
    createdBy: 'officer-1',
    createdAt: DateTime.utc(2026, 9, 11, 10, 30),
  );

  test('CaseModel.fromMap parses a valid case', () {
    final caseItem = CaseModel.fromMap({
      'id': 'case-1',
      'case_number': 'CASE-001',
      'title': 'Sample case',
      'description': 'A safe test description.',
      'created_by': 'officer-1',
      'created_at': '2026-09-11T10:30:00Z',
    });

    expect(caseItem.id, 'case-1');
    expect(caseItem.caseNumber, 'CASE-001');
    expect(caseItem.title, 'Sample case');
    expect(caseItem.description, 'A safe test description.');
    expect(caseItem.createdBy, 'officer-1');
    expect(caseItem.createdAt, DateTime.utc(2026, 9, 11, 10, 30).toLocal());
  });

  test('CaseModel handles a null description', () {
    final caseItem = CaseModel.fromMap({
      'id': 'case-2',
      'case_number': 'CASE-002',
      'title': 'No description',
      'description': null,
      'created_by': 'officer-1',
      'created_at': 'not-a-date',
    });

    expect(caseItem.description, isNull);
    expect(caseItem.createdAt, DateTime.fromMillisecondsSinceEpoch(0));
  });

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
      MaterialApp(
        home: HomeScreen(
          authService: FakeAuthService(),
          caseService: FakeCaseService(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('NIRVA'), findsOneWidget);
    expect(find.text('Welcome, Test Officer'), findsOneWidget);
    expect(find.text('OFFICER'), findsOneWidget);
    expect(find.text('Cases'), findsOneWidget);
    expect(find.text('Start Test - Coming in next phase'), findsOneWidget);
    expect(
      find.text('Evidence History - Coming in next phase'),
      findsOneWidget,
    );
    expect(find.byTooltip('Sign out'), findsOneWidget);
  });

  testWidgets('create case screen validates required fields', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: CreateCaseScreen(caseService: FakeCaseService())),
    );

    await tester.tap(find.text('Create Case'));
    await tester.pump();

    expect(find.text('Case number is required.'), findsOneWidget);
    expect(find.text('Case title is required.'), findsOneWidget);
  });

  testWidgets('case list renders empty state', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: CaseListScreen(caseService: FakeCaseService())),
    );
    await tester.pumpAndSettle();

    expect(find.text('No cases yet'), findsOneWidget);
    expect(find.text('Create New Case'), findsOneWidget);
  });

  testWidgets('case details displays case information', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: CaseDetailsScreen(caseItem: sampleCase)),
    );

    expect(find.text('CASE-001'), findsOneWidget);
    expect(find.text('Sample case'), findsOneWidget);
    expect(find.text('A safe test description.'), findsOneWidget);
    expect(find.text('officer-1'), findsOneWidget);
    expect(find.text('Start Test'), findsOneWidget);
  });

  testWidgets('sign out action can be invoked without credentials',
      (tester) async {
    final authService = FakeAuthService();
    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(
          authService: authService,
          caseService: FakeCaseService(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Sign out'));
    await tester.pump();

    expect(find.text('Welcome, Test Officer'), findsOneWidget);
  });
}
