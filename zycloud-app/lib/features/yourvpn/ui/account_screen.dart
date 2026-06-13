// lib/features/yourvpn/ui/account_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hiddify/core/localization/translations.dart';

import '../api/api_client.dart';
import '../api/models.dart';
import '../auth/auth_controller.dart';

final userAccountProvider = FutureProvider.autoDispose<UserAccount>((ref) async {
  final api = ref.watch(apiClientProvider);
  return api.getUser();
});

class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(userAccountProvider);
    final t = ref.watch(translationsProvider).requireValue;

    return Scaffold(
      appBar: AppBar(
        title: Text(t.yourvpn.account.title),
        actions: [
          IconButton(
            tooltip: t.yourvpn.account.refresh,
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(userAccountProvider),
          ),
          IconButton(
            tooltip: t.yourvpn.account.signOut,
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(authControllerProvider.notifier).logout(),
          ),
        ],
      ),
      body: userAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => _ErrorView(
          message: err.toString(),
          onRetry: () => ref.invalidate(userAccountProvider),
          t: t,
        ),
        data: (user) => _AccountBody(user: user, t: t),
      ),
    );
  }
}

class _AccountBody extends StatelessWidget {
  final UserAccount user;
  final Translations t;
  const _AccountBody({required this.user, required this.t});

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    var value = bytes.toDouble();
    var i = 0;
    while (value >= 1024 && i < suffixes.length - 1) {
      value /= 1024;
      i++;
    }
    return '${value.toStringAsFixed(2)} ${suffixes[i]}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final usedLabel = _formatBytes(user.usedBytes);
    final totalLabel = _formatBytes(user.transferEnable);
    final fraction = user.usageFraction;

    final expiryStr = user.expireIn == 0
        ? t.yourvpn.account.noExpiry
        : '${user.expiryDate.year}-'
            '${user.expiryDate.month.toString().padLeft(2, '0')}-'
            '${user.expiryDate.day.toString().padLeft(2, '0')}';

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Card(
          child: ListTile(
            leading: const Icon(Icons.account_circle_outlined, size: 40),
            title: Text(user.displayName,
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            subtitle: Text(t.yourvpn.account.planLabel(name: user.planName)),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t.yourvpn.account.trafficUsage,
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                LinearProgressIndicator(
                  value: fraction,
                  minHeight: 10,
                  borderRadius: BorderRadius.circular(5),
                  backgroundColor: colorScheme.surfaceContainerHighest,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    fraction > 0.9 ? colorScheme.error : colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(t.yourvpn.account.used(value: usedLabel), style: theme.textTheme.bodySmall),
                    Text(t.yourvpn.account.total(value: totalLabel), style: theme.textTheme.bodySmall),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: ListTile(
            leading: const Icon(Icons.calendar_today_outlined),
            title: Text(t.yourvpn.account.subscriptionExpires),
            trailing: Text(expiryStr,
                style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
          ),
        ),
      ],
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  final Translations t;
  const _ErrorView({required this.message, required this.onRetry, required this.t});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: Text(t.yourvpn.account.retry),
            ),
          ],
        ),
      ),
    );
  }
}
