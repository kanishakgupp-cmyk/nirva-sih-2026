import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

class ApiClient {
  ApiClient({
    String? baseUrl,
    SupabaseClient? supabaseClient,
    http.Client? httpClient,
    @visibleForTesting String? accessToken,
  })  : _baseUrl = (baseUrl ?? const String.fromEnvironment('API_BASE_URL'))
            .trim()
            .replaceAll(RegExp(r'/+$'), ''),
        _supabaseClient = supabaseClient ?? Supabase.instance.client,
        _httpClient = httpClient ?? http.Client(),
        _accessToken = accessToken;

  final String _baseUrl;
  final SupabaseClient _supabaseClient;
  final http.Client _httpClient;
  final String? _accessToken;

  Future<List<dynamic>> getList(String path) async {
    final uri = buildUri(path);
    final response = await _send(
      method: 'GET',
      uri: uri,
      request: () => _httpClient.get(uri, headers: _headers),
    );
    try {
      return jsonDecode(response.body) as List<dynamic>;
    } on Object catch (error) {
      _log('GET $uri invalid JSON response: ${error.runtimeType}');
      throw ApiClientException(
        'The server returned an invalid response (HTTP ${response.statusCode}).',
        statusCode: response.statusCode,
      );
    }
  }

  Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body,
  ) async {
    final uri = buildUri(path);
    final response = await _send(
      method: 'POST',
      uri: uri,
      request: () => _httpClient.post(
        uri,
        headers: {..._headers, 'Content-Type': 'application/json'},
        body: jsonEncode(body),
      ),
    );
    try {
      return Map<String, dynamic>.from(jsonDecode(response.body) as Map);
    } on Object catch (error) {
      _log('POST $uri invalid JSON response: ${error.runtimeType}');
      throw ApiClientException(
        'The server returned an invalid response (HTTP ${response.statusCode}).',
        statusCode: response.statusCode,
      );
    }
  }

  Future<Map<String, dynamic>> getObject(String path) async {
    final uri = buildUri(path);
    final response = await _send(
      method: 'GET',
      uri: uri,
      request: () => _httpClient.get(uri, headers: _headers),
    );
    try {
      return Map<String, dynamic>.from(jsonDecode(response.body) as Map);
    } on Object catch (error) {
      _log('GET $uri invalid JSON response: ${error.runtimeType}');
      throw ApiClientException(
        'The server returned an invalid response (HTTP ${response.statusCode}).',
        statusCode: response.statusCode,
      );
    }
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
    final token =
        _accessToken ?? _supabaseClient.auth.currentSession?.accessToken;
    if (token == null || token.isEmpty) {
      throw const ApiClientException('Please sign in before using the API.');
    }
    return {
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  Future<http.Response> _send({
    required String method,
    required Uri uri,
    required Future<http.Response> Function() request,
  }) async {
    final safeUri = _safeUri(uri);
    _log('$method $safeUri');
    try {
      final response = await request();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        _log(
          '$method $safeUri -> ${response.statusCode}: '
          '${_safeBody(response.body)}',
        );
      } else {
        _log('$method $safeUri -> ${response.statusCode}');
      }
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
    } on http.ClientException catch (error) {
      _log('$method $safeUri transport failure: ${error.runtimeType}');
      throw const ApiClientException(
        'The server could not be reached. Please try again.',
      );
    } catch (error) {
      _log('$method $safeUri unexpected failure: ${error.runtimeType}');
      throw ApiClientException(
        'The request could not be completed (${error.runtimeType}).',
      );
    }
  }

  static String _safeBody(String body) {
    final redacted = body.replaceAll(
      RegExp(r'Bearer\s+[A-Za-z0-9._~-]+', caseSensitive: false),
      'Bearer [redacted]',
    );
    return redacted.length <= 500
        ? redacted
        : '${redacted.substring(0, 500)}...';
  }

  static String _safeUri(Uri uri) => '${uri.scheme}://${uri.host}${uri.path}';

  static void _log(String message) {
    if (kDebugMode) {
      debugPrint('[ApiClient] $message');
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
