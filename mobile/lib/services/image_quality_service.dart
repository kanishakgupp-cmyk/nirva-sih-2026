import 'dart:typed_data';

import 'package:image/image.dart' as img;

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

  ImageQualityResult analyze(Uint8List bytes) {
    img.Image? decoded;
    try {
      decoded = img.decodeImage(bytes);
    } catch (_) {
      throw const ImageQualityException('The image could not be read.');
    }
    if (decoded == null) {
      throw const ImageQualityException('The image could not be read.');
    }

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

    return ImageQualityResult(
      width: decoded.width,
      height: decoded.height,
      brightnessScore: brightnessScore.toDouble(),
      sharpnessScore: sharpnessScore.toDouble(),
      qualityScore: qualityScore.toDouble(),
      requiresRetake: qualityScore < minimumQualityScore,
    );
  }
}

class ImageQualityException implements Exception {
  const ImageQualityException(this.message);

  final String message;
}
