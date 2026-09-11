import 'package:flutter/material.dart';

import '../models/case_model.dart';
import '../models/kit.dart';
import '../models/test_session.dart';
import '../services/test_session_service.dart';
import '../services/workflow_service.dart';
import 'guided_workflow_screen.dart';

class TestSessionScreen extends StatelessWidget {
  const TestSessionScreen({
    required this.session,
    required this.caseItem,
    required this.kit,
    this.testSessionService,
    this.workflowService = const WorkflowService(),
    super.key,
  });

  final TestSession session;
  final CaseModel caseItem;
  final Kit kit;
  final TestSessionService? testSessionService;
  final WorkflowService workflowService;

  @override
  Widget build(BuildContext context) {
    return GuidedWorkflowScreen(
      session: session,
      caseItem: caseItem,
      kit: kit,
      testSessionService: testSessionService,
      workflowService: workflowService,
    );
  }
}
