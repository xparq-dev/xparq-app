import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'dart:async';
import 'package:intl/intl.dart';
import 'package:xparq_app/l10n/app_localizations.dart';
import 'package:xparq_app/features/offline/services/offline_chat_database.dart';
import 'package:xparq_app/features/offline/services/nearby_service.dart';

class OfflineSignalScreen extends ConsumerStatefulWidget {
  const OfflineSignalScreen({super.key});

  @override
  ConsumerState<OfflineSignalScreen> createState() =>
      _OfflineSignalScreenState();
}

class _OfflineSignalScreenState extends ConsumerState<OfflineSignalScreen> {
  List<Map<String, dynamic>> _chats = [];
  bool _isLoading = true;
  StreamSubscription? _peersSubscription;
  StreamSubscription? _msgSubscription;
  bool _routeIsActive = false;

  @override
  void initState() {
    super.initState();
    _refreshChats();

    // Listen for peer changes to update Online/Offline status reactively
    _peersSubscription = NearbyService.instance.incomingPeersStream.listen((_) {
      if (mounted) setState(() {});
    });

    // Listen for new messages to refresh the chat list (newest on top)
    _msgSubscription = NearbyService.instance.incomingMessageStream.listen((_) {
      _refreshChats();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Refresh whenever this screen becomes the top route (e.g. after returning from chat)
    final route = ModalRoute.of(context);
    final nowActive = route?.isCurrent ?? false;
    if (nowActive && !_routeIsActive) {
      _refreshChats();
    }
    _routeIsActive = nowActive;
  }

  @override
  void dispose() {
    _peersSubscription?.cancel();
    _msgSubscription?.cancel();
    super.dispose();
  }

  Future<void> _refreshChats() async {
    final chats = await OfflineChatDatabase.instance.getRecentChats();
    if (mounted) {
      setState(() {
        _chats = chats;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.offlineSignalTitle),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep_outlined),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text(
                    AppLocalizations.of(context)!.offlineClearConfirmTitle,
                  ),
                  content: Text(
                    AppLocalizations.of(context)!.offlineClearConfirmDesc,
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: Text(
                        AppLocalizations.of(context)!.offlineClear,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              );
              if (confirm == true) {
                await OfflineChatDatabase.instance.clearAllHistory();
                _refreshChats();
              }
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _chats.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.chat_bubble_outline,
                    size: 48,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.2),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    AppLocalizations.of(context)!.offlineNoSignals,
                    style: TextStyle(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _chats.length,
              itemBuilder: (context, index) {
                final chat = _chats[index];
                final peerId = chat['peerId'] as String;
                final peerName = chat['peerName'] as String;
                final lastTime = chat['lastMessageTime'] as int;

                final date = DateTime.fromMillisecondsSinceEpoch(lastTime);
                final timeStr = DateFormat.jm().format(date);

                // Check if peer is currently on radar
                final activePeers = NearbyService.instance.peers;
                final activePeer =
                    activePeers.where((p) => p.userId == peerId).firstOrNull ??
                    activePeers
                        .where((p) => p.endpointId == peerId)
                        .firstOrNull;

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: ListTile(
                    leading: Stack(
                      children: [
                        const CircleAvatar(
                          backgroundColor: Colors.blueAccent,
                          child: Icon(Icons.person, color: Colors.white),
                        ),
                        if (activePeer != null)
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: Colors.green,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Theme.of(context).cardColor,
                                  width: 2,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    title: Text(
                      peerName,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      AppLocalizations.of(
                        context,
                      )!.offlineLastSignalAt(timeStr),
                    ),
                    trailing: activePeer != null
                        ? const Icon(
                            Icons.chevron_right,
                            color: Colors.blueAccent,
                          )
                        : Icon(
                            Icons.cloud_off,
                            size: 16,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withValues(alpha: 0.2),
                          ),
                    onTap: () {
                      if (activePeer != null) {
                        context.push(
                          '/offline/chat',
                          extra: {
                            'endpointId': activePeer.endpointId,
                            'peerId': activePeer.userId,
                            'peerName': activePeer.displayName,
                          },
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              AppLocalizations.of(
                                context,
                              )!.offlinePeerUnavailable,
                            ),
                          ),
                        );
                      }
                    },
                  ),
                );
              },
            ),
    );
  }
}
