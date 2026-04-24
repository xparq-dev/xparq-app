import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'dart:async';
import 'dart:convert';
import '../services/nearby_service.dart';
import '../services/offline_chat_database.dart';
import '../services/offline_notification_service.dart';
import '../providers/offline_unread_provider.dart';
import '../providers/offline_friends_provider.dart';
import '../../../l10n/app_localizations.dart';

class OfflineAppShell extends ConsumerStatefulWidget {
  final StatefulNavigationShell navigationShell;

  const OfflineAppShell({super.key, required this.navigationShell});

  @override
  ConsumerState<OfflineAppShell> createState() => _OfflineAppShellState();

  static void setCurrentChatPeerId(BuildContext context, String? peerId) {
    final shell = context.findAncestorStateOfType<_OfflineAppShellState>();
    shell?.setCurrentChatPeerId(peerId);
  }
}

class _OfflineAppShellState extends ConsumerState<OfflineAppShell> {
  late StreamSubscription _connectionInitiatedSub;
  late StreamSubscription _connectionResultSub;
  late StreamSubscription _messageSub;
  String? _currentChatPeerId; // Track current chat peer ID

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
    _connectionInitiatedSub =
        NearbyService.instance.onConnectionInitiated.listen((event) {
      _handleIncomingConnection(event.endpointId, event.connectionInfo);
    });

    // Listen for results (accepted/rejected)
    _connectionResultSub = NearbyService.instance.onConnectionResult.listen((
      event,
    ) {
      if (event.status.name == 'CONNECTED') {
        // Find who this is by endpointId
        final l10n = mounted ? AppLocalizations.of(context) : null;
        final peer = NearbyService.instance.peers
                .where((p) => p.endpointId == event.endpointId)
                .firstOrNull ??
            NearbyPeer(
              endpointId: event.endpointId,
              userId: event.endpointId,
              isAnonymous: true,
              publicKey: null,
              discoveredAt: DateTime.now(),
              displayName: l10n?.offlineUnknownPeer ?? 'Unknown Peer',
            );

        // Add through provider so UI updates immediately (includes publicKey)
        ref.read(offlineFriendsProvider.notifier).addFriend(
          peer.userId,
          peer.displayName,
          publicKey: peer.publicKey,
        );
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
    final senderId = data['senderId'] as String;
    final text = data['text'] as String;
    final lifecycleState = WidgetsBinding.instance.lifecycleState;
    final isForeground =
        lifecycleState == null || lifecycleState == AppLifecycleState.resumed;

    // Don't show if active in chat with this specific peer
    final bool inSpecificChat = _currentChatPeerId == senderId;

    if (inSpecificChat) return;

    final peer = NearbyService.instance.peers
        .where((p) => p.userId == senderId)
        .firstOrNull;
    final String senderName = (peer?.isAnonymous ?? false)
        ? AppLocalizations.of(context)!.offlineStayAnonymous
        : (peer?.displayName ??
            AppLocalizations.of(context)!.offlineUnknownPeer);

    // Show the in-app banner only while the app is actively on screen.
    if (mounted && isForeground) {
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

    if (!isForeground) {
      OfflineNotificationService.instance.showSystemNotification(
        title: senderName,
        body: text,
        payload: senderId,
      );
    }
  }

  void setCurrentChatPeerId(String? peerId) {
    _currentChatPeerId = peerId;
  }

  void _handleIncomingConnection(String endpointId, dynamic info) async {
    String peerName = AppLocalizations.of(context)!.offlineUnknownPeer;
    String peerUserId = endpointId;
    String? peerPublicKey;
    final lifecycleState = WidgetsBinding.instance.lifecycleState;
    final isForeground =
        lifecycleState == null || lifecycleState == AppLifecycleState.resumed;

    try {
      final rawName = info.endpointName as String;
      int startIndex = rawName.indexOf('{');
      int endIndex = rawName.lastIndexOf('}');
      if (startIndex != -1 && endIndex != -1) {
        final jsonStr = rawName.substring(startIndex, endIndex + 1);
        final payload = json.decode(jsonStr);
        final marker = '${payload['a'] ?? payload['app'] ?? ''}'.trim();
        if (marker != 'xq1') {
          debugPrint(
            "Nearby Shell: Ignoring foreign app connection request -> '$marker'",
          );
          return;
        }
        final l10n = mounted ? AppLocalizations.of(context) : null;
        peerUserId = payload['i'] ?? payload['id'] ?? endpointId;
        peerName = payload['n'] ??
            payload['name'] ??
            l10n?.offlineUnknownPeer ??
            'Unknown Peer';
        peerPublicKey = (payload['p'] ?? payload['pub']) as String?;
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
            backgroundColor: Colors.blueAccent.withValues(alpha: 0.8),
            duration: const Duration(seconds: 1),
          ),
        );
      }
      return;
    }

    if (!mounted) return;

    if (mounted && isForeground) {
      OfflineNotificationService.instance.showInAppNotification(
        context,
        title: AppLocalizations.of(context)!.offlineConnectionRequest,
        body: AppLocalizations.of(context)!
            .offlineConnectionRequestDesc(peerName),
        onTap: () async {
          // Accept connection
          await NearbyService.instance.acceptConnection(endpointId);
          // Add through provider so friends list UI updates immediately
          await ref.read(offlineFriendsProvider.notifier).addFriend(
            peerUserId,
            peerName,
            publicKey: peerPublicKey,
          );

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                    AppLocalizations.of(context)!.offlineAddedPeer(peerName)),
                backgroundColor: Colors.green,
              ),
            );
          }
        },
        onDismiss: () {
          // Reject connection on dismiss
          NearbyService.instance.rejectConnection(endpointId);
        },
      );
    } else {
      OfflineNotificationService.instance.showSystemNotification(
        title: AppLocalizations.of(context)!.offlineConnectionRequest,
        body: AppLocalizations.of(context)!.offlineConnectionRequestDesc(
          peerName,
        ),
        payload: peerUserId,
      );
    }
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
                    ).colorScheme.onSurface.withValues(alpha: 0.08)
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
