# Branded VPN Client on Hiddify Fork — Android Integration Guide

## 1. Licensing Reality Check

Hiddify is released under **GPLv3 with additional Section 7 restrictions**. The key obligations: your fork must remain publicly hosted on GitHub, must visibly credit Hiddify, and may not use the Hiddify name, logo, or original store assets in your published app. Because GPLv3 is copyleft, your entire Flutter application layer is also GPLv3 if it links against Hiddify code. **Get legal counsel before publishing commercially.** The only clean-room escape hatch is to build a new Flutter app that links only `libbox` (the compiled Go core artifact from hiddify-core) as a library without forking the Flutter UI at all — that narrows the copyleft surface to the Go boundary. For a fast first build, forking the full repo is practical; just keep the repo public and comply with attribution requirements.

---

## 2. Repo Layout Orientation

```
hiddify-app/                   # Flutter application (this is what you fork)
  lib/
    features/
      home/                    # main connection screen
      profile/                 # subscription/profile management  ← replace this
      settings/
      panel/                   # server stats / clash API display
    core/
      http_client/             # Hiddify's own HTTP helpers
    data/
      repository/
      model/
    services/
      main_service_manager.dart  # starts/stops the VPN service
  android/
    app/src/main/
      AndroidManifest.xml
      kotlin/…/MainActivity.kt
      …/MyVpnService.kt          # VpnService subclass  ← Hiddify already implements this

hiddify-core/                  # Go module (separate repo, produces libcore.aar)
  libcore/
    …                          # wraps sing-box, exposes Start/Stop/QueryStats via JNI/FFI
```

**Boundary rule:** You work almost exclusively inside `lib/` (Dart/Flutter) and `android/` (Kotlin/Manifest). You do **not** need to modify the Go core for login, node fetching, or config building. The Go core exposes a `start(configJson: String)` style interface; you produce the JSON on the Dart side and hand it over. Verify the exact method name/signature in `hiddify-core/libcore` and the corresponding Dart FFI bindings in `lib/core/` or the platform channel files.

---

## 3. What to Add

### 3.1 Auth / Login Screen

Create `lib/features/auth/` with:
- `login_screen.dart` — email + password fields, login button
- `auth_repository.dart` — calls the API, persists the JWT
- `auth_provider.dart` — Riverpod `AsyncNotifierProvider`

### 3.2 API Client Service

```dart
// lib/services/panel_api_client.dart
import 'package:dio/dio.dart';

class PanelApiClient {
  final Dio _dio;

  PanelApiClient(String baseUrl, {String? token})
      : _dio = Dio(BaseOptions(
          baseUrl: baseUrl,
          headers: token != null ? {'Authorization': 'Bearer $token'} : {},
        ));

  Future<String> login(String email, String password) async {
    final res = await _dio.post('/api/v1/login',
        data: {'email': email, 'password': password});
    return res.data['token'] as String;
  }

  Future<Map<String, dynamic>> getUser() async {
    final res = await _dio.get('/api/v1/user');
    return res.data as Map<String, dynamic>;
  }

  Future<List<dynamic>> getPlans() async {
    final res = await _dio.get('/api/v1/plans');
    return res.data as List<dynamic>;
  }

  Future<String> createOrder(String planId) async {
    final res = await _dio.post('/api/v1/order', data: {'plan_id': planId});
    return res.data['checkout_url'] as String;
  }

  Future<List<dynamic>> getNodes() async {
    final res = await _dio.get('/api/v1/nodes');
    return res.data as List<dynamic>;
  }
}
```

### 3.3 Secure Token Storage

```yaml
# pubspec.yaml additions
dependencies:
  flutter_secure_storage: ^9.0.0
  dio: ^5.0.0
  url_launcher: ^6.0.0
```

```dart
// lib/services/auth_storage.dart
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthStorage {
  static const _key = 'panel_jwt';
  final _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true), // uses Android Keystore
  );

  Future<void> saveToken(String token) => _storage.write(key: _key, value: token);
  Future<String?> readToken() => _storage.read(key: _key);
  Future<void> clearToken() => _storage.delete(key: _key);
}
```

### 3.4 Account / Usage Screen

Fetch `/api/v1/user` after login and display upload/download used, quota limit, and expiry date. Wire a Riverpod provider that refreshes on app resume.

### 3.5 Plans Screen with Browser Checkout

```dart
// In your plans screen widget
Future<void> _purchasePlan(String planId) async {
  final url = await ref.read(panelApiClientProvider).createOrder(planId);
  final uri = Uri.parse(url);
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalBrowser);
  }
}
```

No in-app purchase SDK is needed. Payment is entirely on the web.

---

## 4. What to Replace / Remove

**Remove:** `lib/features/profile/` — all UI and logic for "Add Profile", "Import Subscription URL", and the subscription update scheduler.

**Replace with:** After a successful login, call `/api/v1/nodes`, build a sing-box config JSON string (see Section 5), and inject it into the existing profile/config pipeline.

Hiddify converts a profile into a running config somewhere in `lib/features/profile/` or `lib/data/repository/profile_repository.dart` — look for the call path that eventually invokes `MainServiceManager.start()` or equivalent, passing a config file path or JSON string to the core. **Verify this call site in the actual source.** Your goal is to arrive at the same call with your synthesized JSON instead of a downloaded subscription config.

A minimal injection point looks like:

```dart
// lib/features/connection/connection_notifier.dart (sketch — verify actual file)
Future<void> connectWithNodes(List<Map<String, dynamic>> nodes) async {
  final config = SingboxConfigBuilder.build(nodes);
  // Write config to a temp file or pass directly, matching Hiddify's expected input
  final configPath = await _writeConfigToTemp(config);
  await MainServiceManager.instance.start(configPath);
}
```

---

## 5. sing-box Config Building

### 5.1 Config Template

```json
{
  "log": { "level": "warn" },
  "dns": {
    "servers": [
      { "tag": "remote", "address": "8.8.8.8", "detour": "proxy" },
      { "tag": "local",  "address": "223.5.5.5", "detour": "direct" }
    ],
    "rules": [{ "outbound": "any", "server": "local" }],
    "final": "remote"
  },
  "inbounds": [
    {
      "type": "tun",
      "tag": "tun-in",
      "inet4_address": "172.19.0.1/30",
      "auto_route": true,
      "strict_route": true,
      "sniff": true
    }
  ],
  "outbounds": [
    { "type": "selector", "tag": "proxy",   "outbounds": ["auto", "direct"] },
    { "type": "urltest",  "tag": "auto",    "outbounds": [],
      "url": "https://www.gstatic.com/generate_204", "interval": "3m" },
    { "type": "direct",   "tag": "direct" },
    { "type": "block",    "tag": "block"  },
    { "type": "dns",      "tag": "dns-out"}
  ],
  "experimental": {
    "clash_api": { "external_controller": "127.0.0.1:9090", "secret": "" }
  }
}
```

The `auto` urltest outbounds list and the `proxy` selector list are filled programmatically.

### 5.2 Dart Config Builder

```dart
// lib/services/singbox_config_builder.dart
class SingboxConfigBuilder {
  static Map<String, dynamic> build(List<Map<String, dynamic>> nodes) {
    final outbounds = nodes.map(_nodeToOutbound).whereType<Map<String, dynamic>>().toList();
    final tags = outbounds.map((o) => o['tag'] as String).toList();

    final config = _baseConfig();
    (config['outbounds'] as List).addAll(outbounds);
    // inject tags into selector and urltest
    final selector = (config['outbounds'] as List).firstWhere((o) => o['tag'] == 'proxy');
    selector['outbounds'] = ['auto', 'direct', ...tags];
    final urltest = (config['outbounds'] as List).firstWhere((o) => o['tag'] == 'auto');
    urltest['outbounds'] = tags;

    return config;
  }

  static Map<String, dynamic>? _nodeToOutbound(Map<String, dynamic> node) {
    final tag  = node['name'] as String;
    final type = (node['type'] as String).toLowerCase();

    switch (type) {
      case 'vless':
        return {
          'type': 'vless', 'tag': tag,
          'server': node['server'], 'server_port': node['port'],
          'uuid': node['uuid'],
          'flow': node['flow'] ?? '',
          'tls': _tls(node),
          'transport': _transport(node),
        };
      case 'vmess':
        return {
          'type': 'vmess', 'tag': tag,
          'server': node['server'], 'server_port': node['port'],
          'uuid': node['uuid'], 'security': node['security'] ?? 'auto',
          'tls': _tls(node),
          'transport': _transport(node),
        };
      case 'trojan':
        return {
          'type': 'trojan', 'tag': tag,
          'server': node['server'], 'server_port': node['port'],
          'password': node['password'],
          'tls': _tls(node),
          'transport': _transport(node),
        };
      case 'shadowsocks':
        return {
          'type': 'shadowsocks', 'tag': tag,
          'server': node['server'], 'server_port': node['port'],
          'method': node['method'] ?? 'aes-256-gcm',
          'password': node['password'],
        };
      case 'hysteria2':
        return {
          'type': 'hysteria2', 'tag': tag,
          'server': node['server'], 'server_port': node['port'],
          'password': node['password'],
          'tls': _tls(node),
        };
      default:
        return null; // unsupported type — skip
    }
  }

  static Map<String, dynamic> _tls(Map<String, dynamic> node) => {
    'enabled': true,
    'server_name': node['sni'] ?? node['server'],
    'insecure': node['skip_cert_verify'] == true,
  };

  static Map<String, dynamic>? _transport(Map<String, dynamic> node) {
    final net = node['network'] ?? node['transport'];
    if (net == null) return null;
    switch (net) {
      case 'ws':   return {'type': 'ws',   'path': node['path'] ?? '/', 'headers': {'Host': node['host'] ?? node['sni'] ?? node['server']}};
      case 'grpc': return {'type': 'grpc', 'service_name': node['service_name'] ?? ''};
      case 'http': return {'type': 'http', 'path': node['path'] ?? '/'};
      default:     return null;
    }
  }
}
```

> **Verify:** Confirm the exact field names your `/api/v1/nodes` response uses and adjust the key lookups above accordingly.

---

## 6. Android Specifics

Hiddify already implements all Android VPN plumbing. Key things to know:

- **`VpnService` subclass** exists in `android/app/src/main/kotlin/…` — look for a class extending `android.net.VpnService`. Do not replace it; your Dart layer calls it via platform channel/method channel.
- **`VpnService.prepare(context)`** — must be called on first use and requires user consent via an Intent result. Hiddify handles this flow; find the call site in the Kotlin activity or the Flutter method channel handler.
- **Foreground service notification** — required to keep the VPN alive when backgrounded. Hiddify creates a notification channel and calls `startForeground()`. Customize the notification title/icon as part of rebranding.
- **Manifest permissions** — `BIND_VPN_SERVICE`, `FOREGROUND_SERVICE`, `INTERNET` are already declared. After renaming the package, ensure `AndroidManifest.xml` still carries these.

---

## 7. Rebranding Checklist

| Item | Location | Action |
|------|----------|--------|
| Application ID | `android/app/build.gradle` | Change `applicationId` to your package name |
| App name | `android/app/src/main/res/values/strings.xml` | Update `app_name` |
| Kotlin package | `android/app/src/main/kotlin/` | Rename directory tree and update `package` declarations |
| Flutter package name | `pubspec.yaml` | Update `name:` field |
| Launcher icons | `android/app/src/main/res/mipmap-*/` | Replace with your assets (use `flutter_launcher_icons`) |
| Splash screen | `android/app/src/main/res/drawable/` | Replace launch background |
| Store listing | Google Play | Do not use "Hiddify" in title/description; credit required in description |
| About screen | `lib/features/settings/about/` | Add Hiddify attribution per license |

---

## 8. Build & Run

```bash
# Install dependencies
flutter pub get

# Debug build on connected Android device
flutter run --flavor <yourFlavor>   # omit --flavor if you have no flavors defined

# Release APK
flutter build apk --release --target-platform android-arm64

# Release AAB (for Play Store)
flutter build appbundle --release
```

**Signing:** Create a keystore and add to `android/key.properties`:
```properties
storePassword=...
keyPassword=...
keyAlias=...
storeFile=../keystore/release.jks
```
Reference it in `android/app/build.gradle` under `signingConfigs`.

**libcore .aar:** The prebuilt Go core artifact is consumed as a Gradle dependency (check `android/app/build.gradle` for a local file dependency or Maven coordinate pointing to a hiddify-core release). You almost never need to compile the Go core yourself — download the matching `.aar` from hiddify-core releases and drop it in `android/app/libs/` if a local path is used, or update the version tag if fetched from Maven/GitHub Packages.

> **Verify:** Check `android/app/build.gradle` for exactly how libcore is referenced before your first build.

---

## 9. Minimum Viable Path — Ordered Checklist

1. **Fork** `hiddify-app` on GitHub (required by license; keep it public).
2. **Confirm libcore dependency** resolves — run `flutter pub get && flutter build apk` on the unmodified fork first to prove the baseline builds.
3. **Add `PanelApiClient`** and `AuthStorage`; write a simple integration test hitting your SSPanel staging URL.
4. **Build the Login screen** with Riverpod; on success, persist JWT and navigate to a stub home screen.
5. **Implement `SingboxConfigBuilder`**; unit-test it with a hardcoded node list and validate the output JSON against sing-box's JSON schema.
6. **Call `/api/v1/nodes`** post-login, build the config, write it to the app's files directory.
7. **Find the core-start call site** in Hiddify's source (search for `MainServiceManager.start` or the platform channel call that passes a config path), and hook your config file path into that call.
8. **Remove the subscription import UI**; confirm the app routes from login directly to the connection screen.
9. **Test VPN connect end-to-end** on a physical Android device (emulators do not support `VpnService`).
10. **Rebrand** (applicationId, icons, app name, attribution in About screen).
11. **Release-sign the APK/AAB** and verify on a second device before any store submission.
