// lib/features/yourvpn/api/models.dart

class AuthToken {
  final String token;
  final DateTime expires;

  const AuthToken({required this.token, required this.expires});

  factory AuthToken.fromJson(Map<String, dynamic> json) {
    final expiresRaw = json['expires_at'] ?? json['expires'];
    DateTime expires;
    if (expiresRaw is int) {
      expires = DateTime.fromMillisecondsSinceEpoch(expiresRaw * 1000, isUtc: true);
    } else if (expiresRaw is String) {
      expires = DateTime.tryParse(expiresRaw) ?? DateTime.now().add(const Duration(days: 7));
    } else {
      expires = DateTime.now().add(const Duration(days: 7));
    }
    return AuthToken(token: json['token'] as String, expires: expires);
  }

  Map<String, dynamic> toJson() => {'token': token, 'expires': expires.toIso8601String()};
}

class UserAccount {
  final String displayName;
  final String email;
  final int uploadBytes;
  final int downloadBytes;
  final int transferEnable;
  final int usedBytes;
  final int subscriptionClass;
  final int expireIn;
  final String planName;

  const UserAccount({
    required this.displayName,
    required this.email,
    required this.uploadBytes,
    required this.downloadBytes,
    required this.transferEnable,
    required this.usedBytes,
    required this.subscriptionClass,
    required this.expireIn,
    required this.planName,
  });

  factory UserAccount.fromJson(Map<String, dynamic> json) {
    int parseExpireIn() {
      final raw = json['expire_in'];
      if (raw is int) return raw;
      if (raw is String) {
        final dt = DateTime.tryParse(raw);
        if (dt != null) return dt.millisecondsSinceEpoch ~/ 1000;
      }
      final classExpire = json['class_expire'];
      if (classExpire is String) {
        final dt = DateTime.tryParse(classExpire);
        if (dt != null) return dt.millisecondsSinceEpoch ~/ 1000;
      }
      return 0;
    }

    return UserAccount(
      displayName: json['user_name'] as String? ?? json['email'] as String? ?? '',
      email: json['email'] as String? ?? '',
      uploadBytes: (json['u'] as num?)?.toInt() ?? 0,
      downloadBytes: (json['d'] as num?)?.toInt() ?? 0,
      transferEnable: (json['transfer_enable'] as num?)?.toInt() ?? 0,
      usedBytes: (json['used_bytes'] as num?)?.toInt() ?? 0,
      subscriptionClass: (json['class'] as num?)?.toInt() ?? 0,
      expireIn: parseExpireIn(),
      planName: json['plan_name'] as String? ?? '',
    );
  }

  int get remainingBytes => (transferEnable - usedBytes).clamp(0, transferEnable);
  DateTime get expiryDate => DateTime.fromMillisecondsSinceEpoch(expireIn * 1000, isUtc: true).toLocal();
  double get usageFraction => transferEnable == 0 ? 0.0 : (usedBytes / transferEnable).clamp(0.0, 1.0);
}

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

  factory Plan.fromJson(Map<String, dynamic> json) => Plan(
        id: (json['id'] as num).toInt(),
        name: json['name'] as String,
        price: (json['price'] as num).toDouble(),
        currency: json['currency'] as String? ?? 'USD',
        trafficGb: (json['traffic_gb'] as num?)?.toDouble() ?? 0.0,
        durationDays: (json['duration_days'] as num?)?.toInt() ?? 30,
      );
}

class Order {
  final String orderId;
  final String checkoutUrl;
  final String status;

  const Order({required this.orderId, required this.checkoutUrl, required this.status});

  factory Order.fromJson(Map<String, dynamic> json) => Order(
        orderId: json['order_id']?.toString() ?? '',
        checkoutUrl: json['checkout_url'] as String,
        status: json['status'] as String? ?? 'pending',
      );
}

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

class VpnNode {
  final int id;
  final String name;
  final NodeType type;
  final String server;
  final int serverPort;
  final String? uuid;
  final String? password;
  final String? method;
  final String? security;
  final String? sni;
  final String? pbk;
  final String? sid;
  final String? flow;
  final String? transport;
  final String? wsPath;
  final String? grpcServiceName;
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
    String? transportType;
    String? wsPath;
    String? grpcServiceName;
    final transportRaw = json['transport'];
    if (transportRaw is String) {
      transportType = transportRaw;
    } else if (transportRaw is Map<String, dynamic>) {
      transportType = transportRaw['type'] as String?;
      wsPath = transportRaw['path'] as String?;
      grpcServiceName = transportRaw['service_name'] as String?;
    }
    return VpnNode(
      id: id,
      name: name,
      type: _parseNodeType(json['type'] as String?),
      server: json['server'] as String,
      serverPort: (json['server_port'] as num?)?.toInt() ?? (json['port'] as num?)?.toInt() ?? 443,
      uuid: json['uuid'] as String?,
      password: json['password'] as String?,
      method: json['method'] as String?,
      security: json['security'] as String?,
      sni: json['sni'] as String?,
      pbk: json['pbk'] as String?,
      sid: json['sid'] as String?,
      flow: json['flow'] as String?,
      transport: transportType,
      wsPath: wsPath ?? json['ws_path'] as String?,
      grpcServiceName: grpcServiceName ?? json['grpc_service_name'] as String?,
      tag: json['tag'] as String? ?? '$name-$id',
    );
  }
}
