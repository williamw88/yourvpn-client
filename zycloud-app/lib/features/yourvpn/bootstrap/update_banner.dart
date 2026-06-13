// lib/features/yourvpn/bootstrap/update_banner.dart
import 'package:flutter/material.dart';
import 'package:hiddify/core/app_info/app_info_provider.dart';
import 'package:hiddify/core/localization/translations.dart';
import 'package:hiddify/features/yourvpn/bootstrap/bootstrap_provider.dart';
import 'package:hiddify/features/yourvpn/bootstrap/version_utils.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

/// Shown when the remote bootstrap config advertises a newer app version
/// than the one currently running. Tapping it opens the update page.
class UpdateBanner extends ConsumerWidget {
  const UpdateBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bootstrap = ref.watch(bootstrapConfigProvider).valueOrNull;
    final currentVersion = ref.watch(appInfoProvider).valueOrNull?.version;
    final t = ref.watch(translationsProvider).requireValue;

    if (bootstrap == null || currentVersion == null || bootstrap.latestVersion.isEmpty) {
      return const SizedBox.shrink();
    }
    if (compareVersions(currentVersion, bootstrap.latestVersion) >= 0) {
      return const SizedBox.shrink();
    }

    final isRequired = bootstrap.forceUpdate && compareVersions(currentVersion, bootstrap.minVersion) < 0;
    final theme = Theme.of(context);
    final background = isRequired ? theme.colorScheme.errorContainer : theme.colorScheme.secondaryContainer;
    final foreground = isRequired ? theme.colorScheme.onErrorContainer : theme.colorScheme.onSecondaryContainer;
    final message = isRequired
        ? t.yourvpn.update.requiredMessage(version: bootstrap.latestVersion)
        : t.yourvpn.update.availableMessage(version: bootstrap.latestVersion);

    return Material(
      color: background,
      child: InkWell(
        onTap: () => _openUpdateUrl(bootstrap.updateUrl),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Icon(Icons.system_update_rounded, color: foreground, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(message, style: theme.textTheme.bodySmall?.copyWith(color: foreground)),
              ),
              TextButton(
                onPressed: () => _openUpdateUrl(bootstrap.updateUrl),
                child: Text(
                  t.yourvpn.update.updateNow,
                  style: TextStyle(color: foreground, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openUpdateUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri != null && url.isNotEmpty) {
      launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
