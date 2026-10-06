import '../../../core/network/api_exception.dart';
import '../domain/auth_session.dart';
import 'auth_api.dart';
import 'auth_token_store.dart';

/// Repository orchestrating authentication workflows, token persistence,
/// and session restoration.
class AuthRepository {
  AuthRepository({required this.api, required this.tokenStore});

  final AuthApi api;
  final AuthTokenStore tokenStore;

  /// Authenticates with the backend and persists the token in secure storage.
  ///
  /// If writing to secure storage fails, cleans up and throws to fail closed.
  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    final response = await api.login(email: email, password: password);

    try {
      await tokenStore.writeSession(
        token: response.token,
        expiresAt: response.expiresAt,
      );
    } catch (e) {
      await tokenStore.clearSession();
      throw StorageFailureException(
        'Failed to securely persist authentication session.',
      );
    }

    return AuthSession(
      user: response.user,
      token: response.token,
      expiresAt: response.expiresAt,
    );
  }

  /// Restores a previously saved session.
  ///
  /// - If no token or locally expired: clears storage and returns null.
  /// - Validates live token with `/auth/me` to obtain fresh roles/permissions.
  /// - If server returns 401 or 403: token/account is unusable, clears storage and returns null.
  /// - If network error: rethrows without wiping the potentially valid token.
  Future<AuthSession?> restoreSession() async {
    final token = await tokenStore.readToken();
    final expiresAt = await tokenStore.readExpiresAt();

    if (token == null || token.isEmpty || expiresAt == null) {
      return null;
    }

    // Check local expiration before making network call
    if (expiresAt.isBefore(DateTime.now().toUtc())) {
      await tokenStore.clearSession();
      return null;
    }

    try {
      final user = await api.getMe(token: token);
      return AuthSession(user: user, token: token, expiresAt: expiresAt);
    } on UnauthorizedException {
      // Token expired or revoked on server
      await tokenStore.clearSession();
      return null;
    } on ForbiddenException {
      // Account deactivated or role unassigned
      await tokenStore.clearSession();
      return null;
    }
  }

  /// Revokes the session token on the server and clears local storage.
  ///
  /// Preserves local token on network failure so user can retry revocation.
  Future<void> logout({required String token}) async {
    try {
      await api.logout(token: token);
      await tokenStore.clearSession();
    } on UnauthorizedException {
      // Token is already invalid on server; clean up local state
      await tokenStore.clearSession();
    } on ForbiddenException {
      // Account lacks permissions; clean up local state
      await tokenStore.clearSession();
    }
  }
}

/// Thrown when local secure storage write operation fails.
class StorageFailureException implements Exception {
  const StorageFailureException(this.message);
  final String message;

  @override
  String toString() => 'StorageFailureException: $message';
}
