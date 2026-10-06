import 'package:flutter/foundation.dart';

import 'auth_user.dart';

/// Immutable representation of an active, authenticated client session.
///
/// Contains the authenticated [user], the Sanctum plain-text Bearer [token],
/// and the authoritative token expiration timestamp [expiresAt] in UTC.
@immutable
class AuthSession {
  const AuthSession({
    required this.user,
    required this.token,
    required this.expiresAt,
  });

  final AuthUser user;
  final String token;
  final DateTime expiresAt;

  /// Returns true if the token's authoritative expiration timestamp has passed.
  bool get isExpired => DateTime.now().toUtc().isAfter(expiresAt);

  /// Time remaining before token expiration.
  Duration get timeRemaining => expiresAt.difference(DateTime.now().toUtc());

  AuthSession copyWith({AuthUser? user, String? token, DateTime? expiresAt}) {
    return AuthSession(
      user: user ?? this.user,
      token: token ?? this.token,
      expiresAt: expiresAt ?? this.expiresAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AuthSession &&
          runtimeType == other.runtimeType &&
          user == other.user &&
          token == other.token &&
          expiresAt == other.expiresAt;

  @override
  int get hashCode => user.hashCode ^ token.hashCode ^ expiresAt.hashCode;

  /// Masks the sensitive Bearer token to protect against accidental logging.
  @override
  String toString() =>
      'AuthSession(user: ${user.name}, expiresAt: ${expiresAt.toIso8601String()}, token: [REDACTED])';
}
