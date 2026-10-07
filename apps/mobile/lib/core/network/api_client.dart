import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_exception.dart';

/// Lightweight HTTP client wrapper enforcing consistent JSON transport,
/// request timeouts, strict header handling, and mapping to ApiException types.
class ApiClient {
  ApiClient({
    required this.client,
    required String baseUrl,
    this.defaultTimeout = const Duration(seconds: 15),
  }) : _baseUrl = _normalizeBaseUrl(baseUrl);

  final http.Client client;
  final String _baseUrl;
  final Duration defaultTimeout;

  String get baseUrl => _baseUrl;

  static String _normalizeBaseUrl(String rawUrl) {
    final trimmed = rawUrl.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('Base URL cannot be empty.');
    }

    final uri = Uri.tryParse(trimmed);
    if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
      throw ArgumentError('Base URL is not a valid absolute URI: "$rawUrl"');
    }

    // Strip trailing slashes to avoid accidental double slashes
    return trimmed.replaceAll(RegExp(r'/+$'), '');
  }

  Uri _buildUri(String path, [Map<String, String>? queryParameters]) {
    final cleanPath = path.startsWith('/') ? path : '/$path';
    final uri = Uri.parse('$_baseUrl$cleanPath');
    return queryParameters == null
        ? uri
        : uri.replace(queryParameters: queryParameters);
  }

  Map<String, String> _buildHeaders({
    Map<String, String>? customHeaders,
    String? token,
    bool hasBody = false,
  }) {
    final headers = <String, String>{'Accept': 'application/json'};

    if (hasBody) {
      headers['Content-Type'] = 'application/json';
    }

    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }

    if (customHeaders != null) {
      headers.addAll(customHeaders);
    }

    return headers;
  }

  /// Sends a GET request and decodes the JSON response.
  Future<dynamic> get(
    String path, {
    Map<String, String>? queryParameters,
    Map<String, String>? headers,
    String? token,
    Duration? timeout,
  }) async {
    final uri = _buildUri(path, queryParameters);
    final requestHeaders = _buildHeaders(
      customHeaders: headers,
      token: token,
      hasBody: false,
    );

    try {
      final response = await client
          .get(uri, headers: requestHeaders)
          .timeout(timeout ?? defaultTimeout);

      return _handleResponse(response);
    } on TimeoutException {
      throw const NetworkException('Request timed out. Please try again.');
    } on http.ClientException catch (e) {
      throw NetworkException('Network transport error: ${e.message}');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw NetworkException('Connection error: $e');
    }
  }

  /// Sends a POST request with an optional JSON body and decodes the response.
  Future<dynamic> post(
    String path, {
    Object? body,
    Map<String, String>? headers,
    String? token,
    Duration? timeout,
  }) async {
    final uri = _buildUri(path);
    final hasBody = body != null;
    final requestHeaders = _buildHeaders(
      customHeaders: headers,
      token: token,
      hasBody: hasBody,
    );

    final encodedBody = hasBody ? jsonEncode(body) : null;

    try {
      final response = await client
          .post(uri, headers: requestHeaders, body: encodedBody)
          .timeout(timeout ?? defaultTimeout);

      return _handleResponse(response);
    } on TimeoutException {
      throw const NetworkException('Request timed out. Please try again.');
    } on http.ClientException catch (e) {
      throw NetworkException('Network transport error: ${e.message}');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw NetworkException('Connection error: $e');
    }
  }

  dynamic _handleResponse(http.Response response) {
    final statusCode = response.statusCode;

    // 204 No Content
    if (statusCode == 204 || response.body.isEmpty) {
      if (statusCode >= 200 && statusCode < 300) {
        return null;
      }
    }

    dynamic decodedJson;
    if (response.body.isNotEmpty) {
      try {
        decodedJson = jsonDecode(response.body);
      } on FormatException {
        if (statusCode >= 200 && statusCode < 300) {
          throw const InvalidResponseException(
            'Server returned non-JSON response.',
          );
        }
        decodedJson = null;
      }
    }

    if (statusCode >= 200 && statusCode < 300) {
      return decodedJson;
    }

    // Extract error message if present in JSON envelope
    String message = 'Request failed with status $statusCode';
    if (decodedJson is Map<String, dynamic> &&
        decodedJson['message'] is String) {
      message = decodedJson['message'] as String;
    }

    switch (statusCode) {
      case 401:
        throw UnauthorizedException(message);
      case 403:
        throw ForbiddenException(message);
      case 404:
        throw NotFoundException(message);
      case 409:
        String? code;
        Map<String, dynamic>? details;
        if (decodedJson is Map<String, dynamic>) {
          if (decodedJson['code'] is String) {
            code = decodedJson['code'] as String;
          }
          if (decodedJson['details'] is Map<String, dynamic>) {
            details = decodedJson['details'] as Map<String, dynamic>;
          }
        }
        throw ConflictException(message, code: code, details: details);
      case 422:
        final errors = <String, List<String>>{};
        if (decodedJson is Map<String, dynamic> &&
            decodedJson['errors'] is Map) {
          final rawErrors = decodedJson['errors'] as Map;
          for (final entry in rawErrors.entries) {
            final key = entry.key.toString();
            if (entry.value is List) {
              errors[key] = (entry.value as List)
                  .map((e) => e.toString())
                  .toList();
            } else if (entry.value != null) {
              errors[key] = [entry.value.toString()];
            }
          }
        }
        throw ValidationException(message, errors: errors);
      case 429:
        int? retryAfter;
        final headerVal = response.headers['retry-after'];
        if (headerVal != null) {
          retryAfter = int.tryParse(headerVal);
        }
        throw RateLimitedException(message, retryAfter);
      default:
        if (statusCode >= 500) {
          throw ServerException(message, statusCode);
        }
        throw ServerException(message, statusCode);
    }
  }
}
