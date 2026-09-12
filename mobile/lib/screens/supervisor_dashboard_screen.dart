import 'package:flutter/material.dart';

import '../models/supervisor_models.dart';
import '../services/auth_service.dart';
import '../services/supervisor_service.dart';
import 'supervisor_evidence_screen.dart';

class SupervisorDashboardScreen extends StatefulWidget {
  SupervisorDashboardScreen({
    required this.service,
    AuthService? authService,
    super.key,
  }) : authService = authService ?? SupabaseAuthService();

  final SupervisorService service;
  final AuthService authService;

  @override
  State<SupervisorDashboardScreen> createState() => _SupervisorDashboardScreenState();
}

class _SupervisorDashboardScreenState extends State<SupervisorDashboardScreen> {
  late Future<SupervisorOverview> _overview;
  late Future<List<SupervisorEvidenceSummary>> _evidence;
  String _filter = 'ALL';
  String _search = '';
  final _searchController = TextEditingController();

  static const _filterOptions = ['ALL', 'PENDING', 'APPROVED', 'FLAGGED', 'RETURNED'];

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _reload() {
    _overview = widget.service.getOverview();
    _evidence = widget.service.getEvidence(status: _filter, search: _search);
  }

  void _applyFilter(String value) => setState(() {
        _filter = value;
        _reload();
      });

  Future<void> _signOut() async {
    await widget.authService.signOut();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('NIRVA Supervisor Dashboard'),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout),
            onPressed: _signOut,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => setState(_reload),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            FutureBuilder<SupervisorOverview>(
              future: _overview,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const _ErrorState(message: 'Dashboard metrics could not be loaded.');
                }
                if (!snapshot.hasData) return const LinearProgressIndicator();
                final data = snapshot.data!;
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _Metric('Total Cases', data.totalCases, Icons.folder_outlined),
                    _Metric('Test Sessions', data.totalTestSessions, Icons.science_outlined),
                    _Metric('Total Evidence', data.totalEvidenceRecords, Icons.fingerprint),
                    _Metric('Pending Review', data.pendingReview, Icons.pending_actions,
                        color: Colors.amber.shade800),
                    _Metric('Flagged', data.flaggedEvidence, Icons.flag_outlined,
                        color: Colors.orange.shade800),
                    _Metric('Returned', data.returnedEvidence, Icons.assignment_return_outlined,
                        color: Colors.deepOrange.shade700),
                    _Metric('Finalized', data.finalizedEvidence, Icons.verified_outlined,
                        color: Colors.green.shade700),
                  ],
                );
              },
            ),
            const SizedBox(height: 24),
            Text('Evidence Review Queue', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 12),
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Search case, test number, operator, or evidence UUID',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _search.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _search = '';
                            _reload();
                          });
                        },
                      )
                    : null,
              ),
              onSubmitted: (value) => setState(() {
                _search = value.trim();
                _reload();
              }),
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final value in _filterOptions)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(value),
                        selected: _filter == value,
                        onSelected: (_) => _applyFilter(value),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            FutureBuilder<List<SupervisorEvidenceSummary>>(
              future: _evidence,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const _ErrorState(message: 'Evidence queue could not be loaded.');
                }
                if (!snapshot.hasData) {
                  return const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                if (snapshot.data!.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: Text('No evidence matches this review queue.')),
                  );
                }
                return Column(
                  children: snapshot.data!.map((item) {
                    final statusColor = _statusColor(context, item.reviewStatus);
                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: statusColor.withOpacity(0.15),
                          child: Icon(_statusIcon(item.reviewStatus), color: statusColor, size: 20),
                        ),
                        title: Text(
                          '${item.caseNumber ?? 'Case'}  /  ${item.testNumber ?? item.testId}',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 2),
                            Text('${item.operator ?? 'Unknown operator'}  •  ${item.reviewStatus}  •  ${item.analysisResult ?? 'Not analyzed'}'),
                            if (item.reviewReason != null && item.reviewReason!.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(
                                  'Reason: ${item.reviewReason}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontStyle: FontStyle.italic,
                                    color: Theme.of(context).colorScheme.outline,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              item.confidence == null ? '—' : '${(item.confidence! * 100).round()}%',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              item.finalized ? 'Finalized' : item.evidenceStatus,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                        onTap: () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => SupervisorEvidenceScreen(
                                service: widget.service,
                                evidenceId: item.id,
                              ),
                            ),
                          );
                          setState(_reload);
                        },
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Color _statusColor(BuildContext context, String status) {
    switch (status) {
      case 'APPROVED':
        return Colors.green.shade700;
      case 'FLAGGED':
        return Colors.orange.shade800;
      case 'RETURNED':
        return Colors.deepOrange.shade700;
      case 'PENDING':
      default:
        return Colors.amber.shade800;
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'APPROVED':
        return Icons.check_circle_outline;
      case 'FLAGGED':
        return Icons.flag_outlined;
      case 'RETURNED':
        return Icons.assignment_return_outlined;
      case 'PENDING':
      default:
        return Icons.pending_actions;
    }
  }
}

class _Metric extends StatelessWidget {
  const _Metric(this.label, this.value, this.icon, {this.color});
  final String label;
  final int value;
  final IconData icon;
  final Color? color;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 155,
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(label, style: Theme.of(context).textTheme.bodyMedium),
                    Icon(icon, size: 18, color: color ?? Theme.of(context).colorScheme.primary),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '$value',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: color,
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
          ),
        ),
      );
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Text(message, textAlign: TextAlign.center),
      );
}