import 'package:flutter/material.dart';

import '../models/case_model.dart';
import '../models/kit.dart';
import '../models/test_session.dart';
import '../models/workflow_step.dart';
import '../services/workflow_service.dart';
import '../widgets/workflow_timer.dart';
import 'evidence_capture_screen.dart';

class GuidedWorkflowScreen extends StatefulWidget {
  const GuidedWorkflowScreen({
    required this.session,
    required this.caseItem,
    required this.kit,
    this.workflowService = const WorkflowService(),
    super.key,
  });

  final TestSession session;
  final CaseModel caseItem;
  final Kit kit;
  final WorkflowService workflowService;

  @override
  State<GuidedWorkflowScreen> createState() => _GuidedWorkflowScreenState();
}

class _GuidedWorkflowScreenState extends State<GuidedWorkflowScreen> {
  late final List<WorkflowStep> _steps;
  late WorkflowState _workflowState;
  String? _errorMessage;
  bool _isCompleting = false;

  @override
  void initState() {
    super.initState();
    _steps = widget.workflowService.getDemoWorkflow();
    _workflowState = WorkflowState(
      currentStepIndex: 0,
      completedSteps: <String>{},
      startedAt: DateTime.now(),
      completedAt: null,
      timerStartedAt: null,
      timerCompletedAt: null,
    );
  }

  bool get _isComplete => _workflowState.completedAt != null;

  WorkflowStep? get _currentStep {
    final index = _workflowState.currentStepIndex;
    if (index < 0 || index >= _steps.length) {
      return null;
    }
    return _steps[index];
  }

  Future<bool> _confirmLeave() async {
    if (_isComplete) {
      return true;
    }
    final shouldLeave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave workflow?'),
        content: const Text(
          'Your current demonstration workflow progress will not be completed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Stay'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
    return shouldLeave ?? false;
  }

  Future<void> _completeCurrentStep() async {
    final step = _currentStep;
    if (step == null || _isCompleting) {
      return;
    }

    final completed = {..._workflowState.completedSteps, step.id};
    final isLastStep = _workflowState.currentStepIndex == _steps.length - 1;
    if (!isLastStep) {
      setState(() {
        _workflowState = _workflowState.copyWith(
          currentStepIndex: _workflowState.currentStepIndex + 1,
          completedSteps: completed,
          timerStartedAt: null,
          timerCompletedAt: null,
        );
      });
      return;
    }

    setState(() {
      _isCompleting = true;
      _errorMessage = null;
    });
    if (mounted) {
      setState(() {
        _workflowState = _workflowState.copyWith(
          completedSteps: completed,
          completedAt: DateTime.now(),
        );
        _isCompleting = false;
      });
    }
  }

  void _timerStarted() {
    setState(() {
      _workflowState = _workflowState.copyWith(timerStartedAt: DateTime.now());
    });
  }

  void _timerCompleted() {
    setState(() {
      _workflowState = _workflowState.copyWith(
        timerCompletedAt: DateTime.now(),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _isComplete,
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop && await _confirmLeave() && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Guided Test Workflow')),
        body: _isComplete
            ? _CompletionView(widget: widget)
            : _WorkflowBody(
                steps: _steps,
                state: _workflowState,
                currentStep: _currentStep,
                session: widget.session,
                caseItem: widget.caseItem,
                kit: widget.kit,
                errorMessage: _errorMessage,
                isCompleting: _isCompleting,
                onTimerStarted: _timerStarted,
                onTimerCompleted: _timerCompleted,
                onCompleteStep: _completeCurrentStep,
              ),
      ),
    );
  }
}

class _WorkflowBody extends StatelessWidget {
  const _WorkflowBody({
    required this.steps,
    required this.state,
    required this.currentStep,
    required this.session,
    required this.caseItem,
    required this.kit,
    required this.errorMessage,
    required this.isCompleting,
    required this.onTimerStarted,
    required this.onTimerCompleted,
    required this.onCompleteStep,
  });

  final List<WorkflowStep> steps;
  final WorkflowState state;
  final WorkflowStep? currentStep;
  final TestSession session;
  final CaseModel caseItem;
  final Kit kit;
  final String? errorMessage;
  final bool isCompleting;
  final VoidCallback onTimerStarted;
  final VoidCallback onTimerCompleted;
  final VoidCallback onCompleteStep;

  @override
  Widget build(BuildContext context) {
    if (currentStep == null || steps.isEmpty) {
      return const Center(
          child: Text('The demonstration workflow is unavailable.'));
    }

    final step = currentStep!;
    final timerFinished = state.timerCompletedAt != null;
    final canComplete = !step.requiresTimer || timerFinished;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _DemoBanner(),
              const SizedBox(height: 16),
              _SessionSummary(
                session: session,
                caseItem: caseItem,
                kit: kit,
              ),
              const SizedBox(height: 20),
              Text(
                'Step ${state.currentStepIndex + 1} of ${steps.length}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Semantics(
                label: 'Workflow progress',
                value:
                    '${state.completedSteps.length} of ${steps.length} steps complete',
                child: LinearProgressIndicator(
                  value: state.completedSteps.length / steps.length,
                ),
              ),
              const SizedBox(height: 24),
              _StepHistory(steps: steps, completedSteps: state.completedSteps),
              const SizedBox(height: 20),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(step.title,
                          style: Theme.of(context).textTheme.headlineSmall),
                      const SizedBox(height: 8),
                      Text(step.description),
                      const SizedBox(height: 20),
                      if (step.requiresTimer)
                        WorkflowTimer(
                          key: ValueKey(step.id),
                          duration: Duration(seconds: step.durationSeconds),
                          onStarted: onTimerStarted,
                          onCompleted: onTimerCompleted,
                        ),
                      if (step.requiresTimer) const SizedBox(height: 20),
                      FilledButton(
                        onPressed: canComplete && !isCompleting
                            ? onCompleteStep
                            : null,
                        child: Text(
                          isCompleting
                              ? 'Completing...'
                              : canComplete
                                  ? 'Complete Step'
                                  : 'Complete Step (timer required)',
                        ),
                      ),
                      if (errorMessage != null) ...[
                        const SizedBox(height: 16),
                        Text(
                          errorMessage!,
                          key: const Key('workflow-error'),
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SessionSummary extends StatelessWidget {
  const _SessionSummary({
    required this.session,
    required this.caseItem,
    required this.kit,
  });

  final TestSession session;
  final CaseModel caseItem;
  final Kit kit;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('NIRVA'),
            Text('Test Number: ${session.testNumber}'),
            Text('Case: ${caseItem.caseNumber}'),
            Text('Kit: ${kit.kitCode}'),
            const Text('Status: RUNNING'),
          ],
        ),
      ),
    );
  }
}

class _DemoBanner extends StatelessWidget {
  const _DemoBanner();

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.tertiaryContainer,
      child: const Padding(
        padding: EdgeInsets.all(14),
        child: Text(
          'DEMONSTRATION WORKFLOW — NOT A VALIDATED LABORATORY PROTOCOL',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

class _StepHistory extends StatelessWidget {
  const _StepHistory({required this.steps, required this.completedSteps});

  final List<WorkflowStep> steps;
  final Set<String> completedSteps;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: steps.map((step) {
        final completed = completedSteps.contains(step.id);
        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text('${completed ? '✓' : '→'} ${step.title}'),
        );
      }).toList(),
    );
  }
}

class _CompletionView extends StatelessWidget {
  const _CompletionView({required this.widget});

  final GuidedWorkflowScreen widget;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _DemoBanner(),
              const SizedBox(height: 24),
              Text(
                'WORKFLOW COMPLETE',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 24),
              Text('Test Number: ${widget.session.testNumber}'),
              Text('Case: ${widget.caseItem.caseNumber}'),
              Text('Kit: ${widget.kit.kitCode}'),
              const SizedBox(height: 12),
              const Text('Status: READY FOR EVIDENCE CAPTURE'),
              const SizedBox(height: 20),
              const Text(
                'Evidence capture will be implemented in the next phase.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => EvidenceCaptureScreen(
                      session: widget.session,
                      caseItem: widget.caseItem,
                      kit: widget.kit,
                    ),
                  ),
                ),
                child: const Text('Continue to Evidence Capture'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
