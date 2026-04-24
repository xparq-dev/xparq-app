import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:xparq_app/shared/router/app_router.dart';
import 'package:xparq_app/features/offline/providers/offline_user_provider.dart';
import 'package:xparq_app/features/offline/services/bluetooth_permission_manager.dart';
import 'package:xparq_app/features/offline/services/offline_mesh_encryption_service.dart';
import 'package:xparq_app/features/offline/services/nearby_service.dart';
import 'package:xparq_app/l10n/app_localizations.dart';
import 'package:permission_handler/permission_handler.dart';

class OfflineRadarScreen extends ConsumerStatefulWidget {
  const OfflineRadarScreen({super.key});

  @override
  ConsumerState<OfflineRadarScreen> createState() => _OfflineRadarScreenState();
}

class _OfflineRadarScreenState extends ConsumerState<OfflineRadarScreen> {
  bool _isServiceStarted = false;
  bool _isStartingService = false;
  bool _isRefreshing = false;

  Future<void> _initService(OfflineUserState user) async {
    if (_isServiceStarted || _isStartingService || user.userId.isEmpty) return;

    _isStartingService = true;
    final publicKey =
        await OfflineMeshEncryptionService.instance.getPublicKeyBase64();
    NearbyService.instance.setCurrentUser(
      user.userId,
      user.displayName,
      user.isAnonymous,
      publicKey: publicKey,
    );
    final started = await NearbyService.instance.startMesh();
    if (!mounted) return;
    setState(() {
      _isStartingService = false;
      _isServiceStarted = started;
    });
  }

  Future<void> _refreshService() async {
    setState(() => _isRefreshing = true);
    final userState = ref.read(offlineUserProvider);
    if (userState.userId.isNotEmpty) {
      final publicKey =
          await OfflineMeshEncryptionService.instance.getPublicKeyBase64();
      NearbyService.instance.setCurrentUser(
        userState.userId,
        userState.displayName,
        userState.isAnonymous,
        publicKey: publicKey,
      );
    }
    final restarted = await NearbyService.instance.restartMesh();
    _isServiceStarted = restarted;
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

    final bool isActive = NearbyService.instance.isAdvertising &&
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
          final body = Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: _MeshStatusCard(
                  peerCount: results.length,
                  isAdvertising: NearbyService.instance.isAdvertising,
                  isDiscovering: NearbyService.instance.isDiscovering,
                  isMeshStarted: _isServiceStarted,
                  onRefresh: _isRefreshing ? null : _refreshService,
                ),
              ),
              Expanded(
                child: results.isEmpty
                    ? Center(
                        child: SingleChildScrollView(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.radar_rounded,
                                size: 120,
                                color: Theme.of(
                                  context,
                                ).colorScheme.primary.withValues(alpha: 0.5),
                              ),
                              const SizedBox(height: 32),
                              Text(
                                AppLocalizations.of(
                                  context,
                                )!
                                    .offlineSearchingNeighbors,
                                style: TextStyle(
                                  color:
                                      Theme.of(context).colorScheme.onSurface,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                AppLocalizations.of(
                                  context,
                                )!
                                    .offlineEnableServices,
                                style: TextStyle(
                                  color: Theme.of(
                                    context,
                                  )
                                      .colorScheme
                                      .onSurface
                                      .withValues(alpha: 0.5),
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 48),
                              const CircularProgressIndicator(strokeWidth: 2),
                            ],
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
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
                                ).colorScheme.primary.withValues(alpha: 0.1),
                                child: const Icon(Icons.person, size: 20),
                              ),
                              title: Text(
                                displayName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Text(
                                AppLocalizations.of(
                                  context,
                                )!
                                    .offlinePeerFoundNow,
                              ),
                              trailing:
                                  const Icon(Icons.chevron_right, size: 20),
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
                      ),
              ),
            ],
          );

          return body;
        },
      ),
    );
  }
}

class _MeshStatusCard extends StatelessWidget {
  final int peerCount;
  final bool isAdvertising;
  final bool isDiscovering;
  final bool isMeshStarted;
  final Future<void> Function()? onRefresh;

  const _MeshStatusCard({
    required this.peerCount,
    required this.isAdvertising,
    required this.isDiscovering,
    required this.isMeshStarted,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: FutureBuilder<Map<Permission, PermissionStatus>>(
          future: BluetoothPermissionManager.getOfflinePermissionStatuses(),
          builder: (context, snapshot) {
            final statuses =
                snapshot.data ?? const <Permission, PermissionStatus>{};
            final permissionsOk = statuses.isNotEmpty &&
                BluetoothPermissionManager.areOfflinePermissionsGranted(
                  statuses,
                );

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Mesh status',
                      style: TextStyle(
                        color: theme.colorScheme.onSurface,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: onRefresh,
                      icon: const Icon(Icons.refresh, size: 16),
                      label: const Text('Restart mesh'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _StatusChip(
                      label: 'Permissions',
                      value: permissionsOk ? 'OK' : 'Missing',
                      isOk: permissionsOk,
                    ),
                    _StatusChip(
                      label: 'Advertising',
                      value: isAdvertising ? 'ON' : 'OFF',
                      isOk: isAdvertising,
                    ),
                    _StatusChip(
                      label: 'Discovery',
                      value: isDiscovering ? 'ON' : 'OFF',
                      isOk: isDiscovering,
                    ),
                    _StatusChip(
                      label: 'Peers',
                      value: '$peerCount',
                      isOk: peerCount > 0,
                    ),
                    _StatusChip(
                      label: 'Started',
                      value: isMeshStarted ? 'YES' : 'NO',
                      isOk: isMeshStarted,
                    ),
                  ],
                ),
                if (!permissionsOk) ...[
                  const SizedBox(height: 10),
                  Text(
                    'Permissions ยังไม่ครบ กรุณาเปิด Bluetooth, Location และ Nearby devices',
                    style: TextStyle(
                      color: theme.colorScheme.error,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final String value;
  final bool isOk;

  const _StatusChip({
    required this.label,
    required this.value,
    required this.isOk,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = isOk ? Colors.green : theme.colorScheme.error;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: RichText(
        text: TextSpan(
          style: TextStyle(
            color: theme.colorScheme.onSurface,
            fontSize: 12,
          ),
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            TextSpan(
              text: value,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
