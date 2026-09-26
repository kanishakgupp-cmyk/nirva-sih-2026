import 'package:flutter/material.dart';

import '../models/case_model.dart';
import '../models/evidence_record.dart';
import '../models/test_session.dart';
import 'analysis_screen.dart';

class EvidenceSuccessScreen extends StatelessWidget {
  const EvidenceSuccessScreen({
    required this.record,
    required this.session,
    required this.caseItem,
    super.key,
  });

  final EvidenceRecord record;
  final TestSession session;
  final CaseModel caseItem;

  @override
  Widget build(BuildContext context) {
    final isLocalPending = record.evidenceStatus == 'LOCAL_PENDING_UPLOAD';
    final capturedAt = record.capturedAt?.toLocal().toString() ?? 'Unavailable';
    final hash = record.imageSha256 ?? '';
    final shortHash = hash.length > 16
        ? '${hash.substring(0, 8)}...${hash.substring(hash.length - 8)}'
        : hash;

    return Scaffold(
      appBar: AppBar(title: const Text('Evidence Saved')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'EVIDENCE SAVED',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 24),
                Text('Test Number: ${session.testNumber}'),
                Text('Case: ${caseItem.caseNumber}'),
                Text('Captured: $capturedAt'),
                Text(
                  'Image Quality: '
                  '${record.imageQualityScore?.toStringAsFixed(1) ?? 'Unavailable'}',
                ),
                Text(
                    'GPS: ${record.latitude == null ? 'Unavailable' : 'Available'}'),
                Text('SHA-256: $shortHash'),
                const SizedBox(height: 24),
                Text(
                  isLocalPending
                      ? 'Saved securely on this device. Waiting for connection before server upload.'
                      : 'Evidence capture complete.',
                  textAlign: TextAlign.center,
                ),
                if (isLocalPending) ...[
                  const SizedBox(height: 8),
                  Text(
                    'LOCAL CAPTURE • SERVER CONFIRMATION REQUIRED',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: isLocalPending
                      ? null
                      : () => Navigator.of(context).pushReplacement(
                          MaterialPageRoute(
                            builder: (_) => AnalysisScreen(
                              record: record,
                              session: session,
                              caseItem: caseItem,
                            ),
                          ),
                      ),
                  child: Text(
                    isLocalPending
                        ? 'Waiting for server confirmation'
                        : 'Review and Analyze Evidence',
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
