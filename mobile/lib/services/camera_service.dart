import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';

import 'evidence_diagnostics.dart';

class CameraService {
  CameraController? _controller;

  CameraController? get controller => _controller;

  static CameraDescription selectPreferredCamera(
    List<CameraDescription> cameras,
  ) {
    return cameras.firstWhere(
      (camera) => camera.lensDirection == CameraLensDirection.back,
      orElse: () => cameras.first,
    );
  }

  Future<void> initialize({void Function(String stage)? onStage}) async {
    await dispose();

    try {
      onStage?.call('Checking cameras...');
      final cameras = await availableCameras().timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw const CameraServiceException(
          'Camera discovery timed out. Check camera permission and try again.',
        ),
      );
      if (cameras.isEmpty) {
        throw const CameraServiceException('No camera is available.');
      }

      final cameraSummary = cameras
          .map((camera) => '${camera.name} (${camera.lensDirection.name})')
          .join(', ');
      onStage?.call('Camera found: $cameraSummary');

      final selectedCamera = selectPreferredCamera(cameras);
      onStage?.call(
        'Creating camera controller for ${selectedCamera.name} '
        '(${selectedCamera.lensDirection.name})...',
      );
      final controller = CameraController(
        selectedCamera,
        ResolutionPreset.medium,
        enableAudio: false,
      );
      try {
        onStage?.call('Initializing camera...');
        await controller.initialize().timeout(
              const Duration(seconds: 15),
              onTimeout: () => throw const CameraServiceException(
                'Camera initialization timed out. Check camera permission and try again.',
              ),
            );
        _controller = controller;
        onStage?.call('Camera initialized');
      } catch (_) {
        await controller.dispose();
        rethrow;
      }
    } on CameraException catch (error) {
      throw CameraServiceException(
        'Camera initialization failed (${error.code}): '
        '${error.description ?? 'No further details were provided.'}'
        '${_webContextSuffix()}',
      );
    } on CameraServiceException {
      rethrow;
    } catch (error) {
      throw CameraServiceException(
        'Camera initialization failed (${error.runtimeType}): $error'
        '${_webContextSuffix()}',
      );
    }
  }

  String _webContextSuffix() {
    if (!kIsWeb) {
      return '';
    }
    final uri = Uri.base;
    final secureContext = uri.scheme == 'https' ||
        uri.host == 'localhost' ||
        uri.host == '127.0.0.1';
    return ' [Web URL: ${uri.scheme}://${uri.host}; '
        'secure-context-compatible: $secureContext]';
  }

  Future<Uint8List> captureBytes({
    EvidenceDiagnosticFailureCallback? onDiagnosticFailure,
  }) async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      throw const CameraServiceException('Camera is not ready.');
    }
    late final XFile file;
    logEvidenceStage('CAPTURE_TAKE_PICTURE', 'START',
        'function=CameraService.captureBytes');
    try {
      file = await controller.takePicture();
      logEvidenceStage(
        'CAPTURE_TAKE_PICTURE',
        'SUCCESS',
        'function=CameraService.captureBytes XFile.path=${file.path} '
            'XFile.name=${file.name} MIME=${file.mimeType}',
      );
    } catch (error, stackTrace) {
      reportEvidenceFailure(
        'CAPTURE_TAKE_PICTURE',
        error,
        stackTrace,
        functionName: 'CameraService.captureBytes -> CameraController.takePicture',
        onDiagnosticFailure: onDiagnosticFailure,
      );
      rethrow;
    }

    logEvidenceStage(
      'CAPTURE_READ_BYTES',
      'START',
      'function=CameraService.captureBytes XFile.path=${file.path} '
          'XFile.name=${file.name} MIME=${file.mimeType}',
    );
    try {
      final bytes = await file.readAsBytes();
      logEvidenceStage(
        'CAPTURE_READ_BYTES',
        'SUCCESS',
        'function=XFile.readAsBytes XFile.path=${file.path} '
            'XFile.name=${file.name} MIME=${file.mimeType}\n'
            '${describeEvidenceBytes(bytes)}',
      );
      return bytes;
    } catch (error, stackTrace) {
      reportEvidenceFailure(
        'CAPTURE_READ_BYTES',
        error,
        stackTrace,
        functionName: 'CameraService.captureBytes -> XFile.readAsBytes',
        xFilePath: file.path,
        xFileName: file.name,
        mimeType: file.mimeType,
        onDiagnosticFailure: onDiagnosticFailure,
      );
      rethrow;
    }
  }

  Future<void> dispose() async {
    await _controller?.dispose();
    _controller = null;
  }
}

class CameraServiceException implements Exception {
  const CameraServiceException(this.message);

  final String message;
}
