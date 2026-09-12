import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

class ApiClient {
  ApiClient({
    String? baseUrl,
    SupabaseClient? supabaseClient,
    http.Client? httpClient,
  })  : _baseUrl = (baseUrl ?? const String.fromEnvironment('API_BASE_URL'))
            .trim()
            .replaceAll(RegExp(r'/+$'), ''),
        _supabaseClient = supabaseClient ?? Supabase.instance.client,
        _httpClient = httpClient ?? http.Client();

  final String _baseUrl;
  final SupabaseClient _supabaseClient;
  final http.Client _httpClient;

  Future<List<dynamic>> getList(String path) async {
    final response =
        await _send(() => _httpClient.get(buildUri(path), headers: _headers));
    return jsonDecode(response.body) as List<dynamic>;
  }

  Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body,
  ) async {
    final response = await _send(
      () => _httpClient.post(
        buildUri(path),
        headers: {..._headers, 'Content-Type': 'application/json'},
        body: jsonEncode(body),
      ),
    );
    return Map<String, dynamic>.from(jsonDecode(response.body) as Map);
  }

  Future<Map<String, dynamic>> getObject(String path) async {
    final response =
        await _send(() => _httpClient.get(buildUri(path), headers: _headers));
    return Map<String, dynamic>.from(jsonDecode(response.body) as Map);
  }

  Uri buildUri(String path) {
    if (_baseUrl.isEmpty) {
      throw const ApiClientException(
        'API_BASE_URL must be provided with --dart-define.',
      );
    }

    final normalizedPath = path.startsWith('/') ? path : '/$path';
    final baseUrl = _baseUrl.endsWith('/')
        ? _baseUrl.substring(0, _baseUrl.length - 1)
        : _baseUrl;
    return Uri.parse('$baseUrl$normalizedPath');
  }

  Map<String, String> get _headers {
    final token = _supabaseClient.auth.currentSession?.accessToken;
    if (token == null || token.isEmpty) {
      throw const ApiClientException('Please sign in before using the API.');
    }
    return {
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  Future<http.Response> _send(Future<http.Response> Function() request) async {
    try {
      final response = await request();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        String message = 'The server request failed. Please try again.';
        try {
          final body = jsonDecode(response.body) as Map;
          if (body['detail'] is String) {
            message = body['detail'] as String;
          }
        } catch (_) {
          // Keep the generic message for non-JSON error responses.
        }
        throw ApiClientException(message, statusCode: response.statusCode);
      }
      return response;
    } on ApiClientException {
      rethrow;
    } catch (_) {
      throw const ApiClientException(
        'The server could not be reached. Please try again.',
      );
    }
  }
}

class ApiClientException implements Exception {
  const ApiClientException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}
