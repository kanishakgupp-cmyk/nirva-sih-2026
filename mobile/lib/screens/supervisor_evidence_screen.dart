import 'package:flutter/material.dart';

import '../models/supervisor_models.dart';
import '../services/supervisor_service.dart';

class SupervisorEvidenceScreen extends StatefulWidget {
  const SupervisorEvidenceScreen({
    required this.service,
    required this.evidenceId,
    super.key,
  });

  final SupervisorService service;
  final String evidenceId;

  @override
  State<SupervisorEvidenceScreen> createState() => _SupervisorEvidenceScreenState();
}

class _SupervisorEvidenceScreenState extends State<SupervisorEvidenceScreen> {
  late Future<SupervisorEvidenceDetail> _detail;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _detail = widget.service.getEvidenceDetail(widget.evidenceId);
  }

  Future<void> _review(String action) async {
    final isReasonRequired = action == 'FLAG' || action == 'RETURN';
    final reasonController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          action == 'APPROVE'
              ? 'Approve Evidence'
              : action == 'FLAG'
                  ? 'Flag Evidence'
                  : 'Return Evidence for Review',
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                action == 'APPROVE'
                    ? 'Confirm evidence approval. You may optionally enter approval notes for the audit log.'
                    : action == 'FLAG'
                        ? 'Flag this evidence for supervisor inspection. A reason is required.'
                        : 'Return this evidence to the field officer for review. A reason is required.',
                style: Theme.of(dialogContext).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: reasonController,
                maxLines: 3,
                maxLength: 500,
                decoration: InputDecoration(
                  labelText: isReasonRequired
                      ? 'Reason (Required)'
                      : 'Notes / Remarks (Optional)',
                  hintText: action == 'APPROVE'
                      ? 'e.g. Visual quality and workflow timestamps verified'
                      : action == 'FLAG'
                          ? 'e.g. Image blur or glare detected on test area'
                          : 'e.g. Recapture required due to insufficient lighting',
                  border: const OutlineInputBorder(),
                ),
                validator: (value) {
                  if (isReasonRequired && (value == null || value.trim().isEmpty)) {
                    return 'Please provide a reason before submitting.';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState?.validate() ?? true) {
                Navigator.pop(dialogContext, true);
              }
            },
            child: Text(action == 'APPROVE' ? 'Confirm Approval' : action),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final trimmedReason = reasonController.text.trim();
    final reasonParam = trimmedReason.isNotEmpty ? trimmedReason : null;

    setState(() {
      _detail = widget.service.review(
        widget.evidenceId,
        action,
        reason: reasonParam,
      ).then((result) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Evidence review status updated: $action'),
              backgroundColor: action == 'APPROVE'
                  ? Colors.green.shade800
                  : action == 'FLAG'
                      ? Colors.orange.shade800
                      : Colors.deepOrange.shade800,
            ),
          );
        }
        return result;
      }).catchError((error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Review action failed: $error'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
        throw error;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Supervisor Evidence Detail'),
      ),
      body: FutureBuilder<SupervisorEvidenceDetail>(
        future: _detail,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline, size: 48, color: Theme.of(context).colorScheme.error),
                    const SizedBox(height: 12),
                    const Text('Evidence details could not be loaded.', style: TextStyle(fontSize: 16)),
                    const SizedBox(height: 16),
                    FilledButton.tonal(
                      onPressed: () => setState(_load),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final item = snapshot.data!;
          final statusColor = _statusColor(item.reviewStatus);

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 820),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  item.caseNumber != null ? 'Case: ${item.caseNumber}' : 'Evidence Record',
                                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),
                              ),
                              Chip(
                                label: Text(
                                  item.reviewStatus,
                                  style: TextStyle(
                                    color: statusColor,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                side: BorderSide(color: statusColor),
                                backgroundColor: statusColor.withOpacity(0.08),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text('Test Number: ${item.testNumber ?? item.testId}'),
                          Text('Field Operator: ${item.operator ?? item.operatorId}'),
                          if (item.capturedAt != null)
                            Text('Captured: ${item.capturedAt!.toLocal()}'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  if (item.imageUrl != null) ...[
                    Card(
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Container(
                            color: Colors.black12,
                            padding: const EdgeInsets.all(8),
                            child: Image.network(
                              item.imageUrl!,
                              height: 280,
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => Container(
                                height: 160,
                                alignment: Alignment.center,
                                child: const Text('Secure preview unavailable'),
                              ),
                            ),
                          ),
                          if (item.imageSha256 != null)
                            Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                children: [
                                  const Icon(Icons.fingerprint, size: 18),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'SHA-256: ${item.imageSha256}',
                                      style: Theme.of(context).textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  if (item.reviewReason != null && item.reviewReason!.isNotEmpty) ...[
                    Card(
                      color: statusColor.withOpacity(0.05),
                      shape: RoundedRectangleBorder(
                        side: BorderSide(color: statusColor.withOpacity(0.4)),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.rate_review_outlined, size: 20, color: statusColor),
                                const SizedBox(width: 8),
                                Text(
                                  'Saved Review Reason / Notes',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: statusColor,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              item.reviewReason!,
                              style: const TextStyle(fontSize: 14),
                            ),
                            if (item.reviewedAt != null || item.reviewedBy != null) ...[
                              const SizedBox(height: 6),
                              Text(
                                'Reviewed: ${item.reviewedAt?.toLocal() ?? 'Recorded'} by ${item.reviewedBy ?? 'Supervisor'}',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      fontStyle: FontStyle.italic,
                                    ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  _CardSection(
                    title: 'Evidence Identity & Chain of Custody',
                    items: [
                      _DetailRow('Evidence ID', item.id),
                      _DetailRow('Test Session ID', item.testId),
                      _DetailRow('Integrity Status', item.integrityStatus),
                      _DetailRow('Finalization', item.finalized ? 'FINALIZED (Tamper-proof)' : 'ACTIVE'),
                      _DetailRow('Evidence Status', item.evidenceStatus),
                    ],
                  ),
                  const SizedBox(height: 12),

                  _CardSection(
                    title: 'Image Quality Verification',
                    items: [
                      _DetailRow('Quality Score', item.imageQualityScore != null ? '${item.imageQualityScore!.toStringAsFixed(1)} / 100' : '—'),
                      _DetailRow('Blur Score', item.blurScore != null ? item.blurScore!.toStringAsFixed(2) : '—'),
                      _DetailRow('Brightness Score', item.brightnessScore != null ? item.brightnessScore!.toStringAsFixed(2) : '—'),
                    ],
                  ),
                  const SizedBox(height: 12),

                  _CardSection(
                    title: 'Field Geolocation',
                    items: [
                      _DetailRow('Coordinates', item.latitude != null && item.longitude != null ? '${item.latitude!.toStringAsFixed(6)}, ${item.longitude!.toStringAsFixed(6)}' : 'Not recorded'),
                      _DetailRow('GPS Accuracy', item.gpsAccuracy != null ? '±${item.gpsAccuracy!.toStringAsFixed(1)} m' : '—'),
                    ],
                  ),
                  const SizedBox(height: 12),

                  _CardSection(
                    title: 'Demonstration Analysis Result',
                    items: [
                      _DetailRow('Indicative Result', item.analysisResult ?? 'Not Analyzed'),
                      _DetailRow('Confidence', item.confidence != null ? '${(item.confidence! * 100).toStringAsFixed(1)}%' : '—'),
                      _DetailRow('Uncertainty', item.analysisUncertainty != null ? '${(item.analysisUncertainty! * 100).toStringAsFixed(1)}%' : '—'),
                      _DetailRow('Model Version', item.modelVersion ?? 'nirva-demo-visual-1'),
                    ],
                  ),
                  const SizedBox(height: 12),

                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.errorContainer.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Theme.of(context).colorScheme.error.withOpacity(0.5)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.legalLabel ?? 'INDICATIVE ONLY - LABORATORY CONFIRMATION REQUIRED',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Presumptive field screening demonstration only. Not for standalone legal determination without accredited forensic laboratory testing.',
                          style: TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  if (item.reviewStatus != 'APPROVED') ...[
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Supervisor Review Actions',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Select an action to update this evidence record and record an audit event.',
                              style: TextStyle(fontSize: 12),
                            ),
                            const SizedBox(height: 16),
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final isNarrow = constraints.maxWidth < 500;
                                final buttons = [
                                  FilledButton.icon(
                                    onPressed: () => _review('APPROVE'),
                                    icon: const Icon(Icons.check_circle_outline),
                                    label: const Text('Approve'),
                                    style: FilledButton.styleFrom(
                                      backgroundColor: Colors.green.shade700,
                                      foregroundColor: Colors.white,
                                    ),
                                  ),
                                  OutlinedButton.icon(
                                    onPressed: () => _review('FLAG'),
                                    icon: const Icon(Icons.flag_outlined),
                                    label: const Text('Flag Evidence'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.orange.shade900,
                                      side: BorderSide(color: Colors.orange.shade800),
                                    ),
                                  ),
                                  OutlinedButton.icon(
                                    onPressed: () => _review('RETURN'),
                                    icon: const Icon(Icons.assignment_return_outlined),
                                    label: const Text('Return for Review'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.deepOrange.shade900,
                                      side: BorderSide(color: Colors.deepOrange.shade800),
                                    ),
                                  ),
                                ];

                                if (isNarrow) {
                                  return Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      buttons[0],
                                      const SizedBox(height: 8),
                                      buttons[1],
                                      const SizedBox(height: 8),
                                      buttons[2],
                                    ],
                                  );
                                }

                                return Row(
                                  children: [
                                    Expanded(child: buttons[0]),
                                    const SizedBox(width: 8),
                                    Expanded(child: buttons[1]),
                                    const SizedBox(width: 8),
                                    Expanded(child: buttons[2]),
                                  ],
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ] else ...[
                    Card(
                      color: Colors.green.shade50,
                      child: const Padding(
                        padding: EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Icon(Icons.verified, color: Colors.green),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'This evidence record has been APPROVED by a supervisor and finalized for custody.',
                                style: TextStyle(color: Colors.green, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  Text('Audit History Trail', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  if (item.auditHistory.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('No previous audit events recorded.'),
                      ),
                    )
                  else
                    Card(
                      child: ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: item.auditHistory.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final event = item.auditHistory[index];
                          final eventType = event['event_type'] as String? ?? 'EVENT';
                          final createdAt = event['created_at'] as String? ?? '';
                          final eventData = event['event_data'] as Map<String, dynamic>?;
                          final eventReason = eventData?['reason'] as String?;

                          return ListTile(
                            dense: true,
                            leading: Icon(_auditIcon(eventType), size: 20),
                            title: Text(eventType, style: const TextStyle(fontWeight: FontWeight.w600)),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (createdAt.isNotEmpty) Text(createdAt),
                                if (eventReason != null && eventReason.isNotEmpty)
                                  Text(
                                    'Reason: $eventReason',
                                    style: const TextStyle(fontStyle: FontStyle.italic),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Color _statusColor(String status) {
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

  IconData _auditIcon(String eventType) {
    if (eventType.contains('REVIEW')) return Icons.rate_review_outlined;
    if (eventType.contains('CAPTURE')) return Icons.camera_alt_outlined;
    if (eventType.contains('FINAL')) return Icons.verified_outlined;
    return Icons.history;
  }
}

class _CardSection extends StatelessWidget {
  const _CardSection({required this.title, required this.items});
  final String title;
  final List<Widget> items;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            ...items,
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}