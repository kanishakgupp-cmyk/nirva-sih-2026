import 'package:flutter/material.dart';

import '../models/supervisor_models.dart';
import '../services/supervisor_service.dart';

class SupervisorEvidenceScreen extends StatefulWidget {
  const SupervisorEvidenceScreen({required this.service, required this.evidenceId, super.key});
  final SupervisorService service;
  final String evidenceId;
  @override
  State<SupervisorEvidenceScreen> createState() => _SupervisorEvidenceScreenState();
}

class _SupervisorEvidenceScreenState extends State<SupervisorEvidenceScreen> {
  late Future<SupervisorEvidenceDetail> _detail;
  @override
  void initState() { super.initState(); _detail = widget.service.getEvidenceDetail(widget.evidenceId); }

  Future<void> _review(String action) async {
    final approved = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
      title: Text('$action evidence?'), content: const Text('This creates a supervisor audit event.'),
      actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Confirm'))],
    ));
    if (approved != true) return;
    setState(() { _detail = widget.service.review(widget.evidenceId, action); });
  }

  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Evidence Review')), body: FutureBuilder<SupervisorEvidenceDetail>(future: _detail, builder: (context, snapshot) {
    if (snapshot.hasError) return const Center(child: Text('Evidence details could not be loaded.'));
    if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
    final item = snapshot.data!;
    return ListView(padding: const EdgeInsets.all(16), children: [
      Text('Case: ${item.caseNumber ?? '—'}'), Text('Test: ${item.testNumber ?? item.testId}'), Text('Operator: ${item.operator ?? item.operatorId}'),
      Text('Captured: ${item.capturedAt ?? '—'}'), const SizedBox(height: 16),
      if (item.imageUrl != null) Image.network(item.imageUrl!, height: 220, fit: BoxFit.contain),
      _section('Evidence Identity', ['${item.id}', 'SHA-256: ${item.imageSha256 ?? '—'}', 'Status: ${item.reviewStatus}']),
      _section('Quality', ['Score: ${item.imageQualityScore ?? '—'}', 'Blur: ${item.blurScore ?? '—'}', 'Brightness: ${item.brightnessScore ?? '—'}']),
      _section('Location', ['${item.latitude ?? '—'}, ${item.longitude ?? '—'}', 'GPS accuracy: ${item.gpsAccuracy ?? '—'}']),
      _section('Analysis', ['Result: ${item.analysisResult ?? '—'}', 'Confidence: ${item.confidence ?? '—'}', 'Uncertainty: ${item.analysisUncertainty ?? '—'}', 'Model: ${item.modelVersion ?? '—'}']),
      _section('Integrity', [item.integrityStatus, item.finalized ? 'Finalized' : 'Not finalized']),
      Text(item.legalLabel ?? 'INDICATIVE DEMONSTRATION RESULT\nLABORATORY CONFIRMATION REQUIRED', style: TextStyle(color: Theme.of(context).colorScheme.error, fontWeight: FontWeight.bold)),
      const SizedBox(height: 12), Text('Audit Timeline', style: Theme.of(context).textTheme.titleLarge),
      ...item.auditHistory.map((event) => ListTile(dense: true, title: Text(event['event_type'] as String? ?? 'Event'), subtitle: Text(event['created_at'] as String? ?? ''))),
      if (item.reviewStatus != 'APPROVED') Row(children: [Expanded(child: FilledButton(onPressed: () => _review('APPROVE'), child: const Text('Approve'))), const SizedBox(width: 8), Expanded(child: OutlinedButton(onPressed: () => _review('FLAG'), child: const Text('Flag'))), const SizedBox(width: 8), Expanded(child: OutlinedButton(onPressed: () => _review('RETURN'), child: const Text('Return for Review')))]),
    ]);
  }));
}

Widget _section(String title, List<String> values) => Padding(padding: const EdgeInsets.symmetric(vertical: 10), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.bold)), ...values.map(Text.new)]));