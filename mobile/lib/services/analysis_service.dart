import '../models/evidence_record.dart';
import 'api_client.dart';

abstract interface class AnalysisService {
  Future<EvidenceRecord> validate(String evidenceId);

  Future<EvidenceRecord> analyze(String evidenceId);

  Future<EvidenceRecord> finalize(String evidenceId);

  Future<Map<String, dynamic>> integrity(String evidenceId);

  Future<List<Map<String, dynamic>>> audit(String evidenceId);
}

class FastApiAnalysisService implements AnalysisService {
  FastApiAnalysisService({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  @override
  Future<EvidenceRecord> validate(String evidenceId) =>
      _run('/validate', evidenceId);

  @override
  Future<EvidenceRecord> analyze(String evidenceId) =>
      _run('/analyze', evidenceId);

  @override
  Future<EvidenceRecord> finalize(String evidenceId) =>
      _run('/finalize', evidenceId);

  @override
  Future<Map<String, dynamic>> integrity(String evidenceId) =>
      _apiClient.getObject('/api/v1/evidence/$evidenceId/integrity');

  @override
  Future<List<Map<String, dynamic>>> audit(String evidenceId) async {
    final rows = await _apiClient.getList('/api/v1/evidence/$evidenceId/audit');
    return rows.map((row) => Map<String, dynamic>.from(row as Map)).toList();
  }

  Future<EvidenceRecord> _run(String action, String evidenceId) async {
    try {
      final response = await _apiClient.post(
        '/api/v1/evidence/$evidenceId$action',
        const {},
      );
      return EvidenceRecord.fromMap(response);
    } on ApiClientException catch (error) {
      throw AnalysisServiceException(error.message,
          statusCode: error.statusCode);
    } catch (_) {
      throw const AnalysisServiceException(
        'The evidence analysis request could not be completed.',
      );
    }
  }
}

class AnalysisServiceException implements Exception {
  const AnalysisServiceException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}
