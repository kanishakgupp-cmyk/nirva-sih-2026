import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:nirva/main.dart';
import 'package:nirva/models/profile.dart';
import 'package:nirva/models/supervisor_models.dart';
import 'package:nirva/screens/home_screen.dart';
import 'package:nirva/screens/login_screen.dart';
import 'package:nirva/screens/supervisor_dashboard_screen.dart';
import 'package:nirva/screens/supervisor_evidence_screen.dart';
import 'package:nirva/services/api_client.dart';
import 'package:nirva/services/auth_service.dart';
import 'package:nirva/services/supervisor_service.dart';

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

class FakeSupervisorAuthService implements AuthService {
  FakeSupervisorAuthService({
    this.session,
    this.profile,
    this.profileDelay,
  });

  Session? session;
  Profile? profile;
  Duration? profileDelay;
  bool signedOut = false;

  @override
  User? get currentUser => session?.user;

  @override
  Session? get currentSession => session;

  @override
  Stream<AuthState> get authStateChanges => const Stream<AuthState>.empty();

  @override
  Future<AuthResponse> signInWithEmailPassword({
    required String email,
    required String password,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<void> signOut() async {
    signedOut = true;
    session = null;
  }

  @override
  Future<Profile?> getCurrentProfile() async {
    if (profileDelay != null) {
      await Future<void>.delayed(profileDelay!);
    }
    return profile;
  }
}

class MockSupervisorService implements SupervisorService {
  MockSupervisorService({
    this.overview = _defaultOverview,
    List<SupervisorEvidenceSummary>? evidenceList,
    this.detail,
    this.throwOverviewError = false,
    this.throwEvidenceError = false,
    this.throwDetailError = false,
  }) : evidenceList = evidenceList ?? [];

  static const _defaultOverview = SupervisorOverview(
    totalCases: 8,
    totalTestSessions: 14,
    totalEvidenceRecords: 12,
    pendingReview: 4,
    analyzedEvidence: 9,
    finalizedEvidence: 5,
    flaggedEvidence: 2,
    returnedEvidence: 1,
  );

  SupervisorOverview overview;
  List<SupervisorEvidenceSummary> evidenceList;
  SupervisorEvidenceDetail? detail;

  bool throwOverviewError;
  bool throwEvidenceError;
  bool throwDetailError;

  String? lastFilterStatus;
  String? lastSearchQuery;
  String? lastReviewedId;
  String? lastAction;
  String? lastReason;

  @override
  Future<SupervisorOverview> getOverview() async {
    if (throwOverviewError) throw Exception('Overview failure');
    return overview;
  }

  @override
  Future<List<SupervisorEvidenceSummary>> getEvidence({
    String? status,
    String? search,
  }) async {
    if (throwEvidenceError) throw Exception('Evidence queue failure');
    lastFilterStatus = status ?? 'ALL';
    lastSearchQuery = search ?? '';
    return evidenceList;
  }

  @override
  Future<SupervisorEvidenceDetail> getEvidenceDetail(String evidenceId) async {
    if (throwDetailError) throw Exception('Detail failure');
    return detail ??
        SupervisorEvidenceDetail(
          id: evidenceId,
          testId: 'test-session-uuid-1',
          testNumber: 'NIRVA-TEST-101',
          caseNumber: 'CASE-2026-001',
          operator: 'Officer Demo',
          capturedAt: DateTime.utc(2026, 9, 12, 10, 30),
          evidenceStatus: 'ANALYZED',
          reviewStatus: 'PENDING',
          reviewReason: 'Awaiting primary inspection',
          analysisResult: 'DEMO_CLASS_A',
          confidence: 0.92,
          integrityStatus: 'VALID',
          finalized: false,
          operatorId: 'officer-uuid-1',
          latitude: 28.6139,
          longitude: 77.2090,
          gpsAccuracy: 4.5,
          imageQualityScore: 88.0,
          blurScore: 10.5,
          brightnessScore: 72.0,
          imageSha256: 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
          imageUrl: null,
          analysisUncertainty: 0.08,
          modelVersion: 'nirva-demo-visual-1',
          legalLabel: 'INDICATIVE ONLY - LABORATORY CONFIRMATION REQUIRED',
          reviewedBy: 'Supervisor Singh',
          reviewedAt: DateTime.utc(2026, 9, 12, 11, 0),
          auditHistory: [
            {
              'event_type': 'EVIDENCE_CAPTURED',
              'created_at': '2026-09-12T10:30:00Z',
              'event_data': {'action': 'CAPTURE'},
            },
            {
              'event_type': 'SUPERVISOR_REVIEW',
              'created_at': '2026-09-12T11:00:00Z',
              'event_data': {'action': 'FLAG', 'reason': 'Image glare on reagent strip'},
            },
          ],
        );
  }

  @override
  Future<SupervisorEvidenceDetail> review(
    String evidenceId,
    String action, {
    String? reason,
  }) async {
    lastReviewedId = evidenceId;
    lastAction = action;
    lastReason = reason;

    final current = await getEvidenceDetail(evidenceId);
    final updated = SupervisorEvidenceDetail(
      id: current.id,
      testId: current.testId,
      testNumber: current.testNumber,
      caseNumber: current.caseNumber,
      operator: current.operator,
      capturedAt: current.capturedAt,
      evidenceStatus: current.evidenceStatus,
      reviewStatus: action == 'APPROVE' ? 'APPROVED' : action,
      reviewReason: reason,
      analysisResult: current.analysisResult,
      confidence: current.confidence,
      integrityStatus: current.integrityStatus,
      finalized: action == 'APPROVE',
      operatorId: current.operatorId,
      latitude: current.latitude,
      longitude: current.longitude,
      gpsAccuracy: current.gpsAccuracy,
      imageQualityScore: current.imageQualityScore,
      blurScore: current.blurScore,
      brightnessScore: current.brightnessScore,
      imageSha256: current.imageSha256,
      imageUrl: current.imageUrl,
      analysisUncertainty: current.analysisUncertainty,
      modelVersion: current.modelVersion,
      legalLabel: current.legalLabel,
      reviewedBy: 'Current Supervisor',
      reviewedAt: DateTime.utc(2026, 9, 12, 12, 0),
      auditHistory: [
        ...current.auditHistory,
        {
          'event_type': 'SUPERVISOR_REVIEW',
          'created_at': '2026-09-12T12:00:00Z',
          'event_data': {'action': action, if (reason != null) 'reason': reason},
        }
      ],
    );
    detail = updated;
    return updated;
  }
}

void main() {
  group('Supervisor Models Parsing', () {
    test('SupervisorOverview parses all metrics including flagged and returned', () {
      final json = {
        'total_cases': 10,
        'total_test_sessions': 25,
        'total_evidence_records': 20,
        'pending_review': 5,
        'analyzed_evidence': 15,
        'finalized_evidence': 8,
        'flagged_evidence': 3,
        'returned_evidence': 2,
      };

      final overview = SupervisorOverview.fromMap(json);

      expect(overview.totalCases, 10);
      expect(overview.totalTestSessions, 25);
      expect(overview.totalEvidenceRecords, 20);
      expect(overview.pendingReview, 5);
      expect(overview.analyzedEvidence, 15);
      expect(overview.finalizedEvidence, 8);
      expect(overview.flaggedEvidence, 3);
      expect(overview.returnedEvidence, 2);
    });

    test('SupervisorOverview handles missing metrics safely with default 0', () {
      final overview = SupervisorOverview.fromMap({});

      expect(overview.totalCases, 0);
      expect(overview.flaggedEvidence, 0);
      expect(overview.returnedEvidence, 0);
      expect(overview.pendingReview, 0);
    });

    test('SupervisorEvidenceSummary parses review_reason and summary fields', () {
      final summary = SupervisorEvidenceSummary.fromMap({
        'id': 'evidence-101',
        'test_id': 'test-202',
        'test_number': 'NIRVA-TEST-555',
        'case_number': 'CASE-999',
        'operator': 'Officer Kumar',
        'captured_at': '2026-09-12T08:15:00Z',
        'evidence_status': 'ANALYZED',
        'review_status': 'FLAGGED',
        'review_reason': 'Suspected lighting anomaly',
        'analysis_result': 'DEMO_CLASS_B',
        'confidence': 0.89,
        'integrity_status': 'CHAIN_INTACT',
        'finalized': false,
      });

      expect(summary.id, 'evidence-101');
      expect(summary.testNumber, 'NIRVA-TEST-555');
      expect(summary.caseNumber, 'CASE-999');
      expect(summary.reviewStatus, 'FLAGGED');
      expect(summary.reviewReason, 'Suspected lighting anomaly');
      expect(summary.confidence, 0.89);
      expect(summary.finalized, false);
    });

    test('SupervisorEvidenceDetail parses review metadata and audit events', () {
      final detail = SupervisorEvidenceDetail.fromMap({
        'id': 'evidence-101',
        'test_id': 'test-202',
        'test_number': 'NIRVA-TEST-555',
        'case_number': 'CASE-999',
        'operator': 'Officer Kumar',
        'captured_at': '2026-09-12T08:15:00Z',
        'evidence_status': 'FINALIZED',
        'review_status': 'APPROVED',
        'review_reason': 'Full verification passed',
        'analysis_result': 'DEMO_CLASS_A',
        'confidence': 0.97,
        'integrity_status': 'VERIFIED',
        'finalized': true,
        'operator_id': 'op-101',
        'latitude': 19.0760,
        'longitude': 72.8777,
        'gps_accuracy': 3.2,
        'image_quality_score': 94.0,
        'blur_score': 5.1,
        'brightnessScore': 78.0,
        'image_sha256': 'a' * 64,
        'image_url': 'https://example.com/evidence/1.jpg',
        'analysis_uncertainty': 0.03,
        'model_version': 'nirva-demo-1',
        'legal_label': 'INDICATIVE ONLY - LABORATORY CONFIRMATION REQUIRED',
        'previous_record_hash': 'previous-hash',
        'record_hash': 'current-hash',
        'reviewed_by': 'Supervisor Sharma',
        'reviewed_at': '2026-09-12T09:00:00Z',
        'audit_history': [
          {'event_type': 'CAPTURE', 'created_at': '2026-09-12T08:15:00Z'},
          {'event_type': 'SUPERVISOR_REVIEW', 'created_at': '2026-09-12T09:00:00Z', 'event_data': {'action': 'APPROVE', 'reason': 'Full verification passed'}},
        ],
      });

      expect(detail.reviewedBy, 'Supervisor Sharma');
      expect(detail.reviewReason, 'Full verification passed');
      expect(detail.previousRecordHash, 'previous-hash');
      expect(detail.recordHash, 'current-hash');
      expect(detail.auditHistory, hasLength(2));
      expect(detail.auditHistory[1]['event_type'], 'SUPERVISOR_REVIEW');
    });

    testWidgets('shows integrity verification state for supervisor detail', (tester) async {
      final mockService = MockSupervisorService(
        detail: SupervisorEvidenceDetail(
          id: 'ev-verify',
          testId: 'test-verify',
          testNumber: 'NIRVA-TEST-999',
          caseNumber: 'CASE-999',
          operator: 'Officer Demo',
          capturedAt: DateTime.utc(2026, 9, 12, 10, 30),
          evidenceStatus: 'FINALIZED',
          reviewStatus: 'PENDING',
          reviewReason: null,
          analysisResult: 'DEMO_CLASS_A',
          confidence: 0.91,
          integrityStatus: 'INTEGRITY VERIFIED',
          finalized: true,
          operatorId: 'op-999',
          latitude: 12.3,
          longitude: 45.6,
          gpsAccuracy: 2.1,
          imageQualityScore: 90.0,
          blurScore: 5.2,
          brightnessScore: 72.0,
          imageSha256: 'abc123',
          imageUrl: null,
          analysisUncertainty: 0.08,
          modelVersion: 'nirva-demo-visual-1',
          legalLabel: 'INDICATIVE ONLY - LABORATORY CONFIRMATION REQUIRED',
          previousRecordHash: 'prev-hash',
          recordHash: 'current-hash',
          reviewedBy: null,
          reviewedAt: null,
          auditHistory: [
            {'event_type': 'EVIDENCE_CAPTURED', 'created_at': '2026-09-12T10:30:00Z'},
            {'event_type': 'EVIDENCE_FINALIZED', 'created_at': '2026-09-12T10:45:00Z'},
          ],
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: SupervisorEvidenceScreen(
            service: mockService,
            evidenceId: 'ev-verify',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('INTEGRITY VERIFIED'), findsWidgets);
      expect(find.text('Previous Record Hash'), findsOneWidget);
      expect(find.text('Current Record Hash'), findsOneWidget);
    });
  });

  group('FastApiSupervisorService review payload', () {
    test('review() sends correct payload with action and optional reason', () async {
      String? capturedBody;

      final client = ApiClient(
        baseUrl: 'https://example.com/api',
        supabaseClient: SupabaseClient('https://example.com', 'anon-key'),
        accessToken: 'test-token',
        httpClient: _StubHttpClient((request) {
          if (request is http.Request) {
            capturedBody = request.body;
          }
          return http.Response(
            jsonEncode({
              'id': 'evidence-1',
              'test_id': 'test-1',
              'operator_id': 'op-1',
              'evidence_status': 'ANALYZED',
              'review_status': 'FLAGGED',
              'review_reason': 'Blurry test zone',
              'finalized': false,
              'integrity_status': 'VALID',
              'audit_history': [],
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );

      final service = FastApiSupervisorService(apiClient: client);
      final result = await service.review('evidence-1', 'FLAG', reason: 'Blurry test zone');

      expect(result.reviewStatus, 'FLAGGED');
      expect(result.reviewReason, 'Blurry test zone');
      expect(capturedBody, isNotNull);
      final parsed = jsonDecode(capturedBody!) as Map<String, dynamic>;
      expect(parsed['action'], 'FLAG');
      expect(parsed['reason'], 'Blurry test zone');
    });

    test('review() omits reason when reason is null', () async {
      String? capturedBody;

      final client = ApiClient(
        baseUrl: 'https://example.com/api',
        supabaseClient: SupabaseClient('https://example.com', 'anon-key'),
        accessToken: 'test-token',
        httpClient: _StubHttpClient((request) {
          if (request is http.Request) {
            capturedBody = request.body;
          }
          return http.Response(
            jsonEncode({
              'id': 'evidence-1',
              'test_id': 'test-1',
              'operator_id': 'op-1',
              'evidence_status': 'FINALIZED',
              'review_status': 'APPROVED',
              'finalized': true,
              'integrity_status': 'VALID',
              'audit_history': [],
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );

      final service = FastApiSupervisorService(apiClient: client);
      await service.review('evidence-1', 'APPROVE');

      expect(capturedBody, isNotNull);
      final parsed = jsonDecode(capturedBody!) as Map<String, dynamic>;
      expect(parsed['action'], 'APPROVE');
      expect(parsed.containsKey('reason'), isFalse);
    });
  });

  group('Supervisor Dashboard Screen', () {
    testWidgets('renders all 7 metrics including flagged and returned', (tester) async {
      final mockService = MockSupervisorService();
      final authService = FakeSupervisorAuthService();

      await tester.pumpWidget(
        MaterialApp(
          home: SupervisorDashboardScreen(
            service: mockService,
            authService: authService,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Total Cases'), findsOneWidget);
      expect(find.text('Test Sessions'), findsOneWidget);
      expect(find.text('Total Evidence'), findsOneWidget);
      expect(find.text('Pending Review'), findsOneWidget);
      expect(find.text('Flagged'), findsOneWidget);
      expect(find.text('Returned'), findsOneWidget);
      expect(find.text('Finalized'), findsOneWidget);

      expect(find.text('8'), findsOneWidget); // Total cases
      expect(find.text('14'), findsOneWidget); // Test sessions
      expect(find.text('2'), findsOneWidget); // Flagged
      expect(find.text('1'), findsOneWidget); // Returned
    });

    testWidgets('contains all valid review filter chips: ALL, PENDING, APPROVED, FLAGGED, RETURNED', (tester) async {
      final mockService = MockSupervisorService();
      final authService = FakeSupervisorAuthService();

      await tester.pumpWidget(
        MaterialApp(
          home: SupervisorDashboardScreen(
            service: mockService,
            authService: authService,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.widgetWithText(ChoiceChip, 'ALL'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, 'PENDING'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, 'APPROVED'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, 'FLAGGED'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, 'RETURNED'), findsOneWidget);

      // Verify that old invalid chips do not exist
      expect(find.widgetWithText(ChoiceChip, 'ANALYZED'), findsNothing);
      expect(find.widgetWithText(ChoiceChip, 'FINALIZED'), findsNothing);
    });

    testWidgets('tapping filter chips queries backend with matching status', (tester) async {
      final mockService = MockSupervisorService();
      final authService = FakeSupervisorAuthService();

      await tester.pumpWidget(
        MaterialApp(
          home: SupervisorDashboardScreen(
            service: mockService,
            authService: authService,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ChoiceChip, 'FLAGGED'));
      await tester.pumpAndSettle();

      expect(mockService.lastFilterStatus, 'FLAGGED');

      await tester.tap(find.widgetWithText(ChoiceChip, 'APPROVED'));
      await tester.pumpAndSettle();

      expect(mockService.lastFilterStatus, 'APPROVED');
    });

    testWidgets('renders empty state message when evidence list is empty', (tester) async {
      final mockService = MockSupervisorService(evidenceList: []);
      final authService = FakeSupervisorAuthService();

      await tester.pumpWidget(
        MaterialApp(
          home: SupervisorDashboardScreen(
            service: mockService,
            authService: authService,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No evidence matches this review queue.'), findsOneWidget);
    });

    testWidgets('renders error state when overview fails to load', (tester) async {
      final mockService = MockSupervisorService(throwOverviewError: true);
      final authService = FakeSupervisorAuthService();

      await tester.pumpWidget(
        MaterialApp(
          home: SupervisorDashboardScreen(
            service: mockService,
            authService: authService,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Dashboard metrics could not be loaded.'), findsOneWidget);
    });

    testWidgets('renders evidence queue items with saved reason', (tester) async {
      final mockService = MockSupervisorService(
        evidenceList: [
          const SupervisorEvidenceSummary(
            id: 'ev-1',
            testId: 't-1',
            testNumber: 'TEST-1001',
            caseNumber: 'CASE-2026',
            operator: 'Officer Demo',
            capturedAt: null,
            evidenceStatus: 'ANALYZED',
            reviewStatus: 'FLAGGED',
            reviewReason: 'Glare on sensor window',
            analysisResult: 'DEMO_POSITIVE',
            confidence: 0.91,
            integrityStatus: 'VALID',
            finalized: false,
          ),
        ],
      );
      final authService = FakeSupervisorAuthService();

      await tester.pumpWidget(
        MaterialApp(
          home: SupervisorDashboardScreen(
            service: mockService,
            authService: authService,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('CASE-2026'), findsOneWidget);
      expect(find.textContaining('TEST-1001'), findsOneWidget);
      expect(find.text('Reason: Glare on sensor window'), findsOneWidget);
    });

    testWidgets('sign out button calls authService.signOut()', (tester) async {
      final mockService = MockSupervisorService();
      final authService = FakeSupervisorAuthService();

      await tester.pumpWidget(
        MaterialApp(
          home: SupervisorDashboardScreen(
            service: mockService,
            authService: authService,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(authService.signedOut, isFalse);
      await tester.tap(find.byTooltip('Sign out'));
      await tester.pump();

      expect(authService.signedOut, isTrue);
    });
  });

  group('Supervisor Evidence Screen', () {
    testWidgets('displays evidence details, hashes, saved reason, and legal disclaimer', (tester) async {
      final mockService = MockSupervisorService();

      await tester.pumpWidget(
        MaterialApp(
          home: SupervisorEvidenceScreen(
            service: mockService,
            evidenceId: 'ev-sample-1',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Supervisor Evidence Detail'), findsOneWidget);
      expect(find.textContaining('CASE-2026-001'), findsOneWidget);
      expect(find.textContaining('NIRVA-TEST-101'), findsOneWidget);
      expect(find.textContaining('Officer Demo'), findsOneWidget);
      expect(find.text('Saved Review Reason / Notes'), findsOneWidget);
      expect(find.text('Awaiting primary inspection'), findsOneWidget);
      expect(find.text('INDICATIVE ONLY - LABORATORY CONFIRMATION REQUIRED'), findsOneWidget);
      expect(find.text('Audit History Trail'), findsOneWidget);
    });

    testWidgets('Approve action allows optional reason and updates detail', (tester) async {
      final mockService = MockSupervisorService();

      await tester.pumpWidget(
        MaterialApp(
          home: SupervisorEvidenceScreen(
            service: mockService,
            evidenceId: 'ev-sample-1',
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Approve'));
      await tester.pumpAndSettle();

      expect(find.text('Approve Evidence'), findsOneWidget);
      expect(find.text('Notes / Remarks (Optional)'), findsOneWidget);

      // Enter optional remark
      await tester.enterText(find.byType(TextFormField), 'All chain of custody verified');
      await tester.tap(find.text('Confirm Approval'));
      await tester.pumpAndSettle();

      expect(mockService.lastAction, 'APPROVE');
      expect(mockService.lastReason, 'All chain of custody verified');
      expect(find.text('Evidence review status updated: APPROVE'), findsOneWidget);
    });

    testWidgets('Flag action enforces required reason validation', (tester) async {
      final mockService = MockSupervisorService();

      await tester.pumpWidget(
        MaterialApp(
          home: SupervisorEvidenceScreen(
            service: mockService,
            evidenceId: 'ev-sample-1',
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(OutlinedButton, 'Flag Evidence'));
      await tester.pumpAndSettle();

      expect(find.text('Flag Evidence'), findsOneWidget);
      expect(find.text('Reason (Required)'), findsOneWidget);

      // Attempt to submit with empty reason
      await tester.tap(find.widgetWithText(FilledButton, 'FLAG'));
      await tester.pumpAndSettle();

      // Validation error must appear
      expect(find.text('Please provide a reason before submitting.'), findsOneWidget);
      expect(mockService.lastAction, isNull);

      // Enter valid reason and submit
      await tester.enterText(find.byType(TextFormField), 'Test card appears tilted');
      await tester.tap(find.widgetWithText(FilledButton, 'FLAG'));
      await tester.pumpAndSettle();

      expect(mockService.lastAction, 'FLAG');
      expect(mockService.lastReason, 'Test card appears tilted');
    });

    testWidgets('Return action enforces required reason validation', (tester) async {
      final mockService = MockSupervisorService();

      await tester.pumpWidget(
        MaterialApp(
          home: SupervisorEvidenceScreen(
            service: mockService,
            evidenceId: 'ev-sample-1',
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(OutlinedButton, 'Return for Review'));
      await tester.pumpAndSettle();

      expect(find.text('Return Evidence for Review'), findsOneWidget);

      // Submit empty
      await tester.tap(find.widgetWithText(FilledButton, 'RETURN'));
      await tester.pumpAndSettle();

      expect(find.text('Please provide a reason before submitting.'), findsOneWidget);
      expect(mockService.lastAction, isNull);

      // Enter valid reason
      await tester.enterText(find.byType(TextFormField), 'Recapture required under daylight');
      await tester.tap(find.widgetWithText(FilledButton, 'RETURN'));
      await tester.pumpAndSettle();

      expect(mockService.lastAction, 'RETURN');
      expect(mockService.lastReason, 'Recapture required under daylight');
    });
  });

  group('AuthGate Routing & Loading Fix', () {
    testWidgets('shows loading CircularProgressIndicator while profile is resolving without showing HomeScreen or SupervisorDashboard', (tester) async {
      final session = Session(
        accessToken: 'dummy-token',
        tokenType: 'bearer',
        user: const User(
          id: 'user-sup',
          appMetadata: {},
          userMetadata: {},
          aud: 'authenticated',
          createdAt: '2026-09-12T00:00:00Z',
        ),
      );

      final authService = FakeSupervisorAuthService(
        session: session,
        profile: const Profile(
          id: 'user-sup',
          displayName: 'Supervisor Kumar',
          role: ProfileRole.supervisor,
        ),
        profileDelay: const Duration(milliseconds: 500),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: AuthGate(authService: authService),
        ),
      );

      // Immediately after initial pump, future is pending (waiting)
      await tester.pump();

      // Must show loading indicator
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Must NOT show HomeScreen or SupervisorDashboardScreen yet
      expect(find.byType(HomeScreen), findsNothing);
      expect(find.byType(SupervisorDashboardScreen), findsNothing);
      expect(find.byType(LoginScreen), findsNothing);

      // After future completes
      await tester.pumpAndSettle();

      // Supervisor is routed to SupervisorDashboardScreen
      expect(find.byType(SupervisorDashboardScreen), findsOneWidget);
      expect(find.byType(HomeScreen), findsNothing);
    });

    testWidgets('routes OFFICER role to HomeScreen after resolution', (tester) async {
      final session = Session(
        accessToken: 'dummy-token',
        tokenType: 'bearer',
        user: const User(
          id: 'user-off',
          appMetadata: {},
          userMetadata: {},
          aud: 'authenticated',
          createdAt: '2026-09-12T00:00:00Z',
        ),
      );

      final authService = FakeSupervisorAuthService(
        session: session,
        profile: const Profile(
          id: 'user-off',
          displayName: 'Officer Patel',
          role: ProfileRole.officer,
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: AuthGate(authService: authService),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.byType(SupervisorDashboardScreen), findsNothing);
    });

    testWidgets('routes ADMIN role to SupervisorDashboardScreen after resolution', (tester) async {
      final session = Session(
        accessToken: 'dummy-token',
        tokenType: 'bearer',
        user: const User(
          id: 'user-admin',
          appMetadata: {},
          userMetadata: {},
          aud: 'authenticated',
          createdAt: '2026-09-12T00:00:00Z',
        ),
      );

      final authService = FakeSupervisorAuthService(
        session: session,
        profile: const Profile(
          id: 'user-admin',
          displayName: 'Admin Roy',
          role: ProfileRole.admin,
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: AuthGate(authService: authService),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SupervisorDashboardScreen), findsOneWidget);
      expect(find.byType(HomeScreen), findsNothing);
    });

    testWidgets('routes unauthenticated user to LoginScreen', (tester) async {
      final authService = FakeSupervisorAuthService(session: null);

      await tester.pumpWidget(
        MaterialApp(
          home: AuthGate(authService: authService),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(HomeScreen), findsNothing);
      expect(find.byType(SupervisorDashboardScreen), findsNothing);
    });
  });
}
