/// Enumeration of frozen staff roles in the Coffee Management System.
///
/// Role resolution is strict and fails closed: an unrecognized or unsupported
/// role string from the server throws a [FormatException] rather than defaulting
/// to a lower privilege role like cashier.
enum StaffRole {
  cashier('cashier', 'Cashier'),
  manager('manager', 'Manager'),
  admin('admin', 'Administrator');

  const StaffRole(this.value, this.label);

  final String value;
  final String label;

  /// Parses a backend role string strictly. Fails closed on unknown roles.
  static StaffRole fromString(String raw) {
    final normalized = raw.trim().toLowerCase();
    for (final role in StaffRole.values) {
      if (role.value == normalized) {
        return role;
      }
    }
    throw FormatException(
      'Unknown or unsupported staff role: "$raw". Access denied.',
    );
  }

  bool get isCashier => this == StaffRole.cashier;
  bool get isManager => this == StaffRole.manager;
  bool get isAdmin => this == StaffRole.admin;
}
