import '../models/workflow_step.dart';

class WorkflowService {
  const WorkflowService();

  List<WorkflowStep> getDemoWorkflow() {
    return const [
      WorkflowStep(
        id: 'demo_step_1',
        title: 'Demo Preparation',
        description: 'Complete the demonstration preparation step.',
        durationSeconds: 10,
        requiresTimer: false,
        isRequired: true,
      ),
      WorkflowStep(
        id: 'demo_step_2',
        title: 'Observation Window',
        description: 'Wait for the configured observation window.',
        durationSeconds: 20,
        requiresTimer: true,
        isRequired: true,
      ),
      WorkflowStep(
        id: 'demo_step_3',
        title: 'Demo Observation',
        description: 'Record the demonstration observation.',
        durationSeconds: 10,
        requiresTimer: true,
        isRequired: true,
      ),
    ];
  }
}
