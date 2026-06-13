import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:hiddify/features/yourvpn/api/models.dart';
import 'package:hiddify/features/yourvpn/auth/auth_controller.dart';

// Currently selected node — null means Auto (lowest latency).
final selectedNodeProvider = StateProvider<VpnNode?>((ref) => null);

final nodeListProvider = FutureProvider.autoDispose<List<VpnNode>>((ref) {
  return ref.watch(apiClientProvider).getNodes();
});

// Groups nodes by country label extracted from node name.
Map<String, List<VpnNode>> groupNodesByCountry(List<VpnNode> nodes) {
  final map = <String, List<VpnNode>>{};
  for (final node in nodes) {
    final country = _countryLabel(node.name);
    map.putIfAbsent(country, () => []).add(node);
  }
  return Map.fromEntries(map.entries.toList()..sort((a, b) => a.key.compareTo(b.key)));
}

String _countryLabel(String name) {
  // Check for Regional Indicator flag emoji (U+1F1E0–U+1F1FF) at start
  if (name.runes.length >= 2) {
    final r1 = name.runes.first;
    if (r1 >= 0x1F1E0 && r1 <= 0x1F1FF) {
      final flag = String.fromCharCodes(name.runes.take(2));
      final rest = name.substring(flag.length).trim();
      final dash = rest.indexOf('-');
      final country = dash > 0 ? rest.substring(0, dash).trim() : rest.split(' ').first;
      return '$flag $country'.trim();
    }
  }
  final dash = name.indexOf(' - ');
  if (dash > 0) return name.substring(0, dash).trim();
  return name.split(' ').first;
}
