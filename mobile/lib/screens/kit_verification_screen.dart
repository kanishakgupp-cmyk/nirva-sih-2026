import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../models/case_model.dart';
import '../models/kit.dart';
import '../models/test_session.dart';
import '../services/kit_service.dart';
import '../services/test_session_service.dart';
import 'test_session_screen.dart';

class KitVerificationScreen extends StatefulWidget {
  const KitVerificationScreen({
    required this.session,
    required this.caseItem,
    this.kitService,
    this.testSessionService,
    super.key,
  });

  final TestSession session;
  final CaseModel caseItem;
  final KitService? kitService;
  final TestSessionService? testSessionService;

  @override
  State<KitVerificationScreen> createState() => _KitVerificationScreenState();
}

class _KitVerificationScreenState extends State<KitVerificationScreen> {
  late final KitService _kitService;
  late final TestSessionService _testSessionService;
  final _demoCodeController = TextEditingController();
  bool _isVerifying = false;
  bool _isContinuing = false;
  Kit? _verifiedKit;
  String? _failureReason;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _kitService = widget.kitService ?? SupabaseKitService();
    _testSessionService =
        widget.testSessionService ?? SupabaseTestSessionService();
  }

  @override
  void dispose() {
    _demoCodeController.dispose();
    super.dispose();
  }

  Future<void> _verifyCode(String rawCode) async {
    final kitCode = rawCode.trim();
    if (kitCode.isEmpty || _isVerifying || _isContinuing) {
      if (kitCode.isEmpty && mounted) {
        setState(() {
          _failureReason = 'Enter a demo kit code.';
          _errorMessage = null;
          _verifiedKit = null;
        });
      }
      return;
    }

    setState(() {
      _isVerifying = true;
      _failureReason = null;
      _errorMessage = null;
      _verifiedKit = null;
    });

    try {
      final kit = await _kitService.findKitByCode(kitCode);
      if (kit == null) {
        await _markInvalid('Kit not registered.');
        return;
      }

      final statusReason = _statusReason(kit);
      if (statusReason != null) {
        await _markInvalid(statusReason);
        return;
      }

      if (mounted) {
        setState(() => _verifiedKit = kit);
      }
    } on KitServiceException catch (error) {
      if (mounted) {
        setState(() => _errorMessage = error.message);
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Kit verification is unavailable. Please try again.';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isVerifying = false);
      }
    }
  }

  String? _statusReason(Kit kit) {
    switch (kit.status) {
      case 'ACTIVE':
        break;
      case 'INACTIVE':
        return 'Kit inactive.';
      case 'RECALLED':
        return 'Kit recalled.';
      default:
        return 'Kit verification failed.';
    }

    final expiryDate = kit.expiryDate;
    if (expiryDate != null) {
      final today = DateTime.now();
      final expiryDay =
          DateTime(expiryDate.year, expiryDate.month, expiryDate.day);
      final todayDay = DateTime(today.year, today.month, today.day);
      if (expiryDay.isBefore(todayDay)) {
        return 'Kit expired.';
      }
    }
    return null;
  }

  Future<void> _markInvalid(String reason) async {
    try {
      await _testSessionService.updateTestStatus(
        testId: widget.session.id,
        status: 'INVALID',
      );
    } on TestSessionServiceException catch (_) {
      // Keep the user-facing verification result useful if the status update fails.
    } catch (_) {
      // Keep backend details out of the UI.
    }
    if (mounted) {
      setState(() {
        _failureReason = reason;
        _verifiedKit = null;
      });
    }
  }

  Future<void> _continueWithKit() async {
    final kit = _verifiedKit;
    if (kit == null || _isContinuing) {
      return;
    }

    setState(() {
      _isContinuing = true;
      _errorMessage = null;
    });

    try {
      await _testSessionService.attachKitToSession(
        testId: widget.session.id,
        kitId: kit.id,
      );
      await _testSessionService.updateTestStatus(
        testId: widget.session.id,
        status: 'RUNNING',
      );
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => TestSessionScreen(
              session: widget.session,
              caseItem: widget.caseItem,
              kit: kit,
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
          _errorMessage = 'The kit could not be attached. Please try again.';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isContinuing = false);
      }
    }
  }

  void _handleScan(BarcodeCapture capture) {
    for (final barcode in capture.barcodes) {
      final rawValue = barcode.rawValue;
      if (rawValue != null && rawValue.trim().isNotEmpty) {
        _demoCodeController.text = rawValue.trim();
        _verifyCode(rawValue);
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final kit = _verifiedKit;
    return Scaffold(
      appBar: AppBar(title: const Text('Verify Kit')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Test Number: ${widget.session.testNumber}'),
                const SizedBox(height: 16),
                Text(
                  'Scan the kit QR code',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 220,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: MobileScanner(onDetect: _handleScan),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Demo kit code',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _demoCodeController,
                  enabled: !_isVerifying && !_isContinuing,
                  decoration: const InputDecoration(
                    hintText: 'Enter NIRVA-DEMO-001',
                    prefixIcon: Icon(Icons.qr_code_2),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _isVerifying || _isContinuing
                      ? null
                      : () => _verifyCode(_demoCodeController.text),
                  icon: _isVerifying
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.verified_outlined),
                  label:
                      Text(_isVerifying ? 'Verifying...' : 'Verify Kit Code'),
                ),
                if (_failureReason != null) ...[
                  const SizedBox(height: 20),
                  _FailureCard(
                    reason: _failureReason!,
                    onScanAgain: () => setState(() {
                      _failureReason = null;
                      _errorMessage = null;
                      _demoCodeController.clear();
                    }),
                  ),
                ],
                if (_errorMessage != null) ...[
                  const SizedBox(height: 20),
                  Text(
                    _errorMessage!,
                    key: const Key('kit-error'),
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ],
                if (kit != null) ...[
                  const SizedBox(height: 20),
                  _VerifiedKitCard(kit: kit, onContinue: _continueWithKit),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _VerifiedKitCard extends StatelessWidget {
  const _VerifiedKitCard({required this.kit, required this.onContinue});

  final Kit kit;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('KIT VERIFIED',
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 16),
            Text('Kit: ${kit.kitCode}'),
            Text('Batch: ${kit.batchNumber ?? 'Not provided'}'),
            Text('Expiry: ${_formatDate(kit.expiryDate)}'),
            Text('Status: ${kit.status}'),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: onContinue,
              child: const Text('Continue'),
            ),
          ],
        ),
      ),
    );
  }
}

class _FailureCard extends StatelessWidget {
  const _FailureCard({required this.reason, required this.onScanAgain});

  final String reason;
  final VoidCallback onScanAgain;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Kit verification failed',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(reason),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: onScanAgain,
              child: const Text('Scan Again'),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatDate(DateTime? date) {
  if (date == null) {
    return 'Not provided';
  }
  return '${date.year}-${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}
