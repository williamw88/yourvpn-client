// lib/src/core/connection_controller.dart
//
// Riverpod controller that orchestrates: fetch nodes -> build config -> start core.
//
// The actual libcore start/stop calls are left as clearly marked TODOs below
// because they depend on Hiddify internals that must be verified against the
// upstream source before wiring up.
//
// Key Hiddify files to examine:
//   lib/core/core_service.dart           — HiddifyCoreService class
//   lib/features/config/service/config_service.dart — config file path helpers
//   lib/core/app_info/app_info_provider.dart          — app metadata provider
//
// The typical Hiddify call chain is:
//   HiddifyCoreService.instance.start(configPath) / .stop()
// but this has changed across versions; always verify against your fork.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../api/models.dart';
import 'singbox_config_builder.dart';

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

enum ConnectionStatus { disconnected, connecting, connected, disconnecting, error }

class ConnectionState {
  final ConnectionStatus status;
  final String? errorMessage;
  final List<VpnNode> nodes;

  const ConnectionState({
    required this.status,
    this.errorMessage,
    this.nodes = const [],
  });

  const ConnectionState.idle()
      : this(status: ConnectionStatus.disconnected);

  bool get isConnected => status == ConnectionStatus.connected;
  bool get isBusy =>
      status == ConnectionStatus.connecting ||
      status == ConnectionStatus.disconnecting;
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final connectionControllerProvider =
    StateNotifierProvider<ConnectionController, ConnectionState>((ref) {
  return ConnectionController(api: ref.watch(apiClientProvider));
});

// ---------------------------------------------------------------------------
// Controller
// ---------------------------------------------------------------------------

class ConnectionController extends StateNotifier<ConnectionState> {
  final ApiClient _api;

  ConnectionController({required ApiClient api})
      : _api = api,
        super(const ConnectionState.idle());

  // ---------------------------------------------------------------------------
  // Connect
  // ---------------------------------------------------------------------------

  Future<void> connect() async {
    if (state.isBusy) return;
    state = const ConnectionState(status: ConnectionStatus.connecting);

    try {
      // 1. Fetch nodes from the backend.
      final nodes = await _api.getNodes();
      if (nodes.isEmpty) {
        state = const ConnectionState(
          status: ConnectionStatus.error,
          errorMessage: 'No VPN nodes available. Please check your subscription.',
        );
        return;
      }

      // 2. Build the sing-box config.
      final configJson = buildSingBoxConfig(nodes);

      // 3. Write config and start the core.
      //
      // TODO: Plug into Hiddify's core start path here.
      //
      // Option A — via HiddifyCoreService (most likely in Hiddify 2.x):
      //
      //   import 'package:hiddify/core/core_service.dart';
      //   // Verify against Hiddify source: lib/core/core_service.dart
      //   // Confirm method signature: Future<void> start(String configPath)
      //   //   or start(Map<String, dynamic> config) or similar.
      //
      //   final configPath = await _writeConfigFile(configJson);
      //   await HiddifyCoreService.instance.start(configPath);
      //
      // Option B — via a Riverpod provider exposed by Hiddify:
      //
      //   final coreService = ref.read(hiddifyCoreServiceProvider);
      //   // Verify against Hiddify source: lib/core/app_info/app_info_provider.dart
      //   await coreService.startWithConfig(configJson);
      //
      // Option C — direct FFI / platform channel call:
      //   Verify against Hiddify source: lib/core/native_ffi/ or
      //   android/app/src/main/kotlin/.../CoreService.kt
      //
      // For now, log and pretend it worked so the rest of the UI can be tested.
      _debugLog('sing-box config built (${configJson.length} bytes)');
      _debugLog('TODO: call HiddifyCoreService.start() here');

      state = ConnectionState(
        status: ConnectionStatus.connected,
        nodes: nodes,
      );
    } on ApiException catch (e) {
      state = ConnectionState(
        status: ConnectionStatus.error,
        errorMessage: 'API error: ${e.message}',
      );
    } catch (e) {
      state = ConnectionState(
        status: ConnectionStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Disconnect
  // ---------------------------------------------------------------------------

  Future<void> disconnect() async {
    if (state.isBusy) return;
    state = const ConnectionState(status: ConnectionStatus.disconnecting);

    try {
      // TODO: Stop the sing-box core.
      //
      // Verify against Hiddify source: lib/core/core_service.dart
      // Expected call: await HiddifyCoreService.instance.stop();
      //
      _debugLog('TODO: call HiddifyCoreService.stop() here');

      state = const ConnectionState.idle();
    } catch (e) {
      // Even on error we reset to idle — the VPN tunnel is likely gone.
      state = ConnectionState(
        status: ConnectionStatus.error,
        errorMessage: 'Disconnect error: $e',
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// In production, replace with proper Hiddify logging.
  /// Verify against Hiddify source: lib/utils/logger.dart or similar.
  void _debugLog(String message) {
    // ignore: avoid_print
    print('[ConnectionController] $message');
  }
}

// ---------------------------------------------------------------------------
// Config file writer (stub)
// ---------------------------------------------------------------------------
// If Hiddify expects a file path rather than an in-memory string, use this.
// TODO: Replace path logic with Hiddify's config directory helper.
// Verify against Hiddify source: lib/features/config/service/config_service.dart
//
// import 'dart:io';
// import 'package:path_provider/path_provider.dart';
//
// Future<String> _writeConfigFile(String configJson) async {
//   final dir = await getApplicationSupportDirectory();
//   final file = File('${dir.path}/yourvpn_config.json');
//   await file.writeAsString(configJson);
//   return file.path;
// }
