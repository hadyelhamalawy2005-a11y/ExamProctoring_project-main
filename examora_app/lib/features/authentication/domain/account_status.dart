/// Whether an account may sign in.
enum AccountStatus {
  /// May sign in.
  active('Active'),

  /// Deactivated by an administrator; cannot sign in until reactivated.
  deactivated('Deactivated');

  const AccountStatus(this.wireName);

  /// The name used on the wire, the same as the Examora API's `accountStatus`.
  final String wireName;

  /// The accepted wire names. Anything else is a parse error.
  static const Map<String, AccountStatus> byWireName = {
    'Active': AccountStatus.active,
    'Deactivated': AccountStatus.deactivated,
  };
}
