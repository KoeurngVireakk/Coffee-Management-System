import 'package:flutter/foundation.dart';

/// Semantic failure types representing user-facing authentication errors.
@immutable
sealed class AuthFailure {
  const AuthFailure(this.userMessage);

  final String userMessage;

  @override
  String toString() => '$runtimeType: $userMessage';
}

/// 401: Invalid credentials or inactive/unassigned staff.
/// Fails closed without disclosing email existence.
class InvalidCredentialsFailure extends AuthFailure {
  const InvalidCredentialsFailure([
    super.userMessage =
        'The provided credentials are incorrect, or this account cannot sign in.',
  ]);
}

/// 403: Authenticated, but account deactivation or unauthorized access was detected.
class InactiveStaffFailure extends AuthFailure {
  const InactiveStaffFailure([
    super.userMessage =
        'This staff account is inactive or access has been revoked.',
  ]);
}

/// 422: Form payload failed server validation.
class ValidationFailure extends AuthFailure {
  const ValidationFailure({
    String userMessage = 'Please correct the indicated errors.',
    this.errors = const <String, List<String>>{},
  }) : super(userMessage);

  final Map<String, List<String>> errors;

  String? firstErrorFor(String field) => errors[field]?.firstOrNull;
}

/// 429: Rate limit exceeded.
class RateLimitedFailure extends AuthFailure {
  const RateLimitedFailure({
    String userMessage = 'Too many sign-in attempts. Please try again shortly.',
    this.retryAfterSeconds,
  }) : super(userMessage);

  final int? retryAfterSeconds;
}

/// Network transport, socket, or timeout failure.
class NetworkFailure extends AuthFailure {
  const NetworkFailure([
    super.userMessage =
        'Unable to reach the server. Please verify your network connection.',
  ]);
}

/// 5xx server error.
class ServerFailure extends AuthFailure {
  const ServerFailure([
    super.userMessage =
        'A temporary service error occurred. Please try again later.',
  ]);
}

/// Session expired locally or revoked on the server.
class SessionExpiredFailure extends AuthFailure {
  const SessionExpiredFailure([
    super.userMessage = 'Your session has expired. Please sign in again.',
  ]);
}

/// OS-backed secure storage failure.
class StorageFailure extends AuthFailure {
  const StorageFailure([
    super.userMessage = 'Secure storage failure. Please sign in again.',
  ]);
}

/// Unhandled or unexpected error.
class UnknownFailure extends AuthFailure {
  const UnknownFailure([
    super.userMessage = 'An unexpected authentication error occurred.',
  ]);
}
