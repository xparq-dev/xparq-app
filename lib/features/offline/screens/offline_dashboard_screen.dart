import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'dart:async';
import 'dart:convert';
import '../services/nearby_service.dart';
import '../services/offline_chat_database.dart';
import '../services/offline_notification_service.dart';
import '../providers/offline_unread_provider.dart';
import '../../../l10n/app_localizations.dart';

class OfflineAppShell extends ConsumerStatefulWidget {
  final StatefulNavigationShell navigationShell;

  const OfflineAppShell({super.key, required this.navigationShell});

  @override
  ConsumerState<OfflineAppShell> createState() => _OfflineAppShellState();
}

class _OfflineAppShellState extends ConsumerState<OfflineAppShell> {
  late StreamSubscription _connectionInitiatedSub;
  late StreamSubscription _connectionResultSub;
  late StreamSubscription _messageSub;

  @override
  void initState() {
    super.initState();
    OfflineNotificationService.instance.init();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Wait a short moment to ensure everything is mounted, though NearbyService handles its own state
      // We start Advertising and Discovery implicitly when entering radar,
      // but let's make sure our user data is set in the service if needed.
    });

    // Listen for incoming connection requests (someone tapped "Add Peer")
    _connectionInitiatedSub = NearbyService.instance.onConnectionInitiated
        .listen((event) {
          _handleIncomingConnection(event.endpointId, event.connectionInfo);
        });

    // Listen for results (accepted/rejected)
    _connectionResultSub = NearbyService.instance.onConnectionResult.listen((
      event,
    ) {
      if (event.status.name == 'CONNECTED') {
        // Find who this is by endpointId
        final l10n = mounted ? AppLocalizations.of(context) : null;
        final peer =
            NearbyService.instance.peers
                .where((p) => p.endpointId == event.endpointId)
                .firstOrNull ??
            NearbyPeer(
              endpointId: event.endpointId,
              userId: event.endpointId,
              isAnonymous: true,
              discoveredAt: DateTime.now(),
              displayName: l10n?.offlineUnknownPeer ?? 'Unknown Peer',
            );

        // Automatically add them as a friend in DB if not already
        OfflineChatDatabase.instance.addFriend(peer.userId, peer.displayName);
      }
    });

    // Listen for incoming messages to show Notifications
    _messageSub = NearbyService.instance.incomingMessageStream.listen((data) {
      _handleIncomingMessage(data);
    });
  }

  void _handleIncomingMessage(Map<String, dynamic> data) {
    // Refresh unread count
    ref.read(offlineUnreadCountProvider.notifier).refresh();

    _showNotification(data);
  }

  void _showNotification(Map<String, dynamic> data) {
    final location = GoRouterState.of(context).matchedLocation;
    final senderId = data['senderId'] as String;
    final text = data['text'] as String;

    // Don't show if active in that chat
    final bool inSpecificChat = location == '/offline/chat';

    if (inSpecificChat) return;

    final peer = NearbyService.instance.peers
        .where((p) => p.userId == senderId)
        .firstOrNull;
    final String senderName = (peer?.isAnonymous ?? false)
        ? AppLocalizations.of(context)!.offlineStayAnonymous
        : (peer?.displayName ??
              AppLocalizations.of(context)!.offlineUnknownPeer);

    // 1. Show Minimal In-app notification
    if (mounted) {
      OfflineNotificationService.instance.showInAppNotification(
        context,
        title: senderName,
        body: text,
        onTap: () {
          context.push(
            '/offline/chat',
            extra: {
              'peerId': senderId,
              'peerName': senderName,
              'endpointId': peer?.endpointId ?? '',
            },
          );
        },
      );
    }

    // 2. Show System Notification (if backgrounded or just for backup)
    OfflineNotificationService.instance.showSystemNotification(
      title: senderName,
      body: text,
      payload: senderId,
    );
  }

  void _handleIncomingConnection(String endpointId, dynamic info) async {
    String peerName = AppLocalizations.of(context)!.offlineUnknownPeer;
    String peerUserId = endpointId;

    try {
      final rawName = info.endpointName as String;
      int startIndex = rawName.indexOf('{');
      int endIndex = rawName.lastIndexOf('}');
      if (startIndex != -1 && endIndex != -1) {
        final jsonStr = rawName.substring(startIndex, endIndex + 1);
        final payload = json.decode(jsonStr);
        final l10n = mounted ? AppLocalizations.of(context) : null;
        peerUserId = payload['id'] ?? endpointId;
        peerName =
            payload['name'] ?? l10n?.offlineUnknownPeer ?? 'Unknown Peer';
        if (peerName.isEmpty) {
          peerName = l10n?.offlineUnknownPeer ?? 'Unknown Peer';
        }
      } else {
        peerName = rawName;
      }
    } catch (e) {
      debugPrint("Nearby Shell: Failed to parse incoming info: $e");
    }

    // Check if we are already friends to avoid spamming
    final isAlreadyFriend = await OfflineChatDatabase.instance.isFriend(
      peerUserId,
    );

    if (isAlreadyFriend) {
      debugPrint("Nearby Shell: Auto-accepting friend $peerName ($peerUserId)");
      NearbyService.instance.acceptConnection(endpointId);

      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.offlineReconnected(peerName)),
            backgroundColor: Colors.blueAccent.withOpacity(0.8),
            duration: const Duration(seconds: 1),
          ),
        );
      }
      return;
    }

    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Theme.of(context).dialogTheme.backgroundColor,
          title: Text(AppLocalizations.of(context)!.offlineConnectionRequest),
          content: Text(
            AppLocalizations.of(
              context,
            )!.offlineConnectionRequestDesc(peerName),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                NearbyService.instance.rejectConnection(endpointId);
              },
              child: Text(
                AppLocalizations.of(context)!.offlineDecline,
                style: const TextStyle(color: Colors.red),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                // Broadcast accept signal
                await NearbyService.instance.acceptConnection(endpointId);

                // Save to friend DB
                await OfflineChatDatabase.instance.addFriend(
                  peerUserId,
                  peerName,
                );

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        AppLocalizations.of(
                          context,
                        )!.offlineAddedPeer(peerName),
                      ),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child: Text(AppLocalizations.of(context)!.offlineAccept),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _connectionInitiatedSub.cancel();
    _connectionResultSub.cancel();
    _messageSub.cancel();
    NearbyService.instance.disconnectAll();
    NearbyService.instance.stopAdvertising();
    NearbyService.instance.stopDiscovery();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = ref.watch(offlineUnreadCountProvider);

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: widget.navigationShell,
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          color: Theme.of(context).bottomNavigationBarTheme.backgroundColor,
          border: Border(
            top: BorderSide(
              color: context.mounted
                  ? Theme.of(
                      context,
                    ).colorScheme.onSurface.withOpacity(0.08)
                  : Colors.transparent, // Fallback if context is not mounted
            ),
          ),
        ),
        child: SafeArea(
          child: BottomNavigationBar(
            currentIndex: widget.navigationShell.currentIndex,
            onTap: (index) => widget.navigationShell.goBranch(
              index,
              initialLocation: index == widget.navigationShell.currentIndex,
            ),
            backgroundColor: Colors.transparent,
            elevation: 0,
            selectedItemColor: Theme.of(context).colorScheme.primary,
            unselectedItemColor: Theme.of(
              context,
            ).bottomNavigationBarTheme.unselectedItemColor,
            type: BottomNavigationBarType.fixed,
            showSelectedLabels: false,
            showUnselectedLabels: false,
            iconSize: 26,
            items: [
              BottomNavigationBarItem(
                icon: const Icon(Icons.radar),
                label: AppLocalizations.of(context)!.radarTab,
              ),
              BottomNavigationBarItem(
                icon: Badge(
                  label: Text(unreadCount.toString()),
                  isLabelVisible: unreadCount > 0,
                  child: const Icon(Icons.chat_bubble_outline),
                ),
                label: AppLocalizations.of(context)!.signalTab,
              ),
              BottomNavigationBarItem(
                icon: const Icon(Icons.person_outline),
                label: AppLocalizations.of(context)!.planetTab,
              ),
              BottomNavigationBarItem(
                icon: const Icon(Icons.settings_outlined),
                label: AppLocalizations.of(context)!.settingsTitle,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
