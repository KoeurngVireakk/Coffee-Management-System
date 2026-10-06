import 'package:flutter/foundation.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/utils/device_info.dart';
import '../domain/auth_user.dart';

/// DTO representing the successful login response payload from Laravel Sanctum.
@immutable
class LoginResponseDto {
  const LoginResponseDto({
    required this.user,
    required this.token,
    required this.expiresAt,
  });

  final AuthUser user;
  final String token;
  final DateTime expiresAt;
}

/// Dedicated remote API boundary for Laravel Sanctum authentication endpoints.
class AuthApi {
  AuthApi({required this.client, String? deviceName})
    : _deviceName = deviceName ?? DeviceInfo.getDeviceName();

  final ApiClient client;
  final String _deviceName;

  /// Authenticates a staff user with email and password.
  ///
  /// Normalizes email to lowercase and trims whitespace, leaving password untouched.
  /// Sends exact fields (`email`, `password`, `device_name`) required by `LoginRequest`.
  Future<LoginResponseDto> login({
    required String email,
    required String password,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();

    final response = await client.post(
      '/auth/login',
      body: {
        'email': normalizedEmail,
        'password': password,
        'device_name': _deviceName,
      },
    );

    if (response is! Map<String, dynamic>) {
      throw const InvalidResponseException(
        'Login response did not return expected JSON object envelope.',
      );
    }

    final rawData = response['data'];
    if (rawData is! Map<String, dynamic>) {
      throw const InvalidResponseException(
        'Login response missing top-level "data" user object.',
      );
    }

    final user = AuthUser.fromJson(rawData);

    final rawToken = response['token'];
    if (rawToken is! String || rawToken.isEmpty) {
      throw const InvalidResponseException(
        'Login response missing valid "token" string.',
      );
    }

    final rawTokenType = response['token_type'];
    if (rawTokenType is! String || rawTokenType.toLowerCase() != 'bearer') {
      throw const InvalidResponseException(
        'Login response token_type must be "Bearer".',
      );
    }

    final rawExpiresAt = response['expires_at'];
    if (rawExpiresAt is! String) {
      throw const InvalidResponseException(
        'Login response missing "expires_at" timestamp string.',
      );
    }

    DateTime expiresAt;
    try {
      expiresAt = DateTime.parse(rawExpiresAt).toUtc();
    } catch (e) {
      throw FormatException('Invalid expires_at format in login response: $e');
    }

    return LoginResponseDto(user: user, token: rawToken, expiresAt: expiresAt);
  }

  /// Retrieves the currently authenticated staff user profile and permissions.
  Future<AuthUser> getMe({required String token}) async {
    final response = await client.get('/auth/me', token: token);

    if (response is! Map<String, dynamic>) {
      throw const InvalidResponseException(
        '/auth/me did not return expected JSON envelope.',
      );
    }

    final rawData = response['data'];
    if (rawData is! Map<String, dynamic>) {
      throw const InvalidResponseException(
        '/auth/me missing top-level "data" user object.',
      );
    }

    return AuthUser.fromJson(rawData);
  }

  /// Inactivates the current access token on the backend server.
  Future<void> logout({required String token}) async {
    await client.post('/auth/logout', token: token);
  }
}
