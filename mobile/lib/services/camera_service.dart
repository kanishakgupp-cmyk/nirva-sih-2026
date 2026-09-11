import 'dart:typed_data';

import 'package:camera/camera.dart';

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

  Future<void> initialize() async {
    await dispose();

    try {
      final cameras = await availableCameras().timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw const CameraServiceException(
          'Camera discovery timed out. Check camera permission and try again.',
        ),
      );
      if (cameras.isEmpty) {
        throw const CameraServiceException('No camera is available.');
      }

      final controller = CameraController(
        selectPreferredCamera(cameras),
        ResolutionPreset.medium,
        enableAudio: false,
      );
      try {
        await controller.initialize().timeout(
              const Duration(seconds: 15),
              onTimeout: () => throw const CameraServiceException(
                'Camera initialization timed out. Check camera permission and try again.',
              ),
            );
        _controller = controller;
      } catch (_) {
        await controller.dispose();
        rethrow;
      }
    } on CameraException catch (error) {
      throw CameraServiceException(
        'Camera initialization failed (${error.code}): '
        '${error.description ?? 'No further details were provided.'}',
      );
    } on CameraServiceException {
      rethrow;
    } catch (error) {
      throw CameraServiceException(
        'Camera initialization failed (${error.runtimeType}): $error',
      );
    }
  }

  Future<Uint8List> captureBytes() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      throw const CameraServiceException('Camera is not ready.');
    }
    final file = await controller.takePicture();
    return file.readAsBytes();
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
