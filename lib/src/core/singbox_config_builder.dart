// lib/src/core/singbox_config_builder.dart
//
// Builds a sing-box 1.8+ JSON configuration from a list of VpnNode objects.
// The resulting Map can be serialised with jsonEncode() and written to the
// config file that libcore/sing-box reads.
//
// Verify against Hiddify source: lib/features/config/service/config_service.dart
// and lib/core/core_service.dart to confirm the expected config format
// and whether Hiddify applies additional transformations before passing the
// config to libcore (e.g. adding log level, caching, or clash API port).

import 'dart:convert';

import '../api/models.dart';

// ---------------------------------------------------------------------------
// Public entry point
// ---------------------------------------------------------------------------

/// Builds a sing-box config and returns it as a JSON string.
String buildSingBoxConfig(List<VpnNode> nodes) {
  return jsonEncode(_buildConfig(nodes));
}

/// Builds a sing-box config and returns it as a [Map] (useful for merging).
Map<String, dynamic> buildSingBoxConfigMap(List<VpnNode> nodes) {
  return _buildConfig(nodes);
}

// ---------------------------------------------------------------------------
// Top-level builder
// ---------------------------------------------------------------------------

Map<String, dynamic> _buildConfig(List<VpnNode> nodes) {
  final outbounds = <Map<String, dynamic>>[];

  // --- Per-node outbounds ---
  for (final node in nodes) {
    final ob = _buildNodeOutbound(node);
    if (ob != null) outbounds.add(ob);
  }

  final validTags = outbounds.map((o) => o['tag'] as String).toList();

  // --- selector (manual switch) ---
  outbounds.add({
    'type': 'selector',
    'tag': 'proxy',
    'outbounds': ['auto', ...validTags],
    'default': validTags.isNotEmpty ? validTags.first : 'direct',
  });

  // --- urltest (automatic best latency) ---
  outbounds.add({
    'type': 'urltest',
    'tag': 'auto',
    'outbounds': validTags,
    'url': 'https://www.gstatic.com/generate_204',
    'interval': '3m',
    'tolerance': 50,
  });

  // --- utility outbounds ---
  outbounds.addAll([
    {'type': 'direct', 'tag': 'direct'},
    {'type': 'block', 'tag': 'block'},
    {'type': 'dns', 'tag': 'dns-out'},
  ]);

  return {
    'log': {'level': 'warn', 'timestamp': true},
    'dns': _buildDns(),
    'inbounds': _buildInbounds(),
    'outbounds': outbounds,
    'route': _buildRoute(),
    'experimental': _buildExperimental(),
  };
}

// ---------------------------------------------------------------------------
// Inbounds
// ---------------------------------------------------------------------------

List<Map<String, dynamic>> _buildInbounds() {
  return [
    // TUN inbound — requires the tun permission / VpnService on Android.
    // TODO: Verify TUN interface name, MTU, and inet4_address values against
    //       Hiddify's own tun config in lib/features/config/service/config_service.dart
    {
      'type': 'tun',
      'tag': 'tun-in',
      'interface_name': 'tun0',
      'inet4_address': '172.19.0.1/30',
      'inet6_address': 'fdfe:dcba:9876::1/126',
      'mtu': 9000,
      'auto_route': true,
      'strict_route': true,
      'stack': 'system',
      'sniff': true,
      'sniff_override_destination': false,
    },
    // Mixed proxy inbound for desktop/local use.
    {
      'type': 'mixed',
      'tag': 'mixed-in',
      'listen': '127.0.0.1',
      'listen_port': 2080,
      'sniff': true,
    },
  ];
}

// ---------------------------------------------------------------------------
// DNS
// ---------------------------------------------------------------------------

Map<String, dynamic> _buildDns() {
  return {
    'servers': [
      {
        'tag': 'dns-remote',
        'address': 'tls://8.8.8.8',
        'address_resolver': 'dns-direct',
        'strategy': 'prefer_ipv4',
      },
      {
        'tag': 'dns-direct',
        'address': '223.5.5.5',
        'strategy': 'prefer_ipv4',
        'detour': 'direct',
      },
      {'tag': 'dns-block', 'address': 'rcode://success'},
    ],
    'rules': [
      {'outbound': 'any', 'server': 'dns-direct'},
      {'rule_set': 'geosite-cn', 'server': 'dns-direct'},
    ],
    'final': 'dns-remote',
    'independent_cache': true,
  };
}

// ---------------------------------------------------------------------------
// Route
// ---------------------------------------------------------------------------

Map<String, dynamic> _buildRoute() {
  return {
    'rules': [
      // DNS hijack
      {'protocol': 'dns', 'outbound': 'dns-out'},
      // Private / loopback — bypass
      {'ip_is_private': true, 'outbound': 'direct'},
      // China direct
      {
        'rule_set': ['geosite-cn', 'geoip-cn'],
        'outbound': 'direct',
      },
    ],
    'rule_set': [
      {
        'type': 'remote',
        'tag': 'geosite-cn',
        'format': 'binary',
        'url':
            'https://raw.githubusercontent.com/SagerNet/sing-geosite/rule-set/geosite-cn.srs',
        'download_detour': 'direct',
      },
      {
        'type': 'remote',
        'tag': 'geoip-cn',
        'format': 'binary',
        'url':
            'https://raw.githubusercontent.com/SagerNet/sing-geoip/rule-set/geoip-cn.srs',
        'download_detour': 'direct',
      },
    ],
    'final': 'proxy',
    'auto_detect_interface': true,
  };
}

// ---------------------------------------------------------------------------
// Experimental (Clash API for the Hiddify dashboard)
// ---------------------------------------------------------------------------

Map<String, dynamic> _buildExperimental() {
  // TODO: Confirm port with Hiddify — Verify against Hiddify source:
  //       lib/features/config/service/config_service.dart clashApiPort constant.
  return {
    'clash_api': {
      'external_controller': '127.0.0.1:9090',
      'external_ui': 'dashboard',
      'external_ui_download_url':
          'https://github.com/MetaCubeX/Yacd-meta/archive/gh-pages.zip',
      'external_ui_download_detour': 'direct',
      'secret': '',
      'default_mode': 'rule',
    },
    'cache_file': {
      'enabled': true,
      'path': 'cache.db',
    },
  };
}

// ---------------------------------------------------------------------------
// Per-node outbound builders
// ---------------------------------------------------------------------------

Map<String, dynamic>? _buildNodeOutbound(VpnNode node) {
  switch (node.type) {
    case NodeType.vless:
      return _buildVless(node);
    case NodeType.vmess:
      return _buildVmess(node);
    case NodeType.trojan:
      return _buildTrojan(node);
    case NodeType.shadowsocks:
      return _buildShadowsocks(node);
    case NodeType.hysteria2:
      return _buildHysteria2(node);
    case NodeType.unknown:
      return null;
  }
}

// ---------------------------------------------------------------------------
// TLS / REALITY block (shared helper)
// ---------------------------------------------------------------------------

Map<String, dynamic>? _buildTls(VpnNode node) {
  final sec = node.security?.toLowerCase();
  if (sec == null || sec.isEmpty) return null;

  if (sec == 'reality') {
    return {
      'enabled': true,
      'server_name': node.sni ?? node.server,
      'utls': {'enabled': true, 'fingerprint': 'chrome'},
      'reality': {
        'enabled': true,
        'public_key': node.pbk ?? '',
        'short_id': node.sid ?? '',
      },
    };
  }

  // Standard TLS
  return {
    'enabled': true,
    'server_name': node.sni ?? node.server,
    'utls': {'enabled': true, 'fingerprint': 'chrome'},
    'insecure': false,
  };
}

// ---------------------------------------------------------------------------
// Transport block (shared helper)
// ---------------------------------------------------------------------------

Map<String, dynamic>? _buildTransport(VpnNode node) {
  switch (node.transport?.toLowerCase()) {
    case 'ws':
      return {
        'type': 'ws',
        'path': node.wsPath ?? '/',
        'headers': {
          if (node.sni != null) 'Host': node.sni!,
        },
      };
    case 'grpc':
      return {
        'type': 'grpc',
        'service_name': node.grpcServiceName ?? '',
      };
    default:
      return null;
  }
}

// ---------------------------------------------------------------------------
// Protocol builders
// ---------------------------------------------------------------------------

Map<String, dynamic> _buildVless(VpnNode node) {
  return {
    'type': 'vless',
    'tag': node.tag,
    'server': node.server,
    'server_port': node.serverPort,
    'uuid': node.uuid ?? '',
    if (node.flow != null && node.flow!.isNotEmpty) 'flow': node.flow,
    if (_buildTls(node) != null) 'tls': _buildTls(node),
    if (_buildTransport(node) != null) 'transport': _buildTransport(node),
    'packet_encoding': 'xudp',
  };
}

Map<String, dynamic> _buildVmess(VpnNode node) {
  return {
    'type': 'vmess',
    'tag': node.tag,
    'server': node.server,
    'server_port': node.serverPort,
    'uuid': node.uuid ?? '',
    'security': node.method ?? 'auto',
    'alter_id': 0,
    if (_buildTls(node) != null) 'tls': _buildTls(node),
    if (_buildTransport(node) != null) 'transport': _buildTransport(node),
    'packet_encoding': 'xudp',
  };
}

Map<String, dynamic> _buildTrojan(VpnNode node) {
  return {
    'type': 'trojan',
    'tag': node.tag,
    'server': node.server,
    'server_port': node.serverPort,
    'password': node.password ?? '',
    if (_buildTls(node) != null)
      'tls': _buildTls(node)
    else
      'tls': {
        'enabled': true,
        'server_name': node.sni ?? node.server,
        'insecure': false,
      },
    if (_buildTransport(node) != null) 'transport': _buildTransport(node),
  };
}

Map<String, dynamic> _buildShadowsocks(VpnNode node) {
  return {
    'type': 'shadowsocks',
    'tag': node.tag,
    'server': node.server,
    'server_port': node.serverPort,
    'method': node.method ?? 'aes-128-gcm',
    'password': node.password ?? '',
    // Multiplex (optional — comment out if your server does not support it)
    'multiplex': {
      'enabled': false,
      'protocol': 'smux',
      'max_streams': 32,
    },
  };
}

Map<String, dynamic> _buildHysteria2(VpnNode node) {
  return {
    'type': 'hysteria2',
    'tag': node.tag,
    'server': node.server,
    'server_port': node.serverPort,
    'password': node.password ?? '',
    'tls': {
      'enabled': true,
      'server_name': node.sni ?? node.server,
      'insecure': false,
    },
    // Obfuscation — remove if unused
    // 'obfs': {'type': 'salamander', 'password': ''},
  };
}
