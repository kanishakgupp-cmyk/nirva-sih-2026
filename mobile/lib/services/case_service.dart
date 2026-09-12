import '../models/case_model.dart';
import 'api_client.dart';

abstract interface class CaseService {
  Future<List<CaseModel>> getMyCases();

  Future<CaseModel?> getCaseById(String caseId);

  Future<void> createCase({
    required String caseNumber,
    required String title,
    String? description,
  });
}

class FastApiCaseService implements CaseService {
  FastApiCaseService({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  @override
  Future<List<CaseModel>> getMyCases() async {
    try {
      final response = await _apiClient.getList('/api/v1/cases');
      return response
          .map(
              (row) => CaseModel.fromMap(Map<String, dynamic>.from(row as Map)))
          .toList();
    } on ApiClientException catch (error) {
      throw CaseServiceException(
        error.message,
        category: error.category,
        statusCode: error.statusCode,
      );
    } catch (_) {
      throw const CaseServiceException(
        'Cases could not be loaded. Please check your connection and try again.',
      );
    }
  }

  @override
  Future<CaseModel?> getCaseById(String caseId) async {
    try {
      final response = await _apiClient.getObject('/api/v1/cases/$caseId');
      return CaseModel.fromMap(response);
    } on ApiClientException catch (error) {
      if (error.statusCode == 404) {
        return null;
      }
      throw CaseServiceException(
        error.message,
        category: error.category,
        statusCode: error.statusCode,
      );
    } catch (_) {
      throw const CaseServiceException(
        'The case could not be loaded. Please try again.',
      );
    }
  }

  @override
  Future<void> createCase({
    required String caseNumber,
    required String title,
    String? description,
  }) async {
    try {
      await _apiClient.post('/api/v1/cases', {
        'case_number': caseNumber.trim(),
        'title': title.trim(),
        'description':
            description?.trim().isEmpty ?? true ? null : description!.trim(),
      });
    } on ApiClientException catch (error) {
      if (error.statusCode == 409) {
        throw const CaseServiceException(
          'Case number already exists.',
          category: ApiErrorCategory.http409,
          statusCode: 409,
        );
      }
      throw CaseServiceException(
        error.message,
        category: error.category,
        statusCode: error.statusCode,
      );
    } catch (_) {
      throw const CaseServiceException(
        'The case could not be saved. Please try again.',
      );
    }
  }
}

class CaseServiceException implements Exception {
  const CaseServiceException(
    this.message, {
    this.category = ApiErrorCategory.unknownClientError,
    this.statusCode,
  });

  final String message;
  final ApiErrorCategory category;
  final int? statusCode;

  String get userMessage => '${category.label}: $message';

  @override
  String toString() => message;
}
