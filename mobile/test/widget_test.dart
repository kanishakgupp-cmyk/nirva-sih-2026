import 'dart:async';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:nirva/models/profile.dart';
import 'package:nirva/models/case_model.dart';
import 'package:nirva/models/evidence_record.dart';
import 'package:nirva/models/kit.dart';
import 'package:nirva/models/test_session.dart';
import 'package:nirva/models/workflow_step.dart';
import 'package:nirva/screens/case_details_screen.dart';
import 'package:nirva/screens/case_list_screen.dart';
import 'package:nirva/screens/create_case_screen.dart';
import 'package:nirva/screens/evidence_capture_screen.dart';
import 'package:nirva/screens/evidence_success_screen.dart';
import 'package:nirva/screens/home_screen.dart';
import 'package:nirva/screens/guided_workflow_screen.dart';
import 'package:nirva/screens/kit_verification_screen.dart';
import 'package:nirva/screens/login_screen.dart';
import 'package:nirva/screens/start_test_screen.dart';
import 'package:nirva/screens/test_session_screen.dart';
import 'package:nirva/services/api_client.dart';
import 'package:nirva/services/auth_service.dart';
import 'package:nirva/services/camera_service.dart';
import 'package:nirva/services/case_service.dart';
import 'package:nirva/services/evidence_service.dart';
import 'package:nirva/services/evidence_hash_service.dart';
import 'package:nirva/services/image_quality_service.dart';
import 'package:nirva/services/kit_service.dart';
import 'package:nirva/services/location_service.dart';
import 'package:nirva/services/test_session_service.dart';
import 'package:nirva/services/workflow_service.dart';
import 'package:nirva/widgets/workflow_timer.dart';

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

class _StubHttpClient extends http.BaseClient {
  _StubHttpClient(this.handler);

  final http.Response Function(http.BaseRequest) handler;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final response = handler(request);
    return http.StreamedResponse(
      Stream.value(response.bodyBytes),
      response.statusCode,
      headers: response.headers,
      request: request,
    );
  }
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

  @override
  Future<void> markWorkflowComplete({required String testId}) async {}

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

class UnavailableCameraService extends CameraService {
  @override
  Future<void> initialize({void Function(String stage)? onStage}) async {
    throw const CameraServiceException('No camera is available.');
  }
}

class UnavailableLocationService extends LocationService {
  const UnavailableLocationService();

  @override
  Future<LocationResult> captureLocation() async {
    return const LocationResult.unavailable(reason: 'Not available in test.');
  }
}

class FakeEvidenceService implements EvidenceService {
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
    return EvidenceRecord.fromMap({
      'id': 'evidence-1',
      'test_id': session.id,
      'operator_id': session.operatorId,
      'captured_at': capturedAt.toIso8601String(),
      'image_sha256': 'demo-hash',
      'image_quality_score': imageQualityScore,
      'created_at': capturedAt.toIso8601String(),
    });
  }
}

class FastWorkflowService extends WorkflowService {
  const FastWorkflowService();

  @override
  List<WorkflowStep> getDemoWorkflow() {
    return const [
      WorkflowStep(
        id: 'fast_step_1',
        title: 'Fast Demo Step 1',
        description: 'Complete the fast demonstration step.',
        durationSeconds: 0,
        requiresTimer: false,
        isRequired: true,
      ),
      WorkflowStep(
        id: 'fast_step_2',
        title: 'Fast Demo Step 2',
        description: 'Complete the final fast demonstration step.',
        durationSeconds: 0,
        requiresTimer: false,
        isRequired: true,
      ),
    ];
  }
}

class TimedWorkflowService extends WorkflowService {
  const TimedWorkflowService();

  @override
  List<WorkflowStep> getDemoWorkflow() {
    return const [
      WorkflowStep(
        id: 'timed_step',
        title: 'Timed Demo Step',
        description: 'Complete the configured timed demonstration step.',
        durationSeconds: 20,
        requiresTimer: true,
        isRequired: true,
      ),
    ];
  }
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

  test('ApiClient trims trailing slashes and normalizes path URLs', () {
    final client = ApiClient(
      baseUrl: 'https://example.com/api/',
      supabaseClient: SupabaseClient('https://example.com', 'anon-key'),
    );

    expect(
        client.buildUri('/cases').toString(), 'https://example.com/api/cases');
    expect(
        client.buildUri('cases').toString(), 'https://example.com/api/cases');
    expect(client.safeEndpointDescription, 'https://example.com/api');
  });

  test('ApiClient preserves HTTP status and safe server detail', () async {
    final client = ApiClient(
      baseUrl: 'https://example.com',
      supabaseClient: SupabaseClient('https://example.com', 'anon-key'),
      accessToken: 'test-token',
      httpClient: _StubHttpClient(
        (_) => http.Response('{"detail":"Token rejected."}', 401),
      ),
    );

    await expectLater(
      client.getList('/api/v1/cases'),
      throwsA(
        isA<ApiClientException>()
            .having((error) => error.statusCode, 'statusCode', 401)
            .having(
              (error) => error.category,
              'category',
              ApiErrorCategory.http401,
            )
            .having((error) => error.message, 'message', 'Token rejected.'),
      ),
    );
  });

  test('ApiClient reserves unreachable message for transport failures',
      () async {
    final client = ApiClient(
      baseUrl: 'https://example.com',
      supabaseClient: SupabaseClient('https://example.com', 'anon-key'),
      accessToken: 'test-token',
      httpClient: _StubHttpClient((_) {
        throw http.ClientException('connection failed');
      }),
    );

    await expectLater(
      client.getList('/api/v1/cases'),
      throwsA(
        isA<ApiClientException>()
            .having(
              (error) => error.message,
              'message',
              'The server could not be reached. Please try again.',
            )
            .having(
              (error) => error.category,
              'category',
              ApiErrorCategory.networkError,
            ),
      ),
    );
  });

  test('ApiClient exposes only safe development request diagnostics', () async {
    final client = ApiClient(
      baseUrl: 'https://example.com:8443/api/',
      supabaseClient: SupabaseClient('https://example.com', 'anon-key'),
      accessToken: 'test-token',
      httpClient: _StubHttpClient((_) {
        throw http.ClientException('Failed to fetch');
      }),
    );

    try {
      await client.getList('/api/v1/cases?token=hidden');
      fail('Expected ApiClientException');
    } on ApiClientException catch (error) {
      expect(error.category, ApiErrorCategory.networkError);
      expect(
        error.diagnostic,
        contains('url=https://example.com:8443/api/api/v1/cases'),
      );
      expect(error.diagnostic, contains('tokenPresent=true'));
      expect(error.diagnostic, contains('exception=ClientException'));
      expect(error.diagnostic, contains('message=Failed to fetch'));
      expect(error.diagnostic, isNot(contains('hidden')));
      expect(error.diagnostic, isNot(contains('test-token')));
    }
  });

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

  test('EvidenceRecord parses analysis lifecycle fields', () {
    final record = EvidenceRecord.fromMap({
      'id': 'evidence-1',
      'test_id': 'test-1',
      'operator_id': 'officer-1',
      'evidence_status': 'ANALYZED',
      'image_sha256': 'a' * 64,
      'analysis_result': 'DEMO_CLASS_A',
      'analysis_confidence': 0.86,
      'analysis_uncertainty': 0.07,
      'analysis_model_version': 'nirva-demo-visual-1',
      'analysis_explanation': {'reference_card': 'Detected'},
      'created_at': '2026-09-12T10:00:00Z',
      'legal_label': 'INDICATIVE ONLY',
    });

    expect(record.evidenceStatus, 'ANALYZED');
    expect(record.analysisResult, 'DEMO_CLASS_A');
    expect(record.analysisConfidence, 0.86);
    expect(record.analysisExplanation?['reference_card'], 'Detected');
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

  test('EvidenceRecord.fromMap parses evidence metadata safely', () {
    final record = EvidenceRecord.fromMap({
      'id': 'evidence-1',
      'test_id': 'session-1',
      'operator_id': 'officer-1',
      'captured_at': '2026-09-11T10:30:00Z',
      'latitude': null,
      'longitude': null,
      'gps_accuracy': null,
      'image_path': 'officer-1/session-1/demo.jpg',
      'image_sha256': 'abc123',
      'image_quality_score': 82.5,
      'legal_label': 'INDICATIVE ONLY - LABORATORY CONFIRMATION REQUIRED',
      'created_at': '2026-09-11T10:30:00Z',
    });

    expect(record.testId, 'session-1');
    expect(record.imagePath, contains('demo.jpg'));
    expect(record.imageSha256, 'abc123');
    expect(record.latitude, isNull);
    expect(record.imageQualityScore, 82.5);
  });

  test('SHA-256 is deterministic and distinguishes bytes', () {
    const service = EvidenceHashService();
    final first = service.sha256Bytes([1, 2, 3]);
    final same = service.sha256Bytes([1, 2, 3]);
    final different = service.sha256Bytes([1, 2, 4]);

    expect(first, same);
    expect(first, isNot(different));
    expect(first, hasLength(64));
  });

  test('image quality rejects unreadable or undersized data', () {
    const service = ImageQualityService();

    expect(
      () => service.analyze(Uint8List.fromList([1, 2, 3])),
      throwsA(isA<ImageQualityException>()),
    );
  });

  test('low-quality valid image requests a retake', () {
    final tinyImage = img.Image(width: 1, height: 1);
    final bytes = Uint8List.fromList(img.encodeJpg(tinyImage));
    final result = const ImageQualityService().analyze(bytes);

    expect(result.requiresRetake, isTrue);
    expect(result.qualityScore, lessThan(70));
  });

  test('location unavailable state carries no fabricated coordinates', () {
    const result = LocationResult.unavailable(reason: 'Permission denied.');

    expect(result.available, isFalse);
    expect(result.latitude, isNull);
    expect(result.longitude, isNull);
    expect(result.accuracy, isNull);
  });

  test('camera selection prefers the back-facing camera', () {
    const front = CameraDescription(
      name: 'front',
      lensDirection: CameraLensDirection.front,
      sensorOrientation: 0,
    );
    const back = CameraDescription(
      name: 'back',
      lensDirection: CameraLensDirection.back,
      sensorOrientation: 0,
    );

    expect(
      CameraService.selectPreferredCamera([front, back]).name,
      'back',
    );
    expect(
      CameraService.selectPreferredCamera([front]).name,
      'front',
    );
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

  test('WorkflowStep parses demo configuration', () {
    final step = WorkflowStep.fromMap({
      'id': 'demo_step_2',
      'title': 'Observation Window',
      'description': 'Wait for the configured observation window.',
      'duration_seconds': 20,
      'requires_timer': true,
      'is_required': true,
    });

    expect(step.id, 'demo_step_2');
    expect(step.durationSeconds, 20);
    expect(step.requiresTimer, isTrue);
    expect(step.isRequired, isTrue);
  });

  test('demo workflow contains three configured steps', () {
    final workflow = const WorkflowService().getDemoWorkflow();

    expect(workflow, hasLength(3));
    expect(workflow.first.id, 'demo_step_1');
    expect(workflow.first.requiresTimer, isFalse);
    expect(workflow[1].requiresTimer, isTrue);
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
          testSessionService: FakeTestSessionService(),
        ),
      ),
    );

    expect(find.text('Guided Test Workflow'), findsOneWidget);
    expect(find.textContaining('NIRVA-TEST-ABC123'), findsOneWidget);
    expect(find.textContaining('CASE-001'), findsOneWidget);
    expect(find.textContaining('NIRVA-DEMO-001'), findsOneWidget);
    expect(find.textContaining('RUNNING'), findsOneWidget);
  });

  testWidgets('workflow timer counts down and never goes below zero',
      (tester) async {
    var completed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: WorkflowTimer(
          duration: Duration.zero,
          onCompleted: () => completed = true,
        ),
      ),
    );

    expect(find.text('00:00'), findsOneWidget);
    await tester.tap(find.text('Start Timer'));
    await tester.pump();

    expect(completed, isTrue);
    expect(find.text('Step complete'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('Step complete'), findsOneWidget);
  });

  testWidgets('guided workflow advances and completes with fast demo steps',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: GuidedWorkflowScreen(
          session: FakeTestSessionService._session,
          caseItem: sampleCase,
          kit: Kit(
            id: 'kit-1',
            kitCode: 'NIRVA-DEMO-001',
            batchNumber: 'DEMO-BATCH-001',
            expiryDate: DateTime(2030, 12, 31),
            status: 'ACTIVE',
            createdAt: DateTime(2026, 9, 11),
          ),
          testSessionService: FakeTestSessionService(),
          workflowService: const FastWorkflowService(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Step 1 of 2'), findsOneWidget);
    expect(find.text('Fast Demo Step 1'), findsOneWidget);
    await tester.tap(find.text('Complete Step'));
    await tester.pumpAndSettle();

    expect(find.text('Step 2 of 2'), findsOneWidget);
    expect(find.text('Fast Demo Step 2'), findsOneWidget);
    await tester.tap(find.text('Complete Step'));
    await tester.pumpAndSettle();

    expect(find.text('WORKFLOW COMPLETE'), findsOneWidget);
    expect(find.textContaining('NIRVA-TEST-ABC123'), findsOneWidget);
    expect(find.textContaining('READY FOR EVIDENCE CAPTURE'), findsOneWidget);
  });

  testWidgets('evidence capture screen shows demo-only fallback',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: EvidenceCaptureScreen(
          session: FakeTestSessionService._session,
          caseItem: sampleCase,
          kit: Kit(
            id: 'kit-1',
            kitCode: 'NIRVA-DEMO-001',
            batchNumber: 'DEMO-BATCH-001',
            expiryDate: DateTime(2030, 12, 31),
            status: 'ACTIVE',
            createdAt: DateTime(2026, 9, 11),
          ),
          cameraService: UnavailableCameraService(),
          evidenceService: FakeEvidenceService(),
          locationService: const UnavailableLocationService(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Evidence Capture'), findsOneWidget);
    expect(find.text('DEMO ONLY'), findsOneWidget);
    expect(find.text('Use Demo Image'), findsOneWidget);
    expect(find.text('DEMONSTRATION EVIDENCE CAPTURE'), findsOneWidget);
  });

  testWidgets('evidence success screen displays metadata', (tester) async {
    final record = EvidenceRecord.fromMap({
      'id': 'evidence-1',
      'test_id': 'session-1',
      'operator_id': 'officer-1',
      'captured_at': '2026-09-11T10:30:00Z',
      'image_sha256': '1234567890abcdef1234567890abcdef',
      'image_quality_score': 88.0,
      'created_at': '2026-09-11T10:30:00Z',
    });
    await tester.pumpWidget(
      MaterialApp(
        home: EvidenceSuccessScreen(
          record: record,
          session: FakeTestSessionService._session,
          caseItem: sampleCase,
        ),
      ),
    );

    expect(find.text('EVIDENCE SAVED'), findsOneWidget);
    expect(find.textContaining('NIRVA-TEST-ABC123'), findsOneWidget);
    expect(find.textContaining('88.0'), findsOneWidget);
    expect(find.textContaining('12345678...90abcdef'), findsOneWidget);
    expect(find.text('Evidence capture complete.'), findsOneWidget);
  });

  testWidgets('required timed step cannot be completed before timer',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: GuidedWorkflowScreen(
          session: FakeTestSessionService._session,
          caseItem: sampleCase,
          kit: Kit(
            id: 'kit-1',
            kitCode: 'NIRVA-DEMO-001',
            batchNumber: 'DEMO-BATCH-001',
            expiryDate: DateTime(2030, 12, 31),
            status: 'ACTIVE',
            createdAt: DateTime(2026, 9, 11),
          ),
          testSessionService: FakeTestSessionService(),
          workflowService: const TimedWorkflowService(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final completeButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Complete Step (timer required)'),
    );
    expect(completeButton.onPressed, isNull);
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
