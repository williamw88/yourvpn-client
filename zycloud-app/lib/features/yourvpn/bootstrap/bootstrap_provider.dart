// lib/features/yourvpn/bootstrap/bootstrap_provider.dart
import 'dart:convert';

import 'package:hiddify/core/preferences/preferences_provider.dart';
import 'package:hiddify/features/yourvpn/bootstrap/bootstrap_config.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:http/http.dart' as http;

/// Hosted on the yourvpn-client GitHub repo via jsdelivr so it can be edited
/// without an app release. Cached locally so the API base URL keeps working offline.
const _bootstrapUrl = 'https://cdn.jsdelivr.net/gh/williamw88/yourvpn-client@main/bootstrap.json';
const _cacheKey = 'yourvpn_bootstrap_config';

final bootstrapConfigProvider = FutureProvider<BootstrapConfig>((ref) async {
  final prefs = await ref.watch(sharedPreferencesProvider.future);

  BootstrapConfig? cached;
  final cachedJson = prefs.getString(_cacheKey);
  if (cachedJson != null) {
    try {
      cached = BootstrapConfig.fromJson(jsonDecode(cachedJson) as Map<String, dynamic>);
    } catch (_) {
      cached = null;
    }
  }

  try {
    final response = await http.get(Uri.parse(_bootstrapUrl)).timeout(const Duration(seconds: 3));
    if (response.statusCode == 200) {
      final config = BootstrapConfig.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
      await prefs.setString(_cacheKey, jsonEncode(config.toJson()));
      return config;
    }
  } catch (_) {
    // Network unavailable or CDN unreachable - fall back to cached/default below.
  }

  return cached ?? BootstrapConfig.fallback;
});
