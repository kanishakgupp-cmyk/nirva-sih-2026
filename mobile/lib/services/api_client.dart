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

  String get safeEndpointDescription {
    final uri = Uri.tryParse(_baseUrl);
    if (uri == null || uri.scheme.isEmpty || uri.host.isEmpty) {
      return 'API endpoint is not configured';
    }
    final port = uri.hasPort ? ':${uri.port}' : '';
    final path = uri.path.isEmpty ? '/' : uri.path;
    return '${uri.scheme}://${uri.host}$port$path';
  }

  bool get hasAccessToken {
    final token =
        _accessToken ?? _supabaseClient.auth.currentSession?.accessToken;
    return token != null && token.isNotEmpty;
  }

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
      _log('GET ${_safeUri(uri)} invalid JSON response: ${error.runtimeType}');
      throw ApiClientException(
        'The server returned an invalid response (HTTP ${response.statusCode}).',
        statusCode: response.statusCode,
        category: ApiErrorCategory.invalidResponse,
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
      _log('POST ${_safeUri(uri)} invalid JSON response: ${error.runtimeType}');
      throw ApiClientException(
        'The server returned an invalid response (HTTP ${response.statusCode}).',
        statusCode: response.statusCode,
        category: ApiErrorCategory.invalidResponse,
      );
    }
  }

  Future<Map<String, dynamic>> postMultipart(
    String path, {
    required Map<String, String> fields,
    required Uint8List bytes,
    required String filename,
    required String contentType,
  }) async {
    final uri = buildUri(path);
    final response = await _send(
      method: 'POST',
      uri: uri,
      request: () async {
        final mediaParts = contentType.split('/');
        final request = http.MultipartRequest('POST', uri)
          ..headers.addAll(_headers)
          ..fields.addAll(fields)
          ..files.add(
            http.MultipartFile.fromBytes(
              'image',
              bytes,
              filename: filename,
              contentType: http.MediaType(
                mediaParts.first,
                mediaParts.length > 1 ? mediaParts[1] : 'octet-stream',
              ),
            ),
          );
        return http.Response.fromStream(await request.send());
      },
    );
    try {
      return Map<String, dynamic>.from(jsonDecode(response.body) as Map);
    } on Object catch (error) {
      _log('POST ${_safeUri(uri)} invalid JSON response: ${error.runtimeType}');
      throw ApiClientException(
        'The server returned an invalid response (HTTP ${response.statusCode}).',
        statusCode: response.statusCode,
        category: ApiErrorCategory.invalidResponse,
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
      _log('GET ${_safeUri(uri)} invalid JSON response: ${error.runtimeType}');
      throw ApiClientException(
        'The server returned an invalid response (HTTP ${response.statusCode}).',
        statusCode: response.statusCode,
        category: ApiErrorCategory.invalidResponse,
      );
    }
  }

  Uri buildUri(String path) {
    if (_baseUrl.isEmpty) {
      throw const ApiClientException(
        'API_BASE_URL must be provided with --dart-define.',
        category: ApiErrorCategory.unknownClientError,
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
      throw const ApiClientException(
        'Please sign in before using the API.',
        category: ApiErrorCategory.authSessionMissing,
      );
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
    _log('$method $safeUri tokenPresent=$hasAccessToken');
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
        throw ApiClientException(
          message,
          statusCode: response.statusCode,
          category: ApiErrorCategory.fromStatusCode(response.statusCode),
        );
      }
      return response;
    } on ApiClientException {
      rethrow;
    } on http.ClientException catch (error) {
      _log('$method $safeUri transport failure: ${error.runtimeType}');
      throw ApiClientException(
        'The server could not be reached. Please try again.',
        category: ApiErrorCategory.networkError,
        diagnostic: _diagnostic(
          method: method,
          uri: safeUri,
          exception: error,
        ),
      );
    } catch (error) {
      _log('$method $safeUri unexpected failure: ${error.runtimeType}');
      throw ApiClientException(
        'The request could not be completed (${error.runtimeType}).',
        category: ApiErrorCategory.unknownClientError,
        diagnostic: _diagnostic(
          method: method,
          uri: safeUri,
          exception: error,
        ),
      );
    }
  }

  String _diagnostic({
    required String method,
    required String uri,
    required Object exception,
  }) {
    if (!kDebugMode) {
      return '';
    }
    final detail = exception is http.ClientException
        ? exception.message
        : exception.toString();
    return 'url=$uri; method=$method; tokenPresent=$hasAccessToken; '
        'exception=${exception.runtimeType}; message=${_safeBody(detail)}';
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

  static String _safeUri(Uri uri) {
    final port = uri.hasPort ? ':${uri.port}' : '';
    return '${uri.scheme}://${uri.host}$port${uri.path}';
  }

  static void _log(String message) {
    if (kDebugMode) {
      debugPrint('[ApiClient] $message');
    }
  }
}

enum ApiErrorCategory {
  networkError('NETWORK_ERROR'),
  http401('HTTP_401'),
  http403('HTTP_403'),
  http404('HTTP_404'),
  http409('HTTP_409'),
  http422('HTTP_422'),
  http500('HTTP_500'),
  invalidResponse('INVALID_RESPONSE'),
  authSessionMissing('AUTH_SESSION_MISSING'),
  unknownClientError('UNKNOWN_CLIENT_ERROR');

  const ApiErrorCategory(this.label);

  final String label;

  static ApiErrorCategory fromStatusCode(int statusCode) {
    switch (statusCode) {
      case 401:
        return http401;
      case 403:
        return http403;
      case 404:
        return http404;
      case 409:
        return http409;
      case 422:
        return http422;
      case 500:
        return http500;
      default:
        return unknownClientError;
    }
  }
}

class ApiClientException implements Exception {
  const ApiClientException(
    this.message, {
    this.statusCode,
    this.category = ApiErrorCategory.unknownClientError,
    this.diagnostic = '',
  });

  final String message;
  final int? statusCode;
  final ApiErrorCategory category;
  final String diagnostic;

  String get userMessage => '${category.label}: $message';

  @override
  String toString() => message;
}
