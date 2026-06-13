// lib/src/auth/auth_controller.dart
//
// Riverpod-based authentication controller.
//
// Hiddify already depends on flutter_riverpod — do NOT add it again.
// Verify against Hiddify source: lib/core/app_info/app_info_provider.dart
// and lib/features/profile/data/profile_data_source.dart to confirm the
// Riverpod version in use (Hiddify 2.x uses riverpod ^2.5 / hooks_riverpod).

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../api/models.dart';
import 'token_store.dart';

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthState {
  final AuthStatus status;
  final String? errorMessage;

  const AuthState({required this.status, this.errorMessage});

  const AuthState.unknown() : this(status: AuthStatus.unknown);
  const AuthState.authenticated() : this(status: AuthStatus.authenticated);
  const AuthState.unauthenticated({String? error})
      : this(status: AuthStatus.unauthenticated, errorMessage: error);

  bool get isAuthenticated => status == AuthStatus.authenticated;
}

// ---------------------------------------------------------------------------
// Providers
//
// Verify against Hiddify source: lib/core/preferences/general_preferences.dart
// to see how Hiddify exposes its own providers; wire apiClientProvider and
// tokenStoreProvider the same way so they share the Riverpod container.
// ---------------------------------------------------------------------------

/// Provide a configured [TokenStore].
final tokenStoreProvider = Provider<TokenStore>((ref) => TokenStore());

/// Provide a configured [ApiClient].
/// TODO: Replace 'https://your-backend.example.com' with the real base URL,
///       ideally from a compile-time --dart-define or a constants file.
final apiClientProvider = Provider<ApiClient>((ref) {
  final store = ref.watch(tokenStoreProvider);
  return ApiClient(
    baseUrl: const String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: 'https://ziyoucloud.com',
    ),
    tokenProvider: _TokenStoreAdapter(store),
  );
});

/// The main auth controller provider consumed by UI.
final authControllerProvider =
    StateNotifierProvider<AuthController, AuthState>((ref) {
  return AuthController(
    apiClient: ref.watch(apiClientProvider),
    tokenStore: ref.watch(tokenStoreProvider),
  );
});

// ---------------------------------------------------------------------------
// Adapter: TokenStore -> TokenProvider
// ---------------------------------------------------------------------------

class _TokenStoreAdapter implements TokenProvider {
  final TokenStore _store;
  _TokenStoreAdapter(this._store);

  @override
  Future<String?> get token => _store.readToken();
}

// ---------------------------------------------------------------------------
// Controller
// ---------------------------------------------------------------------------

class AuthController extends StateNotifier<AuthState> {
  final ApiClient _api;
  final TokenStore _tokenStore;

  AuthController({
    required ApiClient apiClient,
    required TokenStore tokenStore,
  })  : _api = apiClient,
        _tokenStore = tokenStore,
        super(const AuthState.unknown()) {
    _checkExistingSession();
  }

  /// Reads stored token on startup and sets initial state.
  Future<void> _checkExistingSession() async {
    final loggedIn = await _tokenStore.isLoggedIn;
    state = loggedIn
        ? const AuthState.authenticated()
        : const AuthState.unauthenticated();
  }

  /// Authenticates with email + password.
  /// On success, stores token and transitions to [AuthStatus.authenticated].
  Future<void> login(String email, String password) async {
    state = const AuthState.unknown(); // show loading in UI
    try {
      final AuthToken auth = await _api.login(email, password);
      await _tokenStore.save(auth.token, auth.expires);
      state = const AuthState.authenticated();
    } on ApiException catch (e) {
      state = AuthState.unauthenticated(error: e.message);
    } catch (e) {
      state = AuthState.unauthenticated(error: e.toString());
    }
  }

  /// Clears the stored token and marks the user as unauthenticated.
  Future<void> logout() async {
    await _tokenStore.delete();
    state = const AuthState.unauthenticated();
  }
}
