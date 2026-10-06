import 'package:flutter/foundation.dart';

import 'staff_role.dart';

/// Immutable representation of an authenticated staff user.
///
/// Serialized strictly from UserResource:
/// - `id`: unique user identifier
/// - `name`: full staff member name
/// - `email`: normalized email
/// - `role`: validated [StaffRole]
/// - `permissions`: authoritative server-provided ability list
@immutable
class AuthUser {
  const AuthUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.permissions,
  });

  final int id;
  final String name;
  final String email;
  final StaffRole role;
  final List<String> permissions;

  /// Checks if this staff user has been granted a specific permission by the server.
  bool hasPermission(String permission) => permissions.contains(permission);

  /// Deserializes from a UserResource JSON map.
  ///
  /// Ignores additive optional fields for backward/forward compatibility.
  factory AuthUser.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    if (id is! int) {
      throw const FormatException('AuthUser: missing or invalid "id".');
    }

    final name = json['name'];
    if (name is! String) {
      throw const FormatException('AuthUser: missing or invalid "name".');
    }

    final email = json['email'];
    if (email is! String) {
      throw const FormatException('AuthUser: missing or invalid "email".');
    }

    final rawRole = json['role'];
    if (rawRole is! String) {
      throw const FormatException('AuthUser: missing or invalid "role".');
    }
    final role = StaffRole.fromString(rawRole);

    final rawPermissions = json['permissions'];
    if (rawPermissions is! List) {
      throw const FormatException(
        'AuthUser: missing or invalid "permissions" list.',
      );
    }
    final permissions = rawPermissions
        .map((e) => e.toString())
        .toList(growable: false);

    return AuthUser(
      id: id,
      name: name,
      email: email,
      role: role,
      permissions: permissions,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'email': email,
    'role': role.value,
    'permissions': permissions,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AuthUser &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          email == other.email &&
          role == other.role &&
          listEquals(permissions, other.permissions);

  @override
  int get hashCode =>
      id.hashCode ^
      name.hashCode ^
      email.hashCode ^
      role.hashCode ^
      Object.hashAll(permissions);

  @override
  String toString() => 'AuthUser(id: $id, name: "$name", role: ${role.value})';
}
