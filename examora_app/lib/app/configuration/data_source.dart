import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Where the app's data comes from.
enum DataSource {
  /// This device. The only source the app uses today.
  local,

  /// The Examora HTTP API.
  api,
}

/// THE switch. Every repository provider reads this, so moving the whole app to the server is an edit to this one value
/// (or to the individual repository providers) - no screen, controller or model changes.
///
/// There is deliberately no "demo" source and no banner: the device is the one real source today.
final dataSourceProvider = Provider<DataSource>((ref) => DataSource.local);
