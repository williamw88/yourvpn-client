import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hiddify/core/localization/translations.dart';
import 'package:hiddify/features/home/widget/connection_button.dart';
import 'package:hiddify/features/proxy/active/active_proxy_delay_indicator.dart';
import 'package:hiddify/features/yourvpn/api/models.dart';
import 'package:hiddify/features/yourvpn/bootstrap/update_banner.dart';
import 'package:hiddify/features/yourvpn/ui/account_screen.dart';
import 'package:hiddify/features/yourvpn/ui/node_provider.dart';
import 'package:hiddify/features/yourvpn/ui/server_picker_sheet.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class HomeDashboard extends ConsumerWidget {
  const HomeDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(userAccountProvider);
    final selectedNode = ref.watch(selectedNodeProvider);
    final t = ref.watch(translationsProvider).requireValue;

    return Column(
      children: [
        const UpdateBanner(),

        // ── Account summary card ──────────────────────────────────────
        userAsync.when(
          loading: () => const _AccountCardSkeleton(),
          error: (_, __) => const SizedBox.shrink(),
          data: (user) => _AccountCard(user: user, t: t),
        ),

        // ── Connection area ───────────────────────────────────────────
        const Expanded(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ConnectionButton(),
                SizedBox(height: 8),
                ActiveProxyDelayIndicator(),
              ],
            ),
          ),
        ),

        // ── Server selector bar ───────────────────────────────────────
        _ServerBar(selectedNode: selectedNode),
        const SizedBox(height: 16),
      ],
    );
  }
}

// ── Account summary card ─────────────────────────────────────────────────────

class _AccountCard extends StatelessWidget {
  const _AccountCard({required this.user, required this.t});
  final UserAccount user;
  final Translations t;

  String _fmt(int bytes) {
    if (bytes <= 0) return '0 B';
    const s = ['B', 'KB', 'MB', 'GB', 'TB'];
    var v = bytes.toDouble();
    var i = 0;
    while (v >= 1024 && i < s.length - 1) {
      v /= 1024;
      i++;
    }
    return '${v.toStringAsFixed(1)} ${s[i]}';
  }

  bool get _isExpired {
    if (user.expireIn == 0) return false;
    return user.expiryDate.isBefore(DateTime.now());
  }

  bool get _hasNoPlan => user.subscriptionClass == 0 || _isExpired;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final fraction = user.usageFraction;
    final usedLabel = _fmt(user.usedBytes);
    final totalLabel = _fmt(user.transferEnable);

    final expiryStr = user.expireIn == 0
        ? t.yourvpn.account.noExpiry
        : '${user.expiryDate.year}-'
            '${user.expiryDate.month.toString().padLeft(2, '0')}-'
            '${user.expiryDate.day.toString().padLeft(2, '0')}';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Material(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => context.pushNamed('plans'),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Plan name + expiry row
                Row(
                  children: [
                    Icon(Icons.workspace_premium_rounded, size: 18, color: cs.primary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _hasNoPlan ? t.yourvpn.home.noActivePlan : user.planName,
                        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                    if (!_hasNoPlan)
                      Text(t.yourvpn.home.expiry(date: expiryStr), style: theme.textTheme.bodySmall?.copyWith(color: cs.outline)),
                    const SizedBox(width: 4),
                    Icon(Icons.chevron_right_rounded, size: 18, color: cs.outline),
                  ],
                ),
                if (_hasNoPlan) ...[
                  const SizedBox(height: 10),
                  _BuyPlanButton(t: t),
                ] else ...[
                  const SizedBox(height: 10),
                  // Usage bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: fraction,
                      minHeight: 8,
                      backgroundColor: cs.surfaceContainerHighest,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        fraction > 0.9 ? cs.error : cs.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(t.yourvpn.home.used(value: usedLabel), style: theme.textTheme.bodySmall),
                      Text(t.yourvpn.home.total(value: totalLabel), style: theme.textTheme.bodySmall),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BuyPlanButton extends StatelessWidget {
  const _BuyPlanButton({required this.t});
  final Translations t;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        icon: const Icon(Icons.shopping_cart_rounded, size: 18),
        label: Text(t.yourvpn.home.getPlan),
        onPressed: () => context.pushNamed('plans'),
      ),
    );
  }
}

class _AccountCardSkeleton extends StatelessWidget {
  const _AccountCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      height: 80,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Center(child: CircularProgressIndicator()),
    );
  }
}

// ── Server selector bar ───────────────────────────────────────────────────────

class _ServerBar extends ConsumerWidget {
  const _ServerBar({required this.selectedNode});
  final VpnNode? selectedNode;

  void _openPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const ServerPickerSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final t = ref.watch(translationsProvider).requireValue;

    final label = selectedNode == null ? t.yourvpn.home.autoLowestLatency : selectedNode!.name;
    final flag = selectedNode == null ? '🌐' : _flagFor(selectedNode!.name);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Material(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _openPicker(context),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Text(flag, style: const TextStyle(fontSize: 22)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t.yourvpn.home.server, style: theme.textTheme.bodySmall?.copyWith(color: cs.outline)),
                      Text(
                        label,
                        style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Icon(Icons.keyboard_arrow_down_rounded, color: cs.outline),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _flagFor(String nodeName) {
    if (nodeName.length >= 4) {
      final r1 = nodeName.runes.first;
      if (r1 >= 0x1F1E0 && r1 <= 0x1F1FF) {
        // Two regional indicator letters = one flag emoji (4 UTF-16 code units)
        return String.fromCharCodes(nodeName.runes.take(2));
      }
    }
    return '🌍';
  }
}
