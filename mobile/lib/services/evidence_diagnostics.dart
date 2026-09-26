import 'package:flutter/foundation.dart';

typedef EvidenceDiagnosticFailureCallback =
    void Function(EvidenceDiagnosticReport report);

class EvidenceDiagnosticReport {
  const EvidenceDiagnosticReport({
    required this.stage,
    required this.functionName,
    required this.error,
    required this.stackTrace,
    this.bytes,
    this.xFilePath,
    this.xFileName,
    this.mimeType,
    this.imageWidth,
    this.imageHeight,
  });

  final String stage;
  final String functionName;
  final Object error;
  final StackTrace stackTrace;
  final Uint8List? bytes;
  final String? xFilePath;
  final String? xFileName;
  final String? mimeType;
  final int? imageWidth;
  final int? imageHeight;

  String format({Uint8List? fallbackBytes}) {
    final diagnosticBytes = bytes ?? fallbackBytes;
    return [
      'DEBUG FAILURE:',
      'Stage: $stage',
      'Function: $functionName',
      'Exception type: ${error.runtimeType}',
      'Error: ${error.toString()}',
      if (diagnosticBytes != null) describeEvidenceBytes(diagnosticBytes),
      if (xFilePath != null) 'XFile.path: $xFilePath',
      if (xFileName != null) 'XFile.name: $xFileName',
      if (mimeType != null) 'MIME type: $mimeType',
      if (imageWidth != null && imageHeight != null)
        'Image dimensions: ${imageWidth}x$imageHeight',
      'Stack trace:',
      stackTrace.toString(),
    ].join('\n');
  }
}

String evidenceDiagnosticFunction(String stage) {
  return switch (stage) {
    'CAPTURE_TAKE_PICTURE' =>
      'CameraService.captureBytes -> CameraController.takePicture',
    'CAPTURE_READ_BYTES' =>
      'CameraService.captureBytes -> XFile.readAsBytes',
    'IMAGE_SIGNATURE' || 'IMAGE_DECODE' || 'IMAGE_QUALITY' =>
      'ImageQualityService.analyze',
    'LOCATION' => 'LocationService.captureLocation',
    'OPERATION_ID' || 'HASH' =>
      'OfflineFirstEvidenceService.createEvidenceRecord',
    'QUEUE_LOAD' || 'QUEUE_DESERIALIZATION' =>
      'OfflineEvidenceQueue.list',
    'QUEUE_ENQUEUE' || 'QUEUE_SERIALIZATION' || 'SHARED_PREFERENCES_SAVE' =>
      'OfflineEvidenceQueue.enqueue/_save',
    'MULTIPART_BUILD' => 'ApiClient.postMultipart',
    'HTTP_POST' => 'ApiClient.postMultipart -> MultipartRequest.send',
    'RESPONSE_PARSE' => 'ApiClient.postMultipart response parsing',
    'EVIDENCE_SAVE' => 'EvidenceCaptureScreen._saveEvidence',
    'ACCEPT_IMAGE' => 'EvidenceCaptureScreen._acceptImage',
    'CAPTURE' => 'EvidenceCaptureScreen._captureEvidence',
    'ONLINE_UPLOAD' || 'FASTAPI_UPLOAD' || 'FASTAPI_API_CLIENT' =>
      'FastApiEvidenceService.createEvidenceRecord',
    _ => stage,
  };
}

void logEvidenceStage(String stage, String event, [String? details]) {
  debugPrint('[${stage}_$event]${details == null ? '' : ' $details'}');
}

void reportEvidenceFailure(
  String stage,
  Object error,
  StackTrace stackTrace, {
  String? functionName,
  Uint8List? bytes,
  String? xFilePath,
  String? xFileName,
  String? mimeType,
  int? imageWidth,
  int? imageHeight,
  EvidenceDiagnosticFailureCallback? onDiagnosticFailure,
}) {
  final report = EvidenceDiagnosticReport(
    stage: stage,
    functionName: functionName ?? evidenceDiagnosticFunction(stage),
    error: error,
    stackTrace: stackTrace,
    bytes: bytes,
    xFilePath: xFilePath,
    xFileName: xFileName,
    mimeType: mimeType,
    imageWidth: imageWidth,
    imageHeight: imageHeight,
  );
  debugPrint('[${stage}_FAIL]\n${report.format()}');
  onDiagnosticFailure?.call(report);
}

String describeEvidenceBytes(Uint8List bytes) {
  final firstBytes = bytes.take(16).map((byte) =>
      byte.toRadixString(16).padLeft(2, '0').toUpperCase()).join(' ');
  final isJpeg = bytes.length >= 3 &&
      bytes[0] == 0xff &&
      bytes[1] == 0xd8 &&
      bytes[2] == 0xff;
  final isPng = bytes.length >= 8 &&
      bytes[0] == 0x89 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x4e &&
      bytes[3] == 0x47 &&
      bytes[4] == 0x0d &&
      bytes[5] == 0x0a &&
      bytes[6] == 0x1a &&
      bytes[7] == 0x0a;
  return 'Byte length: ${bytes.length}\n'
      'First 16 bytes (HEX): ${firstBytes.isEmpty ? '(empty)' : firstBytes}\n'
      'JPEG signature FF D8 FF: $isJpeg\n'
      'PNG signature 89 50 4E 47: $isPng';
}
