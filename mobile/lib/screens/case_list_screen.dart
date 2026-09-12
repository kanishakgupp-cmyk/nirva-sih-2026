import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/case_model.dart';
import '../services/case_service.dart';
import 'case_details_screen.dart';
import 'create_case_screen.dart';

class CaseListScreen extends StatefulWidget {
  const CaseListScreen({required this.caseService, super.key});

  final CaseService caseService;

  @override
  State<CaseListScreen> createState() => _CaseListScreenState();
}

class _CaseListScreenState extends State<CaseListScreen> {
  late Future<List<CaseModel>> _casesFuture;

  @override
  void initState() {
    super.initState();
    _loadCases();
  }

  void _loadCases() {
    _casesFuture = widget.caseService.getMyCases();
  }

  Future<void> _refreshCases() async {
    setState(_loadCases);
    await _casesFuture;
  }

  Future<void> _openCreateCase() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => CreateCaseScreen(caseService: widget.caseService),
      ),
    );
    if (created == true && mounted) {
      setState(_loadCases);
    }
  }

  Future<void> _openCase(CaseModel caseItem) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => CaseDetailsScreen(caseItem: caseItem),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cases'),
      ),
      body: FutureBuilder<List<CaseModel>>(
        future: _casesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _CasesError(
              message: _errorMessage(snapshot.error),
              onRetry: () => setState(_loadCases),
            );
          }

          final cases = snapshot.data ?? const <CaseModel>[];
          if (cases.isEmpty) {
            return _EmptyCases(onCreateCase: _openCreateCase);
          }

          return RefreshIndicator(
            onRefresh: _refreshCases,
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              itemCount: cases.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final caseItem = cases[index];
                return _CaseCard(
                  caseItem: caseItem,
                  onTap: () => _openCase(caseItem),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreateCase,
        icon: const Icon(Icons.add),
        label: const Text('New Case'),
      ),
    );
  }

  String _errorMessage(Object? error) {
    if (error is CaseServiceException) {
      return _withDiagnostic(error.userMessage, error.diagnostic);
    }
    return 'Cases could not be loaded. Please check your connection and try again.';
  }

  String _withDiagnostic(String message, String diagnostic) {
    if (!kDebugMode || diagnostic.isEmpty) {
      return message;
    }
    return '$message\n$diagnostic';
  }
}

class _CaseCard extends StatelessWidget {
  const _CaseCard({required this.caseItem, required this.onTap});

  final CaseModel caseItem;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                caseItem.caseNumber,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(caseItem.title, style: theme.textTheme.titleLarge),
              if (caseItem.description?.isNotEmpty == true) ...[
                const SizedBox(height: 8),
                Text(caseItem.description!),
              ],
              const SizedBox(height: 12),
              Text(
                _formatDateTime(caseItem.createdAt),
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyCases extends StatelessWidget {
  const _EmptyCases({required this.onCreateCase});

  final VoidCallback onCreateCase;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.folder_open_outlined, size: 56),
            const SizedBox(height: 16),
            Text('No cases yet',
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            const Text('Create a case to begin the next field workflow.'),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onCreateCase,
              icon: const Icon(Icons.add),
              label: const Text('Create New Case'),
            ),
          ],
        ),
      ),
    );
  }
}

class _CasesError extends StatelessWidget {
  const _CasesError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
            ),
          ],
        ),
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
