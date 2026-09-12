import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../models/case_model.dart';
import '../models/kit.dart';
import '../models/test_session.dart';
import '../services/camera_service.dart';
import '../services/demo_image_service.dart';
import '../services/evidence_service.dart';
import '../services/image_quality_service.dart';
import '../services/location_service.dart';
import 'evidence_success_screen.dart';

class EvidenceCaptureScreen extends StatefulWidget {
  const EvidenceCaptureScreen({
    required this.session,
    required this.caseItem,
    required this.kit,
    this.cameraService,
    this.evidenceService,
    this.locationService = const LocationService(),
    this.qualityService = const ImageQualityService(),
    this.demoImageService = const DemoImageService(),
    super.key,
  });

  final TestSession session;
  final CaseModel caseItem;
  final Kit kit;
  final CameraService? cameraService;
  final EvidenceService? evidenceService;
  final LocationService locationService;
  final ImageQualityService qualityService;
  final DemoImageService demoImageService;

  @override
  State<EvidenceCaptureScreen> createState() => _EvidenceCaptureScreenState();
}

class _EvidenceCaptureScreenState extends State<EvidenceCaptureScreen> {
  late final CameraService _cameraService;
  late final EvidenceService _evidenceService;
  CameraController? _cameraController;
  Uint8List? _imageBytes;
  ImageQualityResult? _quality;
  LocationResult? _location;
  DateTime? _capturedAt;
  String? _cameraMessage;
  String? _errorMessage;
  bool _cameraInitializationFailed = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _cameraService = widget.cameraService ?? CameraService();
    _evidenceService = widget.evidenceService ?? FastApiEvidenceService();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    if (mounted) {
      setState(() {
        _cameraMessage = 'Checking cameras...';
        _cameraInitializationFailed = false;
      });
    }
    try {
      await _cameraService.initialize(
        onStage: (stage) {
          if (mounted) {
            setState(() => _cameraMessage = stage);
          }
        },
      );
      if (mounted) {
        setState(() {
          _cameraController = _cameraService.controller;
          _cameraMessage = 'Camera initialized';
        });
      }
    } on CameraServiceException catch (error) {
      debugPrint('NIRVA camera initialization: ${error.message}');
      if (mounted) {
        setState(() {
          _cameraMessage = error.message;
          _cameraInitializationFailed = true;
        });
      }
    } catch (error, stackTrace) {
      debugPrint('NIRVA camera initialization: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (mounted) {
        setState(() {
          _cameraMessage =
              'Camera initialization failed (${error.runtimeType}): $error';
          _cameraInitializationFailed = true;
        });
      }
    }
  }

  @override
  void dispose() {
    _cameraService.dispose();
    super.dispose();
  }

  Future<void> _captureEvidence() async {
    try {
      final bytes = await _cameraService.captureBytes();
      await _acceptImage(bytes);
    } on CameraServiceException catch (error) {
      setState(() => _errorMessage = error.message);
    } catch (_) {
      setState(() => _errorMessage = 'The image could not be captured.');
    }
  }

  Future<void> _useDemoImage() async {
    await _acceptImage(widget.demoImageService.createDemoImage());
  }

  Future<void> _acceptImage(Uint8List bytes) async {
    try {
      final quality = widget.qualityService.analyze(bytes);
      if (quality.requiresRetake) {
        setState(() {
          _imageBytes = null;
          _quality = quality;
          _errorMessage =
              'Image quality is insufficient. Please capture another image.';
        });
        return;
      }

      final location = await widget.locationService.captureLocation();
      setState(() {
        _imageBytes = bytes;
        _quality = quality;
        _location = location;
        _capturedAt = DateTime.now().toUtc();
        _errorMessage = null;
      });
    } on ImageQualityException catch (error) {
      setState(() => _errorMessage = error.message);
    } catch (_) {
      setState(() => _errorMessage = 'The image could not be read.');
    }
  }

  Future<void> _saveEvidence() async {
    final bytes = _imageBytes;
    final quality = _quality;
    final capturedAt = _capturedAt;
    if (bytes == null || quality == null || capturedAt == null || _isSaving) {
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });
    try {
      final location = _location;
      final record = await _evidenceService.createEvidenceRecord(
        session: widget.session,
        imageBytes: bytes,
        capturedAt: capturedAt,
        latitude: location?.latitude,
        longitude: location?.longitude,
        gpsAccuracy: location?.accuracy,
        imageQualityScore: quality.qualityScore,
        sharpnessScore: quality.sharpnessScore,
        brightnessScore: quality.brightnessScore,
      );
      if (mounted) {
        await Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => EvidenceSuccessScreen(
              record: record,
              session: widget.session,
              caseItem: widget.caseItem,
            ),
          ),
        );
      }
    } on EvidenceServiceException catch (error) {
      if (mounted) setState(() => _errorMessage = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _errorMessage = 'Evidence could not be saved.');
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _retake() {
    setState(() {
      _imageBytes = null;
      _quality = null;
      _location = null;
      _capturedAt = null;
      _errorMessage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final imageBytes = _imageBytes;
    final quality = _quality;
    final location = _location;
    final hasPreview = imageBytes != null && quality != null;

    return Scaffold(
      appBar: AppBar(title: const Text('Evidence Capture')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _EvidenceHeader(),
                const SizedBox(height: 16),
                _SessionSummary(
                  session: widget.session,
                  caseItem: widget.caseItem,
                  kit: widget.kit,
                ),
                const SizedBox(height: 16),
                if (!hasPreview)
                  _CameraPanel(
                    controller: _cameraController,
                    cameraMessage: _cameraMessage,
                    initializationFailed: _cameraInitializationFailed,
                    onCapture: _captureEvidence,
                    onUseDemoImage: _useDemoImage,
                  )
                else ...[
                  Image.memory(imageBytes, fit: BoxFit.contain),
                  const SizedBox(height: 12),
                  Text(
                      'Image dimensions: ${quality.width} x ${quality.height}'),
                  Text('File size: ${imageBytes.length} bytes'),
                  const SizedBox(height: 12),
                  const Text('Image quality check'),
                  Text(
                      'Quality score: ${quality.qualityScore.toStringAsFixed(1)}'),
                  Text(
                    location?.available == true
                        ? 'Location: Available'
                        : 'Location unavailable. The record will note GPS as unavailable.',
                  ),
                  if (location?.available == true)
                    Text(
                        'Accuracy: ${location!.accuracy!.toStringAsFixed(1)} m'),
                  Text('Captured: ${_capturedAt?.toLocal()}'),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _isSaving ? null : _retake,
                          child: const Text('Retake'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: _isSaving ? null : _saveEvidence,
                          child: _isSaving
                              ? const CircularProgressIndicator()
                              : const Text('Use This Image'),
                        ),
                      ),
                    ],
                  ),
                ],
                if (_errorMessage != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    _errorMessage!,
                    key: const Key('evidence-error'),
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ],
                const SizedBox(height: 20),
                const Text(
                  'DEMONSTRATION EVIDENCE CAPTURE',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  'INDICATIVE ONLY - LABORATORY CONFIRMATION REQUIRED',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EvidenceHeader extends StatelessWidget {
  const _EvidenceHeader();

  @override
  Widget build(BuildContext context) {
    return Text(
      'NIRVA\nEvidence Capture',
      style: Theme.of(context).textTheme.headlineMedium,
    );
  }
}

class _SessionSummary extends StatelessWidget {
  const _SessionSummary(
      {required this.session, required this.caseItem, required this.kit});

  final TestSession session;
  final CaseModel caseItem;
  final Kit kit;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Test Number: ${session.testNumber}'),
            Text('Case: ${caseItem.caseNumber}'),
            Text('Kit: ${kit.kitCode}'),
            const Text('Status: READY FOR EVIDENCE CAPTURE'),
          ],
        ),
      ),
    );
  }
}

class _CameraPanel extends StatelessWidget {
  const _CameraPanel({
    required this.controller,
    required this.cameraMessage,
    required this.initializationFailed,
    required this.onCapture,
    required this.onUseDemoImage,
  });

  final CameraController? controller;
  final String? cameraMessage;
  final bool initializationFailed;
  final VoidCallback onCapture;
  final VoidCallback onUseDemoImage;

  @override
  Widget build(BuildContext context) {
    final cameraReady = controller?.value.isInitialized == true;
    return Column(
      children: [
        if (cameraReady)
          AspectRatio(
            aspectRatio: controller!.value.aspectRatio,
            child: CameraPreview(controller!),
          )
        else
          Container(
            height: 260,
            alignment: Alignment.center,
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Text(cameraMessage ?? 'Initializing camera...'),
          ),
        const SizedBox(height: 16),
        if (cameraReady)
          FilledButton.icon(
            onPressed: onCapture,
            icon: const Icon(Icons.camera_alt_outlined),
            label: const Text('Capture Evidence'),
          ),
        if (!cameraReady && initializationFailed) ...[
          const Text('DEMO ONLY'),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: onUseDemoImage,
            child: const Text('Use Demo Image'),
          ),
        ],
      ],
    );
  }
}
