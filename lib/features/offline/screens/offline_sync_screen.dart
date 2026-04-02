import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xparq_app/core/widgets/galaxy_button.dart';
import 'package:xparq_app/core/widgets/glass_card.dart';
import 'package:xparq_app/features/offline/providers/offline_provider.dart';
import 'package:xparq_app/features/offline/widgets/offline_task_tile.dart';

class OfflineSyncScreen extends ConsumerStatefulWidget {
  const OfflineSyncScreen({super.key});

  @override
  ConsumerState<OfflineSyncScreen> createState() => _OfflineSyncScreenState();
}

class _OfflineSyncScreenState extends ConsumerState<OfflineSyncScreen> {
  late final TextEditingController _payloadController;

  @override
  void initState() {
    super.initState();
    _payloadController = TextEditingController(
      text:
          '{\n'
          '  "type": "profile_update",\n'
          '  "payload": {\n'
          '    "bio": "Updated while offline"\n'
          '  }\n'
          '}',
    );

    Future.microtask(() {
      final notifier = ref.read(offlineProvider.notifier);
      notifier.startMonitoring();
      notifier.check();
    });
  }

  @override
  void dispose() {
    _payloadController.dispose();
    super.dispose();
  }

  Future<void> _queueAction() async {
    FocusScope.of(context).unfocus();
    await ref
        .read(offlineProvider.notifier)
        .storeAction(payloadText: _payloadController.text);
  }

  Future<void> _checkNow() async {
    await ref.read(offlineProvider.notifier).check();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<OfflineState>(offlineProvider, (previous, next) {
      if (previous?.errorMessage != next.errorMessage &&
          next.errorMessage != null) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(next.errorMessage!)));
      }

      if (previous?.successMessage != next.successMessage &&
          next.successMessage != null) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(next.successMessage!)));
      }
    });

    final state = ref.watch(offlineProvider);
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        appBar: AppBar(title: const Text('Offline Sync')),
        body: SafeArea(
          child: RefreshIndicator(
            onRefresh: _checkNow,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                GlassCard(
                  padding: const EdgeInsets.all(16),
                  borderRadius: BorderRadius.circular(24),
                  opacity: 0.08,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          _StatusChip(
                            label: state.isOnline ? 'Online' : 'Offline',
                            icon: state.isOnline ? Icons.wifi : Icons.wifi_off,
                            color: state.isOnline
                                ? Colors.green
                                : theme.colorScheme.error,
                          ),
                          _StatusChip(
                            label:
                                '${state.queuedTasks.length} queued task${state.queuedTasks.length == 1 ? '' : 's'}',
                            icon: Icons.pending_actions_outlined,
                            color: theme.colorScheme.primary,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Queue Action Payload',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _payloadController,
                        minLines: 8,
                        maxLines: 12,
                        enabled: !state.isStoring && !state.isSyncing,
                        decoration: InputDecoration(
                          hintText: 'Enter a JSON payload to queue.',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      GalaxyButton(
                        label: 'Store Action',
                        isLoading: state.isStoring,
                        onTap: state.isStoring || state.isSyncing
                            ? null
                            : _queueAction,
                      ),
                      const SizedBox(height: 12),
                      GalaxyButton(
                        label: state.isChecking || state.isSyncing
                            ? 'Checking...'
                            : 'Check & Sync',
                        isPrimary: false,
                        isLoading: state.isChecking || state.isSyncing,
                        onTap: state.isChecking || state.isSyncing
                            ? null
                            : _checkNow,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (state.queuedTasks.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 48),
                    child: Center(
                      child: Text(
                        'No queued offline actions.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                else
                  ...state.queuedTasks.map(
                    (task) => OfflineTaskTile(task: task),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    required this.icon,
    required this.color,
  });

  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(color: color, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
