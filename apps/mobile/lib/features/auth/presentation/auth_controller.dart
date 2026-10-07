import 'package:flutter/foundation.dart';

import '../../../core/network/api_exception.dart';
import '../data/auth_repository.dart';
import '../domain/auth_failure.dart';
import '../domain/auth_session.dart';
import '../domain/auth_user.dart';

/// Coherent immutable state union for authentication.
@immutable
sealed class AuthState {
  const AuthState();
}

/// App boot state while attempting to restore and verify a saved token.
class AuthInitializing extends AuthState {
  const AuthInitializing();
}

/// Unauthenticated state with an optional error/failure envelope.
class Unauthenticated extends AuthState {
  const Unauthenticated([this.failure]);
  final AuthFailure? failure;
}

/// Transient state while credentials are being validated by the server.
class Authenticating extends AuthState {
  const Authenticating();
}

/// Active authenticated session with validated user and live token.
class Authenticated extends AuthState {
  const Authenticated(this.session);
  final AuthSession session;
  AuthUser get user => session.user;
}

/// State when a stored token exists but network/timeout prevented verification.
///
/// Preserves the token without logging the user out immediately, allowing retry.
class SessionVerificationFailed extends AuthState {
  const SessionVerificationFailed({required this.message, this.logoutError});

  final String message;
  final String? logoutError;
}

/// State controller managing authentication lifecycle and UI notifications.
class AuthController extends ChangeNotifier {
  AuthController({required this.repository})
    : _state = const AuthInitializing();

  final AuthRepository repository;
  AuthState _state;
  Future<void>? _invalidSessionCleanup;

  AuthState get state => _state;
  bool get isAuthenticated => _state is Authenticated;
  bool get isAuthenticating => _state is Authenticating;
  bool get isInitializing => _state is AuthInitializing;

  /// Invalidates only the session that issued a protected request. A late 401
  /// from a previous staff session must never sign out a newly signed-in user.
  Future<void> invalidateSession({required String token}) async {
    final current = _state;
    if (current is! Authenticated || current.session.token != token) return;
    _invalidSessionCleanup = _clearInvalidSession();
    _setState(const Unauthenticated(SessionExpiredFailure()));
    await _invalidSessionCleanup;
  }

  Future<void> _clearInvalidSession() async {
    try {
      await repository.clearInvalidSession();
    } catch (_) {
      // Authentication stays closed even if OS storage cleanup fails.
    }
  }

  void _setState(AuthState newState) {
    if (_state == newState) return;
    _state = newState;
    notifyListeners();
  }

  /// Restores session on app startup.
  Future<void> restoreSession() async {
    _setState(const AuthInitializing());

    try {
      final session = await repository.restoreSession();
      if (session != null) {
        _setState(Authenticated(session));
      } else {
        _setState(const Unauthenticated());
      }
    } on NetworkException catch (e) {
      _setState(SessionVerificationFailed(message: e.message));
    } catch (e) {
      _setState(Unauthenticated(UnknownFailure(e.toString())));
    }
  }

  /// Submits credentials for authentication.
  Future<bool> login(String email, String password) async {
    if (isAuthenticating) return false;

    _setState(const Authenticating());

    try {
      // Delete old credentials before storing a newly authenticated session.
      await _invalidSessionCleanup;
      final session = await repository.login(email: email, password: password);
      _setState(Authenticated(session));
      return true;
    } on UnauthorizedException {
      _setState(const Unauthenticated(InvalidCredentialsFailure()));
      return false;
    } on ForbiddenException {
      _setState(const Unauthenticated(InactiveStaffFailure()));
      return false;
    } on ValidationException catch (e) {
      _setState(
        Unauthenticated(
          ValidationFailure(userMessage: e.message, errors: e.errors),
        ),
      );
      return false;
    } on RateLimitedException catch (e) {
      _setState(
        Unauthenticated(
          RateLimitedFailure(
            userMessage: e.message,
            retryAfterSeconds: e.retryAfterSeconds,
          ),
        ),
      );
      return false;
    } on NetworkException catch (e) {
      _setState(Unauthenticated(NetworkFailure(e.message)));
      return false;
    } on ServerException catch (e) {
      _setState(Unauthenticated(ServerFailure(e.message)));
      return false;
    } on StorageFailureException catch (e) {
      _setState(Unauthenticated(StorageFailure(e.message)));
      return false;
    } catch (e) {
      _setState(Unauthenticated(UnknownFailure(e.toString())));
      return false;
    }
  }

  /// Logs out of the current session on server and cleans local credentials.
  ///
  /// Preserves session if server revocation fails due to network, reporting failure.
  Future<bool> logout() async {
    final currentState = _state;
    if (currentState is! Authenticated) {
      _setState(const Unauthenticated());
      return true;
    }

    try {
      await repository.logout(token: currentState.session.token);
      _setState(const Unauthenticated());
      return true;
    } on NetworkException catch (e) {
      // Keep session intact so token revocation can be retried
      notifyListeners();
      throw NetworkException(
        'Could not revoke session on server: ${e.message}. Please retry sign out.',
      );
    } catch (e) {
      _setState(const Unauthenticated());
      return true;
    }
  }

  /// Clears any transient failure message.
  void clearError() {
    if (_state is Unauthenticated &&
        (_state as Unauthenticated).failure != null) {
      _setState(const Unauthenticated());
    }
  }
}
