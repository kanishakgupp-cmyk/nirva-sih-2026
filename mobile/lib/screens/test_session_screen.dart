import 'package:flutter/material.dart';

import '../models/case_model.dart';
import '../models/kit.dart';
import '../models/test_session.dart';

class TestSessionScreen extends StatelessWidget {
  const TestSessionScreen({
    required this.session,
    required this.caseItem,
    required this.kit,
    super.key,
  });

  final TestSession session;
  final CaseModel caseItem;
  final Kit kit;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Test Session')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'NIRVA',
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Test Session',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 28),
                _SessionRow(label: 'Test Number', value: session.testNumber),
                _SessionRow(label: 'Case', value: caseItem.caseNumber),
                _SessionRow(label: 'Kit', value: kit.kitCode),
                const _SessionRow(label: 'Status', value: 'RUNNING'),
                const SizedBox(height: 28),
                const Text(
                  'Guided test workflow will be implemented in the next phase.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SessionRow extends StatelessWidget {
  const _SessionRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(label, style: Theme.of(context).textTheme.labelLarge),
          ),
          Expanded(
            child: Text(value, style: Theme.of(context).textTheme.titleMedium),
          ),
        ],
      ),
    );
  }
}
