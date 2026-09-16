import '../models/supervisor_models.dart';
import 'api_client.dart';

/// Server-side pagination page size used by the supervisor evidence queue.
const int supervisorEvidencePageSize = 50;

abstract interface class SupervisorService {
  Future<SupervisorOverview> getOverview();
  Future<List<SupervisorEvidenceSummary>> getEvidence({String? status, String? search});
  Future<SupervisorEvidenceDetail> getEvidenceDetail(String evidenceId);
  Future<SupervisorEvidenceDetail> review(String evidenceId, String action, {String? reason});
}

class FastApiSupervisorService implements SupervisorService {
  FastApiSupervisorService({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  @override
  Future<SupervisorOverview> getOverview() async => SupervisorOverview.fromMap(
        await _apiClient.getObject('/api/v1/supervisor/overview'),
      );

  @override
  Future<List<SupervisorEvidenceSummary>> getEvidence({String? status, String? search}) async {
    final query = <String, String>{
      'page': '1',
      'page_size': '$supervisorEvidencePageSize',
    };
    if (status != null && status != 'ALL') query['status'] = status;
    if (search != null && search.isNotEmpty) query['search'] = search;
    final path = Uri(path: '/api/v1/supervisor/evidence', queryParameters: query).toString();
    final response = await _apiClient.getObject(path);
    return (response['items'] as List<dynamic>? ?? [])
        .map((item) => SupervisorEvidenceSummary.fromMap(Map<String, dynamic>.from(item as Map)))
        .toList();
  }

  @override
  Future<SupervisorEvidenceDetail> getEvidenceDetail(String evidenceId) async =>
      SupervisorEvidenceDetail.fromMap(
        await _apiClient.getObject('/api/v1/supervisor/evidence/$evidenceId'),
      );

  @override
  Future<SupervisorEvidenceDetail> review(String evidenceId, String action, {String? reason}) async {
    final normalizedAction = action.trim().toUpperCase();
    final body = <String, dynamic>{'action': normalizedAction};
    if (reason != null && reason.trim().isNotEmpty) {
      body['reason'] = reason.trim();
    }
    return SupervisorEvidenceDetail.fromMap(
      await _apiClient.post(
        '/api/v1/supervisor/evidence/$evidenceId/$normalizedAction',
        body,
      ),
    );
  }
}