class WorkflowStep {
  const WorkflowStep({
    required this.id,
    required this.title,
    required this.description,
    required this.durationSeconds,
    required this.requiresTimer,
    required this.isRequired,
  });

  final String id;
  final String title;
  final String description;
  final int durationSeconds;
  final bool requiresTimer;
  final bool isRequired;

  factory WorkflowStep.fromMap(Map<String, dynamic> map) {
    return WorkflowStep(
      id: map['id'] as String? ?? '',
      title: map['title'] as String? ?? '',
      description: map['description'] as String? ?? '',
      durationSeconds: _parseInt(map['duration_seconds']) ?? 0,
      requiresTimer: map['requires_timer'] as bool? ?? false,
      isRequired: map['is_required'] as bool? ?? true,
    );
  }

  static int? _parseInt(Object? value) {
    if (value is int) {
      return value;
    }
    return int.tryParse('$value');
  }
}

class WorkflowState {
  const WorkflowState({
    required this.currentStepIndex,
    required this.completedSteps,
    required this.startedAt,
    required this.completedAt,
    required this.timerStartedAt,
    required this.timerCompletedAt,
  });

  final int currentStepIndex;
  final Set<String> completedSteps;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final DateTime? timerStartedAt;
  final DateTime? timerCompletedAt;

  WorkflowState copyWith({
    int? currentStepIndex,
    Set<String>? completedSteps,
    DateTime? startedAt,
    DateTime? completedAt,
    DateTime? timerStartedAt,
    DateTime? timerCompletedAt,
  }) {
    return WorkflowState(
      currentStepIndex: currentStepIndex ?? this.currentStepIndex,
      completedSteps: completedSteps ?? this.completedSteps,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      timerStartedAt: timerStartedAt ?? this.timerStartedAt,
      timerCompletedAt: timerCompletedAt ?? this.timerCompletedAt,
    );
  }
}
