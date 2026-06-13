// lib/features/yourvpn/ui/plans_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hiddify/core/localization/translations.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api/api_client.dart';
import '../api/models.dart';
import '../auth/auth_controller.dart';

final plansProvider = FutureProvider.autoDispose<List<Plan>>((ref) async {
  final api = ref.watch(apiClientProvider);
  return api.getPlans();
});

class PlansScreen extends ConsumerWidget {
  const PlansScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plansAsync = ref.watch(plansProvider);
    final t = ref.watch(translationsProvider).requireValue;

    return Scaffold(
      appBar: AppBar(
        title: Text(t.yourvpn.plans.title),
        actions: [
          IconButton(
            tooltip: t.yourvpn.plans.refresh,
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(plansProvider),
          ),
        ],
      ),
      body: plansAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 12),
              Text(err.toString(), textAlign: TextAlign.center),
              const SizedBox(height: 16),
              OutlinedButton(onPressed: () => ref.invalidate(plansProvider), child: Text(t.yourvpn.plans.retry)),
            ],
          ),
        ),
        data: (plans) => plans.isEmpty
            ? Center(child: Text(t.yourvpn.plans.noPlans))
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: plans.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) => _PlanCard(plan: plans[index], t: t),
              ),
      ),
    );
  }
}

class _PlanCard extends ConsumerStatefulWidget {
  final Plan plan;
  final Translations t;
  const _PlanCard({required this.plan, required this.t});

  @override
  ConsumerState<_PlanCard> createState() => _PlanCardState();
}

class _PlanCardState extends ConsumerState<_PlanCard> {
  bool _loading = false;
  String? _error;

  Future<void> _buy() async {
    setState(() { _loading = true; _error = null; });
    try {
      final api = ref.read(apiClientProvider);
      final order = await api.createOrder(widget.plan.id);
      final uri = Uri.tryParse(order.checkoutUrl);
      if (uri == null) {
        setState(() => _error = widget.t.yourvpn.plans.invalidCheckoutUrl);
        return;
      }
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        setState(() => _error = widget.t.yourvpn.plans.couldNotOpenBrowser);
      }
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final plan = widget.plan;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(plan.name, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                Text('${plan.currency} ${plan.price.toStringAsFixed(2)}',
                    style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              widget.t.yourvpn.plans.planDetails(
                traffic: plan.trafficGb.toStringAsFixed(0),
                days: plan.durationDays,
              ),
              style: theme.textTheme.bodyMedium,
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: TextStyle(color: theme.colorScheme.error, fontSize: 12)),
            ],
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _loading ? null : _buy,
                child: _loading
                    ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(widget.t.yourvpn.plans.buyButton),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
