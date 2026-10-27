/// Build-time configuration. The only value is where the future API lives; it comes from `--dart-define` and nowhere
/// else, so no address, secret or token is ever written into the source.
abstract final class AppConfig {
  /// The API's base address, for example `https://api.example.edu`. Empty when not configured.
  ///
  /// Set with `flutter run --dart-define=API_BASE_URL=https://...`.
  static const String apiBaseUrl = String.fromEnvironment('API_BASE_URL');
}
