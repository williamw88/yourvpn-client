// lib/features/yourvpn/auth/auth_controller.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hiddify/features/yourvpn/bootstrap/bootstrap_config.dart';
import 'package:hiddify/features/yourvpn/bootstrap/bootstrap_provider.dart';

import '../api/api_client.dart';
import '../api/models.dart';
import 'token_store.dart';

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

final tokenStoreProvider = Provider<TokenStore>((ref) => TokenStore());

final apiClientProvider = Provider<ApiClient>((ref) {
  final store = ref.watch(tokenStoreProvider);
  final bootstrap = ref.watch(bootstrapConfigProvider).valueOrNull;
  return ApiClient(
    baseUrl: bootstrap?.apiBaseUrl ?? BootstrapConfig.fallback.apiBaseUrl,
    tokenProvider: _TokenStoreAdapter(store),
  );
});

final authControllerProvider = StateNotifierProvider<AuthController, AuthState>((ref) {
  return AuthController(
    apiClient: ref.watch(apiClientProvider),
    tokenStore: ref.watch(tokenStoreProvider),
  );
});

class _TokenStoreAdapter implements TokenProvider {
  final TokenStore _store;
  _TokenStoreAdapter(this._store);

  @override
  Future<String?> get token => _store.readToken();
}

class AuthController extends StateNotifier<AuthState> {
  final ApiClient _api;
  final TokenStore _tokenStore;

  AuthController({required ApiClient apiClient, required TokenStore tokenStore})
      : _api = apiClient,
        _tokenStore = tokenStore,
        super(const AuthState.unknown()) {
    _checkExistingSession();
  }

  Future<void> _checkExistingSession() async {
    final loggedIn = await _tokenStore.isLoggedIn;
    state = loggedIn ? const AuthState.authenticated() : const AuthState.unauthenticated();
  }

  Future<void> login(String email, String password) async {
    state = const AuthState.unknown();
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

  Future<void> logout() async {
    await _tokenStore.delete();
    state = const AuthState.unauthenticated();
  }
}
