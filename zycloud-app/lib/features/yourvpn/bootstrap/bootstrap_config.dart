// lib/features/yourvpn/bootstrap/bootstrap_config.dart

/// Remote configuration fetched on app startup, allowing the API domain
/// and update prompts to be changed without shipping a new app build.
class BootstrapConfig {
  final String apiBaseUrl;
  final String latestVersion;
  final String minVersion;
  final String updateUrl;
  final bool forceUpdate;

  const BootstrapConfig({
    required this.apiBaseUrl,
    required this.latestVersion,
    required this.minVersion,
    required this.updateUrl,
    required this.forceUpdate,
  });

  factory BootstrapConfig.fromJson(Map<String, dynamic> json) {
    return BootstrapConfig(
      apiBaseUrl: json['api_base_url'] as String? ?? fallback.apiBaseUrl,
      latestVersion: json['latest_version'] as String? ?? fallback.latestVersion,
      minVersion: json['min_version'] as String? ?? fallback.minVersion,
      updateUrl: json['update_url'] as String? ?? fallback.updateUrl,
      forceUpdate: json['force_update'] as bool? ?? fallback.forceUpdate,
    );
  }

  Map<String, dynamic> toJson() => {
        'api_base_url': apiBaseUrl,
        'latest_version': latestVersion,
        'min_version': minVersion,
        'update_url': updateUrl,
        'force_update': forceUpdate,
      };

  /// Used when the bootstrap config can't be fetched and nothing is cached yet.
  static const fallback = BootstrapConfig(
    apiBaseUrl: String.fromEnvironment('API_BASE_URL', defaultValue: 'https://ziyoucloud.com'),
    latestVersion: '0.0.0',
    minVersion: '0.0.0',
    updateUrl: '',
    forceUpdate: false,
  );
}
