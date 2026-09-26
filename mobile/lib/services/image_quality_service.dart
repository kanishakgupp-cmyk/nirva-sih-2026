import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

import 'evidence_diagnostics.dart';

class ImageQualityResult {
  const ImageQualityResult({
    required this.width,
    required this.height,
    required this.brightnessScore,
    required this.sharpnessScore,
    required this.qualityScore,
    required this.requiresRetake,
  });

  final int width;
  final int height;
  final double brightnessScore;
  final double sharpnessScore;
  final double qualityScore;
  final bool requiresRetake;
}

class ImageQualityService {
  const ImageQualityService({this.minimumQualityScore = 70});

  final double minimumQualityScore;

  ImageQualityResult analyze(
    Uint8List bytes, {
    EvidenceDiagnosticFailureCallback? onDiagnosticFailure,
  }) {
    logEvidenceStage('IMAGE_DECODE', 'START', 'bytes=${bytes.length}');
    img.Image? decoded;
    try {
      if (_hasJpegSignature(bytes)) {
        decoded = img.JpegDecoder().decode(bytes);
      } else if (_hasPngSignature(bytes)) {
        decoded = img.PngDecoder().decode(bytes);
      } else {
        throw const FormatException('Unsupported or truncated image header.');
      }
    } catch (error, stackTrace) {
      reportEvidenceFailure(
        'IMAGE_DECODE',
        error,
        stackTrace,
        onDiagnosticFailure: onDiagnosticFailure,
      );
      throw const ImageQualityException('The image could not be read.');
    }
    if (decoded == null) {
      const error = FormatException('Image decoder returned null.');
      reportEvidenceFailure(
        'IMAGE_DECODE',
        error,
        StackTrace.current,
        onDiagnosticFailure: onDiagnosticFailure,
      );
      throw const ImageQualityException('The image could not be read.');
    }
    logEvidenceStage(
      'IMAGE_DECODE',
      'SUCCESS',
      '${decoded.width}x${decoded.height}',
    );

    var brightnessTotal = 0.0;
    var brightnessSquaredTotal = 0.0;
    var pixelCount = 0;
    for (final pixel in decoded) {
      final brightness = (pixel.r + pixel.g + pixel.b) / 3;
      brightnessTotal += brightness;
      brightnessSquaredTotal += brightness * brightness;
      pixelCount++;
    }

    final mean = pixelCount == 0 ? 0 : brightnessTotal / pixelCount;
    final variance = pixelCount == 0
        ? 0
        : (brightnessSquaredTotal / pixelCount) - (mean * mean);
    final brightnessScore = (100 - (mean - 128).abs() / 1.28).clamp(0, 100);
    final sharpnessScore = (variance / 5000 * 100).clamp(0, 100);
    final dimensionScore =
        ((decoded.width * decoded.height) / 300000).clamp(0, 100);
    final qualityScore =
        (brightnessScore * 0.4 + sharpnessScore * 0.4 + dimensionScore * 0.2)
            .clamp(0, 100);

    final result = ImageQualityResult(
      width: decoded.width,
      height: decoded.height,
      brightnessScore: brightnessScore.toDouble(),
      sharpnessScore: sharpnessScore.toDouble(),
      qualityScore: qualityScore.toDouble(),
      requiresRetake: qualityScore < minimumQualityScore,
    );
    logEvidenceStage(
      'IMAGE_QUALITY',
      'SUCCESS',
      'score=${result.qualityScore} requiresRetake=${result.requiresRetake}',
    );
    return result;
  }

  bool _hasJpegSignature(Uint8List bytes) =>
      bytes.length >= 3 &&
      bytes[0] == 0xff &&
      bytes[1] == 0xd8 &&
      bytes[2] == 0xff;

  bool _hasPngSignature(Uint8List bytes) =>
      bytes.length >= 8 &&
      bytes[0] == 0x89 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x4e &&
      bytes[3] == 0x47 &&
      bytes[4] == 0x0d &&
      bytes[5] == 0x0a &&
      bytes[6] == 0x1a &&
      bytes[7] == 0x0a;
}

class ImageQualityException implements Exception {
  const ImageQualityException(this.message);

  final String message;
}
