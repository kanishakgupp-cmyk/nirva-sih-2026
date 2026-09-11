import 'package:flutter/material.dart';

import '../models/case_model.dart';
import '../services/test_session_service.dart';
import 'kit_verification_screen.dart';

class StartTestScreen extends StatefulWidget {
  const StartTestScreen({
    required this.caseItem,
    required this.testSessionService,
    super.key,
  });

  final CaseModel caseItem;
  final TestSessionService testSessionService;

  @override
  State<StartTestScreen> createState() => _StartTestScreenState();
}

class _StartTestScreenState extends State<StartTestScreen> {
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _createTestSession() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final session = await widget.testSessionService.createTestSession(
        caseId: widget.caseItem.id,
      );
      if (mounted) {
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => KitVerificationScreen(
              session: session,
              caseItem: widget.caseItem,
            ),
          ),
        );
      }
    } on TestSessionServiceException catch (error) {
      if (mounted) {
        setState(() => _errorMessage = error.message);
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _errorMessage =
              'The test session could not be created. Please try again.';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Start Test')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
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
                  'Start Test',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 28),
                _SummaryRow(
                  label: 'Case Number',
                  value: widget.caseItem.caseNumber,
                ),
                _SummaryRow(label: 'Case Title', value: widget.caseItem.title),
                const SizedBox(height: 28),
                if (_errorMessage != null) ...[
                  Text(
                    _errorMessage!,
                    key: const Key('test-session-error'),
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                  const SizedBox(height: 16),
                ],
                FilledButton.icon(
                  onPressed: _isLoading ? null : _createTestSession,
                  icon: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.add_task),
                  label: Text(
                    _isLoading ? 'Creating Session...' : 'Create Test Session',
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  'INDICATIVE ONLY - LABORATORY CONFIRMATION REQUIRED',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: Theme.of(context).colorScheme.error,
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 4),
          Text(value, style: Theme.of(context).textTheme.titleMedium),
        ],
      ),
    );
  }
}
