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
    final cameras = await availableCameras();
    if (cameras.isEmpty) {
      throw const CameraServiceException('No camera is available.');
    }

    final controller = CameraController(
      selectPreferredCamera(cameras),
      ResolutionPreset.medium,
      enableAudio: false,
    );
    await controller.initialize();
    _controller = controller;
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
