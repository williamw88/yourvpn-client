// lib/src/api/models.dart
//
// Plain Dart model classes for the YourVPN backend API.
// All classes are immutable and expose a fromJson constructor.

/// Bearer token returned by POST /api/v1/login.
class AuthToken {
  final String token;
  final DateTime expires;

  const AuthToken({required this.token, required this.expires});

  factory AuthToken.fromJson(Map<String, dynamic> json) {
    return AuthToken(
      token: json['token'] as String,
      expires: DateTime.parse(json['expires'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'token': token,
        'expires': expires.toIso8601String(),
      };
}

/// Authenticated user's account details from GET /api/v1/user.
class UserAccount {
  /// Username / display name.
  final String u;

  /// Download bytes used (may be same as [usedBytes] depending on backend).
  final int d;

  /// Total traffic quota in bytes.
  final int transferEnable;

  /// Bytes consumed so far.
  final int usedBytes;

  /// Subscription tier / class level.
  final int subscriptionClass;

  /// Subscription expiry as Unix timestamp (seconds).
  final int expireIn;

  /// Human-readable plan name.
  final String planName;

  const UserAccount({
    required this.u,
    required this.d,
    required this.transferEnable,
    required this.usedBytes,
    required this.subscriptionClass,
    required this.expireIn,
    required this.planName,
  });

  factory UserAccount.fromJson(Map<String, dynamic> json) {
    return UserAccount(
      u: json['u'] as String? ?? '',
      d: (json['d'] as num?)?.toInt() ?? 0,
      transferEnable: (json['transfer_enable'] as num?)?.toInt() ?? 0,
      usedBytes: (json['used_bytes'] as num?)?.toInt() ?? 0,
      subscriptionClass: (json['class'] as num?)?.toInt() ?? 0,
      expireIn: (json['expire_in'] as num?)?.toInt() ?? 0,
      planName: json['plan_name'] as String? ?? '',
    );
  }

  /// Remaining traffic in bytes.
  int get remainingBytes => (transferEnable - usedBytes).clamp(0, transferEnable);

  /// Expiry as a [DateTime].
  DateTime get expiryDate =>
      DateTime.fromMillisecondsSinceEpoch(expireIn * 1000, isUtc: true).toLocal();

  /// Usage fraction 0.0–1.0 for progress indicators.
  double get usageFraction =>
      transferEnable == 0 ? 0.0 : (usedBytes / transferEnable).clamp(0.0, 1.0);
}

/// A subscription plan from GET /api/v1/plans.
class Plan {
  final int id;
  final String name;
  final double price;
  final String currency;
  final double trafficGb;
  final int durationDays;

  const Plan({
    required this.id,
    required this.name,
    required this.price,
    required this.currency,
    required this.trafficGb,
    required this.durationDays,
  });

  factory Plan.fromJson(Map<String, dynamic> json) {
    return Plan(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String,
      price: (json['price'] as num).toDouble(),
      currency: json['currency'] as String? ?? 'USD',
      trafficGb: (json['traffic_gb'] as num?)?.toDouble() ?? 0.0,
      durationDays: (json['duration_days'] as num?)?.toInt() ?? 30,
    );
  }
}

/// Order created by POST /api/v1/order.
class Order {
  final String orderId;
  final String checkoutUrl;
  final String status;

  const Order({
    required this.orderId,
    required this.checkoutUrl,
    required this.status,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    return Order(
      orderId: json['order_id']?.toString() ?? '',
      checkoutUrl: json['checkout_url'] as String,
      status: json['status'] as String? ?? 'pending',
    );
  }
}

/// Protocol type enum — used when building the sing-box config.
enum NodeType { vless, vmess, trojan, shadowsocks, hysteria2, unknown }

NodeType _parseNodeType(String? raw) {
  switch (raw?.toLowerCase()) {
    case 'vless':
      return NodeType.vless;
    case 'vmess':
      return NodeType.vmess;
    case 'trojan':
      return NodeType.trojan;
    case 'shadowsocks':
    case 'ss':
      return NodeType.shadowsocks;
    case 'hysteria2':
    case 'hy2':
      return NodeType.hysteria2;
    default:
      return NodeType.unknown;
  }
}

/// A VPN node from GET /api/v1/nodes.
class VpnNode {
  final int id;
  final String name;
  final NodeType type;
  final String server;
  final int serverPort;

  // VLESS / VMess
  final String? uuid;

  // Trojan / Shadowsocks
  final String? password;

  // Shadowsocks
  final String? method;

  // TLS / REALITY
  final String? security; // "tls" | "reality" | null
  final String? sni;
  final String? pbk;   // REALITY public key
  final String? sid;   // REALITY short ID

  // VLESS XTLS
  final String? flow; // "xtls-rprx-vision" etc.

  // Transport
  final String? transport; // "ws" | "grpc" | null
  final String? wsPath;
  final String? grpcServiceName;

  /// Tag used inside sing-box outbounds — derived from name + id.
  final String tag;

  const VpnNode({
    required this.id,
    required this.name,
    required this.type,
    required this.server,
    required this.serverPort,
    this.uuid,
    this.password,
    this.method,
    this.security,
    this.sni,
    this.pbk,
    this.sid,
    this.flow,
    this.transport,
    this.wsPath,
    this.grpcServiceName,
    required this.tag,
  });

  factory VpnNode.fromJson(Map<String, dynamic> json) {
    final id = (json['id'] as num).toInt();
    final name = json['name'] as String? ?? 'Node $id';
    return VpnNode(
      id: id,
      name: name,
      type: _parseNodeType(json['type'] as String?),
      server: json['server'] as String,
      serverPort: (json['server_port'] as num?)?.toInt() ??
          (json['port'] as num?)?.toInt() ??
          443,
      uuid: json['uuid'] as String?,
      password: json['password'] as String?,
      method: json['method'] as String?,
      security: json['security'] as String?,
      sni: json['sni'] as String?,
      pbk: json['pbk'] as String?,
      sid: json['sid'] as String?,
      flow: json['flow'] as String?,
      transport: json['transport'] as String?,
      wsPath: json['ws_path'] as String?,
      grpcServiceName: json['grpc_service_name'] as String?,
      tag: json['tag'] as String? ?? '$name-$id',
    );
  }
}
