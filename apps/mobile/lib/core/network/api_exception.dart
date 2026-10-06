import 'package:flutter/foundation.dart';

/// Base exception class for all HTTP network and API errors.
@immutable
abstract class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => '$runtimeType: $message (status: $statusCode)';
}

/// 401 Unauthorized: token missing, invalid, expired, revoked, or invalid credentials.
class UnauthorizedException extends ApiException {
  const UnauthorizedException([
    super.message =
        'The provided credentials are incorrect or session expired.',
  ]) : super(statusCode: 401);
}

/// 403 Forbidden: authenticated, but access is denied for this account or action.
class ForbiddenException extends ApiException {
  const ForbiddenException([
    super.message = 'Access denied. Account is inactive or lacks permission.',
  ]) : super(statusCode: 403);
}

/// 404 Not Found: the requested resource does not exist.
class NotFoundException extends ApiException {
  const NotFoundException([super.message = 'Requested resource not found.'])
    : super(statusCode: 404);
}

/// 409 Conflict: business rule violation or concurrency conflict.
class ConflictException extends ApiException {
  const ConflictException(super.message, {this.code, this.details})
    : super(statusCode: 409);

  final String? code;
  final Map<String, dynamic>? details;
}

/// 422 Unprocessable Content: request payload validation failure.
class ValidationException extends ApiException {
  const ValidationException(
    super.message, {
    this.errors = const <String, List<String>>{},
  }) : super(statusCode: 422);

  final Map<String, List<String>> errors;

  /// Returns the first error message for a given field, if present.
  String? firstErrorFor(String field) => errors[field]?.firstOrNull;
}

/// 429 Too Many Requests: endpoint rate limit exceeded.
class RateLimitedException extends ApiException {
  const RateLimitedException([
    super.message = 'Too many requests. Please try again shortly.',
    this.retryAfterSeconds,
  ]) : super(statusCode: 429);

  final int? retryAfterSeconds;
}

/// 5xx Server Error: unhandled server failure.
class ServerException extends ApiException {
  const ServerException([
    super.message = 'A server error occurred. Please try again later.',
    int statusCode = 500,
  ]) : super(statusCode: statusCode);
}

/// Network transport failure, timeout, or socket connection error.
class NetworkException extends ApiException {
  const NetworkException([
    super.message =
        'Network connection failure. Please check your internet connection.',
  ]) : super(statusCode: null);
}

/// Malformed JSON payload or missing expected schema fields.
class InvalidResponseException extends ApiException {
  const InvalidResponseException(super.message) : super(statusCode: null);
}
