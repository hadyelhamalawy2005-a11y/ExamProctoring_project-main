import 'package:examora_app/app/configuration/app_config.dart';
import 'package:examora_app/core/network/api_client.dart';
import 'package:examora_app/core/network/api_tokens.dart';
import 'package:examora_app/core/security/password_hasher.dart';
import 'package:examora_app/core/storage/flutter_secure_store.dart';
import 'package:examora_app/core/storage/key_value_store.dart';
import 'package:examora_app/core/utilities/app_clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

/// Where local data lives. Overridden at start-up with the real `shared_preferences`; tests override it with memory.
final keyValueStoreProvider = Provider<KeyValueStore>(
  (ref) => throw UnimplementedError('keyValueStoreProvider must be overridden when the app starts.'),
);

/// Where session material lives. The platform keystore by default; tests override it with memory.
final secureStoreProvider = Provider<SecureStore>((ref) => const FlutterSecureStore());

/// The app's clock. Tests replace it with a fake.
final clockProvider = Provider<AppClock>((ref) => const SystemClock());

/// The password hasher. Tests replace it with a cheap one.
final passwordHasherProvider = Provider<PasswordHasher>((ref) => const PasswordHasher());

/// The HTTP client used by the API implementations.
final httpClientProvider = Provider<http.Client>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return client;
});

/// The API's token storage.
final apiTokenStoreProvider = Provider<ApiTokenStore>((ref) => ApiTokenStore(ref.watch(secureStoreProvider)));

/// The API client. Nothing calls it while the repositories use the device, but it is ready.
final apiClientProvider = Provider<ApiClient>(
  (ref) => ApiClient(
    httpClient: ref.watch(httpClientProvider),
    baseUrl: AppConfig.apiBaseUrl,
    tokens: ref.watch(apiTokenStoreProvider),
    clock: ref.watch(clockProvider),
  ),
);
