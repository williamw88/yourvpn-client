# yourvpn-client

App-specific overlay files for a branded VPN client built on top of a forked
[hiddify-app](https://github.com/hiddify/hiddify-next) Flutter project.

## What this folder is

This directory contains **only the custom source files** to be added to a fork
of hiddify-app. It is not a standalone Flutter project. Drop the contents into
the corresponding paths inside the Hiddify fork, merge the dependency additions
in `pubspec.additions.yaml` into the existing `pubspec.yaml`, and then wire the
TODO markers to the relevant Hiddify internals.

## File map

```
yourvpn-client/
├── lib/src/
│   ├── api/
│   │   ├── api_client.dart          HTTP client (package:http)
│   │   └── models.dart              AuthToken, UserAccount, Plan, Order, VpnNode
│   ├── auth/
│   │   ├── token_store.dart         Secure token persistence (flutter_secure_storage)
│   │   └── auth_controller.dart     Riverpod StateNotifier for auth flow
│   ├── ui/
│   │   ├── login_screen.dart        Email + password login screen
│   │   ├── account_screen.dart      Usage bar, expiry, plan name
│   │   └── plans_screen.dart        Plan list + buy → external browser
│   └── core/
│       ├── singbox_config_builder.dart  Builds sing-box 1.8+ JSON config
│       └── connection_controller.dart   Connect/disconnect orchestration
├── pubspec.additions.yaml           Extra deps to merge into Hiddify's pubspec.yaml
└── README.md                        This file
```

## Integration steps (summary)

1. Copy `lib/src/` into the Hiddify fork's `lib/` tree.
2. Merge `pubspec.additions.yaml` entries into `pubspec.yaml`, then run
   `flutter pub get`.
3. Search every file for `// TODO:` and `// Verify against Hiddify source:`
   comments — these mark the exact call sites that must be wired to Hiddify
   internals before the app will build cleanly.
4. Key Hiddify files to examine:
   - `lib/core/core_service.dart` — core start/stop
   - `lib/features/config/service/config_service.dart` — config file path
   - `lib/core/router/app_router.dart` — route names for navigation
5. Set the backend base URL at build time:
   ```
   flutter run --dart-define=API_BASE_URL=https://your-backend.example.com
   ```

## Licensing

This project is distributed under the **GNU General Public License v3.0** with
the additional conditions permitted by GPL Section 7:

- The fork must remain open source under GPLv3 (no proprietary re-licensing).
- Credit to the original Hiddify project must be retained in all user-visible
  about screens and source headers.
- The Hiddify name, logo, and original design elements must not appear on
  app-store listings or promotional material for any branded fork, in
  accordance with Hiddify's published fork guidelines.

See [https://github.com/hiddify/hiddify-next/blob/main/LICENSE](LICENSE) for
the full GPL v3 text.
