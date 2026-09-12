import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/case_model.dart';
import '../models/evidence_record.dart';
import '../models/test_session.dart';
import '../services/analysis_service.dart';

class AnalysisScreen extends StatefulWidget {
  const AnalysisScreen({
    required this.record,
    required this.session,
    required this.caseItem,
    this.analysisService,
    super.key,
  });

  final EvidenceRecord record;
  final TestSession session;
  final CaseModel caseItem;
  final AnalysisService? analysisService;

  @override
  State<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends State<AnalysisScreen> {
  late final AnalysisService _service;
  late EvidenceRecord _record;
  Map<String, dynamic>? _integrity;
  List<Map<String, dynamic>> _audit = const [];
  String? _errorMessage;
  String _progress = 'Evidence captured';
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _service = widget.analysisService ?? FastApiAnalysisService();
    _record = widget.record;
  }

  Future<void> _analyze() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _errorMessage = null;
      _progress = 'Validating image and reference card...';
    });
    try {
      _record = await _service.validate(_record.id);
      setState(() => _progress = 'Analyzing indicative visual features...');
      _record = await _service.analyze(_record.id);
      await _refreshIntegrity();
      if (mounted) setState(() => _progress = 'Indicative analysis complete');
    } on AnalysisServiceException catch (error) {
      if (mounted) setState(() => _errorMessage = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _finalize() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _errorMessage = null;
      _progress = 'Securing evidence and linking hash chain...';
    });
    try {
      _record = await _service.finalize(_record.id);
      await _refreshIntegrity();
      if (mounted) setState(() => _progress = 'Evidence finalized');
    } on AnalysisServiceException catch (error) {
      if (mounted) setState(() => _errorMessage = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _refreshIntegrity() async {
    _integrity = await _service.integrity(_record.id);
    _audit = await _service.audit(_record.id);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hash = _record.imageSha256 ?? 'Unavailable';
    final confidence = _record.analysisConfidence;
    final uncertainty = _record.analysisUncertainty;
    return Scaffold(
      appBar: AppBar(title: const Text('Evidence Details')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 860),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _DemoBanner(theme: theme),
                const SizedBox(height: 16),
                _Section(
                  title: 'Evidence identity',
                  icon: Icons.fingerprint,
                  children: [
                    _DetailRow('Evidence ID', _record.id),
                    _DetailRow('Test number', widget.session.testNumber),
                    _DetailRow('Case number', widget.caseItem.caseNumber),
                    _DetailRow(
                        'Captured',
                        _record.capturedAt?.toLocal().toString() ??
                            'Unavailable'),
                    _StatusChip(status: _record.evidenceStatus),
                  ],
                ),
                const SizedBox(height: 12),
                _Section(
                  title: 'Capture integrity',
                  icon: Icons.verified_outlined,
                  children: [
                    Row(
                      children: [
                        Expanded(
                            child: _DetailRow('SHA-256', _shortHash(hash))),
                        if (_record.imageSha256 != null)
                          IconButton(
                            tooltip: 'Copy full SHA-256',
                            onPressed: () => Clipboard.setData(
                              ClipboardData(text: _record.imageSha256!),
                            ),
                            icon: const Icon(Icons.copy_outlined),
                          ),
                      ],
                    ),
                    _DetailRow(
                      'Hash chain',
                      _integrity?['status'] as String? ?? 'Not checked',
                    ),
                    _DetailRow(
                      'Signature',
                      _record.signature == null
                          ? 'SIGNATURE MODE: DEMONSTRATION'
                          : (_record.signatureAlgorithm ?? 'Present'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _Section(
                  title: 'Location',
                  icon: Icons.location_on_outlined,
                  children: [
                    _DetailRow('Latitude', _number(_record.latitude)),
                    _DetailRow('Longitude', _number(_record.longitude)),
                    _DetailRow(
                        'Accuracy',
                        _record.gpsAccuracy == null
                            ? 'GPS unavailable'
                            : '${_record.gpsAccuracy!.toStringAsFixed(1)} m'),
                  ],
                ),
                const SizedBox(height: 12),
                _Section(
                  title: 'Reference validation',
                  icon: Icons.crop_free,
                  children: [
                    _DetailRow('Reference card',
                        _record.referenceCardStatus ?? 'Not validated'),
                    _DetailRow('Calibration',
                        _record.calibrationStatus ?? 'Not validated'),
                    _DetailRow(
                        'Calibration error', _number(_record.calibrationError)),
                    _DetailRow(
                        'Image quality', _number(_record.imageQualityScore)),
                    _DetailRow(
                        'Dimensions', 'Captured image metadata retained'),
                  ],
                ),
                const SizedBox(height: 12),
                _Section(
                  title: 'Indicative analysis',
                  icon: Icons.auto_awesome_outlined,
                  children: [
                    _DetailRow(
                        'Result', _record.analysisResult ?? 'Not analyzed'),
                    if (confidence != null) ...[
                      const SizedBox(height: 8),
                      Text('Confidence ${(confidence * 100).round()}%'),
                      const SizedBox(height: 5),
                      LinearProgressIndicator(value: confidence),
                    ],
                    _DetailRow(
                        'Uncertainty',
                        uncertainty == null
                            ? 'Unavailable'
                            : '±${(uncertainty * 100).round()}%'),
                    _DetailRow('Model version',
                        _record.analysisModelVersion ?? 'Not analyzed'),
                    const SizedBox(height: 8),
                    const Text('WHY THIS RESULT?',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const Text(
                        'Reference card detected. Image quality and lighting are acceptable. Generic features are stable.'),
                    const SizedBox(height: 8),
                    Text(
                      'INDICATIVE DEMONSTRATION RESULT\nLABORATORY CONFIRMATION REQUIRED',
                      style: TextStyle(
                          color: theme.colorScheme.error,
                          fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _Section(
                  title: 'Audit timeline',
                  icon: Icons.timeline,
                  children: _audit.isEmpty
                      ? const [
                          Text('Audit events will appear after validation.')
                        ]
                      : _audit
                          .map((event) => _DetailRow(
                                event['event_type'] as String? ?? 'Event',
                                event['created_at'] as String? ?? '',
                              ))
                          .toList(),
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 16),
                  Text(_errorMessage!,
                      key: const Key('analysis-error'),
                      style: TextStyle(color: theme.colorScheme.error)),
                ],
                const SizedBox(height: 16),
                Text(_progress, textAlign: TextAlign.center),
                const SizedBox(height: 10),
                FilledButton.icon(
                  onPressed: _busy || _record.evidenceStatus == 'FINALIZED'
                      ? null
                      : _analyze,
                  icon: const Icon(Icons.analytics_outlined),
                  label: Text(_busy ? 'Processing...' : 'Validate and Analyze'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _busy || _record.evidenceStatus != 'ANALYZED'
                      ? null
                      : _finalize,
                  icon: const Icon(Icons.lock_outline),
                  label: const Text('Finalize Evidence'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _shortHash(String value) => value.length > 16
      ? '${value.substring(0, 8)}...${value.substring(value.length - 8)}'
      : value;

  String _number(double? value) =>
      value == null ? 'Unavailable' : value.toStringAsFixed(3);
}

class _DemoBanner extends StatelessWidget {
  const _DemoBanner({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) => Card(
        color: theme.colorScheme.tertiaryContainer,
        child: const Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'NIRVA DEMONSTRATION MODE\nINDICATIVE VISUAL ANALYSIS\nLABORATORY CONFIRMATION REQUIRED',
            textAlign: TextAlign.center,
          ),
        ),
      );
}

class _Section extends StatelessWidget {
  const _Section(
      {required this.title, required this.icon, required this.children});

  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [
                Icon(icon),
                const SizedBox(width: 8),
                Text(title, style: Theme.of(context).textTheme.titleMedium)
              ]),
              const Divider(height: 24),
              ...children,
            ],
          ),
        ),
      );
}

class _DetailRow extends StatelessWidget {
  const _DetailRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
                width: 145,
                child:
                    Text(label, style: Theme.of(context).textTheme.bodySmall)),
            Expanded(child: Text(value)),
          ],
        ),
      );
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.centerLeft,
        child: Chip(label: Text(status)),
      );
}
