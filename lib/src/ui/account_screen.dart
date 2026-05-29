// lib/src/ui/account_screen.dart
//
// Displays the user's subscription status, traffic usage, and expiry.
// Uses Riverpod AsyncNotifier pattern consistent with Hiddify 2.x.
//
// Verify against Hiddify source: lib/features/profile/overview/
// to confirm how Hiddify surfaces its own profile widgets — you may want to
// reuse the same scaffold/theming primitives.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../api/models.dart';
import '../auth/auth_controller.dart';

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final userAccountProvider = FutureProvider.autoDispose<UserAccount>((ref) async {
  final api = ref.watch(apiClientProvider);
  return api.getUser();
});

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(userAccountProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Account'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(userAccountProvider),
          ),
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout),
            onPressed: () =>
                ref.read(authControllerProvider.notifier).logout(),
          ),
        ],
      ),
      body: userAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => _ErrorView(
          message: err.toString(),
          onRetry: () => ref.invalidate(userAccountProvider),
        ),
        data: (user) => _AccountBody(user: user),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Body
// ---------------------------------------------------------------------------

class _AccountBody extends StatelessWidget {
  final UserAccount user;
  const _AccountBody({required this.user});

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
        ? 'No expiry'
        : '${user.expiryDate.year}-'
            '${user.expiryDate.month.toString().padLeft(2, '0')}-'
            '${user.expiryDate.day.toString().padLeft(2, '0')}';

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Username / plan name card
        Card(
          child: ListTile(
            leading: const Icon(Icons.account_circle_outlined, size: 40),
            title: Text(user.u,
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            subtitle: Text('Plan: ${user.planName}'),
          ),
        ),
        const SizedBox(height: 16),

        // Traffic usage
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Traffic Usage',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                LinearProgressIndicator(
                  value: fraction,
                  minHeight: 10,
                  borderRadius: BorderRadius.circular(5),
                  backgroundColor: colorScheme.surfaceVariant,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    fraction > 0.9
                        ? colorScheme.error
                        : colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Used: $usedLabel',
                        style: theme.textTheme.bodySmall),
                    Text('Total: $totalLabel',
                        style: theme.textTheme.bodySmall),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Expiry
        Card(
          child: ListTile(
            leading: const Icon(Icons.calendar_today_outlined),
            title: const Text('Subscription Expires'),
            trailing: Text(expiryStr,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w600)),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Error view
// ---------------------------------------------------------------------------

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

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
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
