import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xparq_app/features/control_deck/providers/control_provider.dart';
import 'package:xparq_app/features/control_deck/widgets/dashboard_stat_card.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(controlProvider.notifier).load();
    });
  }

  Future<void> _refresh() async {
    await ref.read(controlProvider.notifier).load();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<ControlState>(controlProvider, (previous, next) {
      if (previous?.errorMessage == next.errorMessage ||
          next.errorMessage == null) {
        return;
      }

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(next.errorMessage!)));
    });

    final state = ref.watch(controlProvider);
    final dashboard = state.dashboard;

    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard')),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(
                'Control Deck Overview',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Monitor total users and current active users.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.72),
                ),
              ),
              const SizedBox(height: 24),
              if (state.isLoading && dashboard == null)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 64),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (dashboard != null) ...[
                DashboardStatCard(
                  title: 'Total Users',
                  value: dashboard.users,
                  icon: Icons.group_outlined,
                ),
                const SizedBox(height: 16),
                DashboardStatCard(
                  title: 'Active Users',
                  value: dashboard.active,
                  icon: Icons.bolt_outlined,
                ),
              ] else
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 64),
                  child: Center(
                    child: Text(
                      'No dashboard data available.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: state.isLoading ? null : _refresh,
        icon: const Icon(Icons.refresh),
        label: const Text('Reload'),
      ),
    );
  }
}
