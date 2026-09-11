import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:nirva/models/profile.dart';
import 'package:nirva/models/case_model.dart';
import 'package:nirva/models/kit.dart';
import 'package:nirva/models/test_session.dart';
import 'package:nirva/screens/case_details_screen.dart';
import 'package:nirva/screens/case_list_screen.dart';
import 'package:nirva/screens/create_case_screen.dart';
import 'package:nirva/screens/home_screen.dart';
import 'package:nirva/screens/kit_verification_screen.dart';
import 'package:nirva/screens/login_screen.dart';
import 'package:nirva/screens/start_test_screen.dart';
import 'package:nirva/screens/test_session_screen.dart';
import 'package:nirva/services/auth_service.dart';
import 'package:nirva/services/case_service.dart';
import 'package:nirva/services/kit_service.dart';
import 'package:nirva/services/test_session_service.dart';

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

class FakeTestSessionService implements TestSessionService {
  FakeTestSessionService({TestSession? session})
      : session = session ?? _session;

  TestSession session;

  @override
  Future<TestSession> createTestSession({required String caseId}) async {
    return session;
  }

  @override
  Future<TestSession?> getTestSession(String testId) async => session;

  @override
  Future<void> attachKitToSession({
    required String testId,
    required String kitId,
  }) async {}

  @override
  Future<void> updateTestStatus({
    required String testId,
    required String status,
  }) async {}

  static final _session = TestSession(
    id: 'test-session-1',
    testNumber: 'NIRVA-TEST-ABC123',
    caseId: 'case-1',
    kitId: null,
    operatorId: 'officer-1',
    sessionNonce: 'test-only-nonce',
    reagentProtocol: null,
    startedAt: null,
    capturedAt: null,
    reactionTimeSeconds: null,
    latitude: null,
    longitude: null,
    gpsAccuracy: null,
    status: 'CREATED',
    createdAt: DateTime.utc(2026, 9, 11, 10, 30),
  );
}

class FakeKitService implements KitService {
  FakeKitService({this.kit});

  final Kit? kit;

  @override
  Future<Kit?> findKitByCode(String kitCode) async => kit;
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

  test('TestSession.fromMap parses nullable fields safely', () {
    final session = TestSession.fromMap({
      'id': 'session-1',
      'test_number': 'NIRVA-TEST-ABC123',
      'case_id': 'case-1',
      'kit_id': null,
      'operator_id': 'officer-1',
      'session_nonce': 'nonce',
      'reagent_protocol': null,
      'started_at': null,
      'captured_at': null,
      'reaction_time_seconds': null,
      'latitude': null,
      'longitude': null,
      'gps_accuracy': null,
      'status': 'CREATED',
      'created_at': '2026-09-11T10:30:00Z',
    });

    expect(session.testNumber, 'NIRVA-TEST-ABC123');
    expect(session.kitId, isNull);
    expect(session.status, 'CREATED');
    expect(session.createdAt, DateTime.utc(2026, 9, 11, 10, 30).toLocal());
  });

  test('Kit.fromMap parses nullable fields safely', () {
    final kit = Kit.fromMap({
      'id': 'kit-1',
      'kit_code': 'NIRVA-DEMO-001',
      'batch_number': null,
      'expiry_date': null,
      'status': 'ACTIVE',
      'created_at': null,
    });

    expect(kit.kitCode, 'NIRVA-DEMO-001');
    expect(kit.batchNumber, isNull);
    expect(kit.expiryDate, isNull);
    expect(kit.status, 'ACTIVE');
  });

  test('test number and nonce generators use non-empty values', () {
    final testNumberA = TestSessionValues.generateTestNumber();
    final testNumberB = TestSessionValues.generateTestNumber();
    final nonceA = TestSessionValues.generateSessionNonce();
    final nonceB = TestSessionValues.generateSessionNonce();

    expect(testNumberA, startsWith('NIRVA-TEST-'));
    expect(testNumberA, isNotEmpty);
    expect(testNumberB, isNotEmpty);
    expect(testNumberA, isNot(testNumberB));
    expect(nonceA, isNotEmpty);
    expect(nonceB, isNotEmpty);
    expect(nonceA, isNot(nonceB));
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
      MaterialApp(
        home: CaseDetailsScreen(
          caseItem: sampleCase,
          testSessionService: FakeTestSessionService(),
        ),
      ),
    );

    expect(find.text('CASE-001'), findsOneWidget);
    expect(find.text('Sample case'), findsOneWidget);
    expect(find.text('A safe test description.'), findsOneWidget);
    expect(find.text('officer-1'), findsOneWidget);
    expect(find.text('Start Test'), findsOneWidget);
  });

  testWidgets('start test screen displays case information', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: StartTestScreen(
          caseItem: sampleCase,
          testSessionService: FakeTestSessionService(),
        ),
      ),
    );

    expect(find.text('Start Test'), findsNWidgets(2));
    expect(find.text('CASE-001'), findsOneWidget);
    expect(find.text('Sample case'), findsOneWidget);
    expect(find.text('Create Test Session'), findsOneWidget);
  });

  testWidgets('kit verification screen displays demo fallback', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: KitVerificationScreen(
          session: FakeTestSessionService._session,
          caseItem: sampleCase,
          kitService: FakeKitService(),
          testSessionService: FakeTestSessionService(),
        ),
      ),
    );

    expect(find.text('Verify Kit'), findsOneWidget);
    expect(find.text('Scan the kit QR code'), findsOneWidget);
    expect(find.text('Demo kit code'), findsOneWidget);
    expect(find.text('Verify Kit Code'), findsOneWidget);
  });

  testWidgets('empty kit code shows validation message', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: KitVerificationScreen(
          session: FakeTestSessionService._session,
          caseItem: sampleCase,
          kitService: FakeKitService(),
          testSessionService: FakeTestSessionService(),
        ),
      ),
    );

    await tester.tap(find.text('Verify Kit Code'));
    await tester.pump();

    expect(find.text('Enter a demo kit code.'), findsOneWidget);
  });

  testWidgets('unregistered kit code shows failure state', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: KitVerificationScreen(
          session: FakeTestSessionService._session,
          caseItem: sampleCase,
          kitService: FakeKitService(),
          testSessionService: FakeTestSessionService(),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), 'UNKNOWN-KIT');
    await tester.tap(find.text('Verify Kit Code'));
    await tester.pumpAndSettle();

    expect(find.text('Kit verification failed'), findsOneWidget);
    expect(find.text('Kit not registered.'), findsOneWidget);
    expect(find.text('Scan Again'), findsOneWidget);
  });

  testWidgets('test session screen displays session information',
      (tester) async {
    final kit = Kit(
      id: 'kit-1',
      kitCode: 'NIRVA-DEMO-001',
      batchNumber: 'DEMO-BATCH-001',
      expiryDate: DateTime(2030, 12, 31),
      status: 'ACTIVE',
      createdAt: DateTime(2026, 9, 11),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: TestSessionScreen(
          session: FakeTestSessionService._session,
          caseItem: sampleCase,
          kit: kit,
        ),
      ),
    );

    expect(find.text('Test Session'), findsNWidgets(2));
    expect(find.text('NIRVA-TEST-ABC123'), findsOneWidget);
    expect(find.text('CASE-001'), findsOneWidget);
    expect(find.text('NIRVA-DEMO-001'), findsOneWidget);
    expect(find.text('RUNNING'), findsOneWidget);
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
