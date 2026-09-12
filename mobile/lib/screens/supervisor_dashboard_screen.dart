import 'package:flutter/material.dart';

import '../models/supervisor_models.dart';
import '../services/supervisor_service.dart';
import 'supervisor_evidence_screen.dart';

class SupervisorDashboardScreen extends StatefulWidget {
  const SupervisorDashboardScreen({required this.service, super.key});
  final SupervisorService service;

  @override
  State<SupervisorDashboardScreen> createState() => _SupervisorDashboardScreenState();
}

class _SupervisorDashboardScreenState extends State<SupervisorDashboardScreen> {
  late Future<SupervisorOverview> _overview;
  late Future<List<SupervisorEvidenceSummary>> _evidence;
  String _filter = 'ALL';
  String _search = '';

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _overview = widget.service.getOverview();
    _evidence = widget.service.getEvidence(status: _filter, search: _search);
  }

  void _applyFilter(String value) => setState(() { _filter = value; _reload(); });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('NIRVA Supervisor Dashboard')),
      body: RefreshIndicator(
        onRefresh: () async => setState(_reload),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            FutureBuilder<SupervisorOverview>(future: _overview, builder: (context, snapshot) {
              if (snapshot.hasError) return _ErrorState(message: 'Dashboard metrics could not be loaded.');
              if (!snapshot.hasData) return const LinearProgressIndicator();
              final data = snapshot.data!;
              return Wrap(spacing: 12, runSpacing: 12, children: [
                _Metric('Total Cases', data.totalCases), _Metric('Active Tests', data.totalTestSessions),
                _Metric('Pending Review', data.pendingReview), _Metric('Finalized Evidence', data.finalizedEvidence),
              ]);
            }),
            const SizedBox(height: 24),
            Text('Evidence Review Queue', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 12),
            TextField(decoration: const InputDecoration(labelText: 'Search case, test, or evidence ID', prefixIcon: Icon(Icons.search)),
              onSubmitted: (value) => setState(() { _search = value; _reload(); })),
            const SizedBox(height: 8),
            SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [
              for (final value in const ['ALL', 'PENDING', 'ANALYZED', 'FINALIZED', 'FLAGGED', 'RETURNED'])
                Padding(padding: const EdgeInsets.only(right: 8), child: ChoiceChip(label: Text(value), selected: _filter == value, onSelected: (_) => _applyFilter(value))),
            ])),
            FutureBuilder<List<SupervisorEvidenceSummary>>(future: _evidence, builder: (context, snapshot) {
              if (snapshot.hasError) return _ErrorState(message: 'Evidence queue could not be loaded.');
              if (!snapshot.hasData) return const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator()));
              if (snapshot.data!.isEmpty) return const Padding(padding: EdgeInsets.all(32), child: Center(child: Text('No evidence matches this review queue.')));
              return Column(children: snapshot.data!.map((item) => Card(child: ListTile(
                title: Text('${item.caseNumber ?? 'Case'}  /  ${item.testNumber ?? item.testId}'),
                subtitle: Text('${item.operator ?? 'Unknown operator'}  •  ${item.reviewStatus}  •  ${item.analysisResult ?? 'Not analyzed'}'),
                trailing: Text(item.confidence == null ? '—' : '${(item.confidence! * 100).round()}%'),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => SupervisorEvidenceScreen(service: widget.service, evidenceId: item.id))),
              ))).toList());
            }),
          ],
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric(this.label, this.value);
  final String label;
  final int value;
  @override
  Widget build(BuildContext context) => SizedBox(width: 160, child: Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label), const SizedBox(height: 8), Text('$value', style: Theme.of(context).textTheme.headlineMedium)]))));
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.all(24), child: Text(message, textAlign: TextAlign.center));
}