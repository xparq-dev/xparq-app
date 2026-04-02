import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:xparq_app/core/router/app_router.dart';
import 'package:xparq_app/features/offline/providers/offline_user_provider.dart';
import 'package:xparq_app/features/offline/services/nearby_service.dart';
import 'package:xparq_app/l10n/app_localizations.dart';

class OfflineRadarScreen extends ConsumerStatefulWidget {
  const OfflineRadarScreen({super.key});

  @override
  ConsumerState<OfflineRadarScreen> createState() => _OfflineRadarScreenState();
}

class _OfflineRadarScreenState extends ConsumerState<OfflineRadarScreen> {
  bool _isServiceStarted = false;
  bool _isRefreshing = false;

  void _initService(OfflineUserState user) {
    if (_isServiceStarted || user.userId.isEmpty) return;

    _isServiceStarted = true;
    NearbyService.instance.setCurrentUser(
      user.userId,
      user.displayName,
      user.isAnonymous,
    );
    NearbyService.instance.startDiscovery();
    NearbyService.instance.startAdvertising();
  }

  Future<void> _refreshService() async {
    setState(() => _isRefreshing = true);
    await NearbyService.instance.resetAll();
    _isServiceStarted = false;
    // The next build will re-trigger _initService
    setState(() => _isRefreshing = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.offlineMeshStarted),
        ),
      );
    }
  }

  @override
  void dispose() {
    // Keep services running so people can find us while switching tabs,
    // but the AppShell handles global lifecycle.
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userState = ref.watch(offlineUserProvider);

    // Trigger initialization when data is ready
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _initService(userState),
    );

    final bool isActive =
        NearbyService.instance.isAdvertising &&
        NearbyService.instance.isDiscovering;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Column(
          children: [
            Text(AppLocalizations.of(context)!.offlineRadarTitle),
            Text(
              isActive
                  ? AppLocalizations.of(context)!.offlineMeshActive
                  : AppLocalizations.of(context)!.offlineConnecting,
              style: TextStyle(
                fontSize: 10,
                color: isActive ? Colors.greenAccent : Colors.orangeAccent,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: _isRefreshing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
            onPressed: _isRefreshing ? null : _refreshService,
          ),
        ],
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: StreamBuilder<List<NearbyPeer>>(
        stream: NearbyService.instance.incomingPeersStream,
        initialData: const [],
        builder: (context, snapshot) {
          final results = snapshot.data ?? [];

          if (results.isEmpty) {
            return Center(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.radar_rounded,
                      size: 120,
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withOpacity(0.5),
                    ),
                    const SizedBox(height: 32),
                    Text(
                      AppLocalizations.of(context)!.offlineSearchingNeighbors,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      AppLocalizations.of(context)!.offlineEnableServices,
                      style: TextStyle(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withOpacity(0.5),
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 48),
                    const CircularProgressIndicator(strokeWidth: 2),
                  ],
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: results.length,
            itemBuilder: (context, index) {
              final peer = results[index];
              final displayName = peer.displayName;

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.primary.withOpacity(0.1),
                    child: const Icon(Icons.person, size: 20),
                  ),
                  title: Text(
                    displayName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    AppLocalizations.of(context)!.offlinePeerFoundNow,
                  ),
                  trailing: const Icon(Icons.chevron_right, size: 20),
                  onTap: () {
                    context.push(
                      AppRoutes.offlineChat,
                      extra: {
                        'peerId': peer.userId,
                        'peerName': displayName,
                        'endpointId': peer.endpointId,
                      },
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
