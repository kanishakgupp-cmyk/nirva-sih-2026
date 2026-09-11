import 'package:flutter/material.dart';

import '../models/case_model.dart';

class CaseDetailsScreen extends StatelessWidget {
  const CaseDetailsScreen({required this.caseItem, super.key});

  final CaseModel caseItem;

  void _showNextPhaseMessage(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Test workflow will be implemented in the next phase.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Case Details')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _DetailRow(label: 'Case Number', value: caseItem.caseNumber),
                _DetailRow(label: 'Title', value: caseItem.title),
                _DetailRow(
                  label: 'Description',
                  value: caseItem.description?.isNotEmpty == true
                      ? caseItem.description!
                      : 'No description provided',
                ),
                _DetailRow(
                  label: 'Created',
                  value: _formatDateTime(caseItem.createdAt),
                ),
                _DetailRow(label: 'Created by', value: caseItem.createdBy),
                const SizedBox(height: 28),
                FilledButton.icon(
                  onPressed: () => _showNextPhaseMessage(context),
                  icon: const Icon(Icons.play_circle_outline),
                  label: const Text('Start Test'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 4),
          Text(value, style: Theme.of(context).textTheme.bodyLarge),
        ],
      ),
    );
  }
}

String _formatDateTime(DateTime value) {
  final local = value.toLocal();
  String twoDigits(int number) => number.toString().padLeft(2, '0');
  return '${local.day}/${local.month}/${local.year} '
      '${twoDigits(local.hour)}:${twoDigits(local.minute)}';
}
