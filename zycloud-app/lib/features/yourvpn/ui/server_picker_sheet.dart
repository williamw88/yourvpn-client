import 'package:flutter/material.dart';
import 'package:hiddify/core/localization/translations.dart';
import 'package:hiddify/features/yourvpn/ui/node_provider.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class ServerPickerSheet extends ConsumerStatefulWidget {
  const ServerPickerSheet({super.key});

  @override
  ConsumerState<ServerPickerSheet> createState() => _ServerPickerSheetState();
}

class _ServerPickerSheetState extends ConsumerState<ServerPickerSheet> {
  final Set<String> _expanded = {};

  @override
  Widget build(BuildContext context) {
    final nodesAsync = ref.watch(nodeListProvider);
    final selected = ref.watch(selectedNodeProvider);
    final t = ref.watch(translationsProvider).requireValue;

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  const Icon(Icons.dns_rounded),
                  const SizedBox(width: 8),
                  Text(t.yourvpn.serverPicker.title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: nodesAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline, size: 40, color: Colors.red),
                      const SizedBox(height: 8),
                      Text(e.toString(), textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: () => ref.invalidate(nodeListProvider),
                        child: Text(t.yourvpn.serverPicker.retry),
                      ),
                    ],
                  ),
                ),
                data: (nodes) {
                  final grouped = groupNodesByCountry(nodes);
                  return ListView(
                    controller: scrollController,
                    children: [
                      // Auto option
                      _NodeTile(
                        leading: const Text('🌐', style: TextStyle(fontSize: 22)),
                        title: t.yourvpn.serverPicker.autoLowestLatency,
                        subtitle: t.yourvpn.serverPicker.autoDescription,
                        isSelected: selected == null,
                        onTap: () {
                          ref.read(selectedNodeProvider.notifier).state = null;
                          Navigator.pop(context);
                        },
                      ),
                      const Divider(height: 1),
                      // Country groups
                      ...grouped.entries.map((entry) {
                        final country = entry.key;
                        final countryNodes = entry.value;
                        final isExpanded = _expanded.contains(country);
                        final hasSelected = selected != null && countryNodes.any((n) => n.id == selected.id);

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ListTile(
                              leading: Text(
                                _flagFromLabel(country),
                                style: const TextStyle(fontSize: 22),
                              ),
                              title: Text(
                                _nameFromLabel(country),
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  fontWeight: hasSelected ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    t.yourvpn.serverPicker.nodeCount(n: countryNodes.length),
                                    style: Theme.of(context).textTheme.bodySmall,
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(isExpanded ? Icons.expand_less : Icons.expand_more),
                                ],
                              ),
                              onTap: () => setState(() {
                                if (isExpanded) {
                                  _expanded.remove(country);
                                } else {
                                  _expanded.add(country);
                                }
                              }),
                            ),
                            if (isExpanded)
                              ...countryNodes.map((node) => _NodeTile(
                                leading: const SizedBox(width: 22),
                                title: node.name,
                                subtitle: node.server,
                                isSelected: selected?.id == node.id,
                                onTap: () {
                                  ref.read(selectedNodeProvider.notifier).state = node;
                                  Navigator.pop(context);
                                },
                                indent: 16,
                              )),
                            const Divider(height: 1),
                          ],
                        );
                      }),
                    ],
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  String _flagFromLabel(String label) {
    final space = label.indexOf(' ');
    if (space > 0) return label.substring(0, space);
    return '🌍';
  }

  String _nameFromLabel(String label) {
    final space = label.indexOf(' ');
    if (space > 0) return label.substring(space + 1);
    return label;
  }
}

class _NodeTile extends StatelessWidget {
  const _NodeTile({
    required this.leading,
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
    this.indent = 0,
  });

  final Widget leading;
  final String title;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;
  final double indent;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme;
    return ListTile(
      contentPadding: EdgeInsetsDirectional.only(start: 16 + indent, end: 16),
      leading: leading,
      title: Text(
        title,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? color.primary : null,
        ),
      ),
      subtitle: Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
      trailing: isSelected ? Icon(Icons.check_circle_rounded, color: color.primary) : null,
      onTap: onTap,
    );
  }
}
