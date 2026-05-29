// lib/src/api/api_client.dart
//
// HTTP client for the YourVPN backend.
// Uses package:http (not dio) — add `http: ^1.2.1` to pubspec.yaml.
// See pubspec.additions.yaml for the full dependency snippet.

import 'dart:convert';
import 'package:http/http.dart' as http;

import 'models.dart';

/// Lightweight exception carrying the HTTP status and body message.
class ApiException implements Exception {
  final int statusCode;
  final String message;
  const ApiException(this.statusCode, this.message);

  @override
  String toString() => 'ApiException($statusCode): $message';
}

/// Provides the current bearer token.
/// Typically implemented by TokenStore (see auth/token_store.dart).
abstract class TokenProvider {
  Future<String?> get token;
}

class ApiClient {
  final String baseUrl;
  final TokenProvider tokenProvider;
  final http.Client _http;

  ApiClient({
    required this.baseUrl,
    required this.tokenProvider,
    http.Client? httpClient,
  }) : _http = httpClient ?? http.Client();

  // ---------------------------------------------------------------------------
  // Internal helpers
  // ---------------------------------------------------------------------------

  Future<Map<String, String>> _authHeaders() async {
    final t = await tokenProvider.token;
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (t != null) 'Authorization': 'Bearer $t',
    };
  }

  Map<String, dynamic> _decode(http.Response response) {
    final body = utf8.decode(response.bodyBytes);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      String msg = 'Request failed';
      try {
        final j = jsonDecode(body) as Map<String, dynamic>;
        msg = (j['message'] ?? j['error'] ?? msg).toString();
      } catch (_) {}
      throw ApiException(response.statusCode, msg);
    }
    return jsonDecode(body) as Map<String, dynamic>;
  }

  Uri _uri(String path) => Uri.parse('$baseUrl$path');

  // ---------------------------------------------------------------------------
  // Auth
  // ---------------------------------------------------------------------------

  /// POST /api/v1/login
  /// Returns [AuthToken] containing the bearer token and its expiry.
  Future<AuthToken> login(String email, String password) async {
    final response = await _http.post(
      _uri('/api/v1/login'),
      headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );
    final json = _decode(response);
    // Backend returns { "token": "...", "expires": "<ISO8601>" }
    return AuthToken.fromJson(json);
  }

  // ---------------------------------------------------------------------------
  // User
  // ---------------------------------------------------------------------------

  /// GET /api/v1/user
  /// Returns the authenticated user's account details.
  Future<UserAccount> getUser() async {
    final response = await _http.get(
      _uri('/api/v1/user'),
      headers: await _authHeaders(),
    );
    return UserAccount.fromJson(_decode(response));
  }

  // ---------------------------------------------------------------------------
  // Plans
  // ---------------------------------------------------------------------------

  /// GET /api/v1/plans
  /// Returns the list of available subscription plans.
  Future<List<Plan>> getPlans() async {
    final response = await _http.get(
      _uri('/api/v1/plans'),
      headers: await _authHeaders(),
    );
    final json = _decode(response);
    final list = json['data'] as List<dynamic>? ?? (json is List ? json : [json]);
    return list.map((e) => Plan.fromJson(e as Map<String, dynamic>)).toList();
  }

  // ---------------------------------------------------------------------------
  // Orders
  // ---------------------------------------------------------------------------

  /// POST /api/v1/order
  /// Creates an order for [planId] and returns a checkout URL.
  Future<Order> createOrder(int planId) async {
    final response = await _http.post(
      _uri('/api/v1/order'),
      headers: await _authHeaders(),
      body: jsonEncode({'plan_id': planId}),
    );
    return Order.fromJson(_decode(response));
  }

  // ---------------------------------------------------------------------------
  // Nodes
  // ---------------------------------------------------------------------------

  /// GET /api/v1/nodes
  /// Returns the VPN node list for the authenticated user.
  Future<List<VpnNode>> getNodes() async {
    final response = await _http.get(
      _uri('/api/v1/nodes'),
      headers: await _authHeaders(),
    );
    final json = _decode(response);
    final list = json['data'] as List<dynamic>? ?? (json is List ? json : [json]);
    return list.map((e) => VpnNode.fromJson(e as Map<String, dynamic>)).toList();
  }

  void dispose() => _http.close();
}
