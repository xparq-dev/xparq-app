import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:xparq_app/features/offline/services/nearby_service.dart';
import 'package:xparq_app/features/offline/services/offline_chat_database.dart';

class OfflineOtherProfileScreen extends ConsumerStatefulWidget {
  final String peerId;
  final String displayName;
  final String endpointId;

  const OfflineOtherProfileScreen({
    super.key,
    required this.peerId,
    required this.displayName,
    required this.endpointId, // Required for GNC
  });

  @override
  ConsumerState<OfflineOtherProfileScreen> createState() =>
      _OfflineOtherProfileScreenState();
}

class _OfflineOtherProfileScreenState
    extends ConsumerState<OfflineOtherProfileScreen> {
  bool _isFriend = false;
  bool _isRequesting = false;
  late StreamSubscription _acceptSubscription;

  @override
  void initState() {
    super.initState();
    _checkFriendStatus();

    // Listen to handshake acceptance
    _acceptSubscription = NearbyService.instance.onHandshakeAccept.listen((
      acceptedEndpointId,
    ) async {
      if (acceptedEndpointId == widget.endpointId) {
        // Handshake succeeded!
        await OfflineChatDatabase.instance.addFriend(
          widget.peerId,
          widget.displayName,
        );
        if (mounted) {
          setState(() {
            _isFriend = true;
            _isRequesting = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${widget.displayName} accepted your request!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    });
  }

  @override
  void dispose() {
    _acceptSubscription.cancel();
    super.dispose();
  }

  Future<void> _checkFriendStatus() async {
    final status = await OfflineChatDatabase.instance.isFriend(widget.peerId);
    if (mounted) {
      setState(() {
        _isFriend = status;
      });
    }
  }

  Future<void> _sendFriendRequest(String targetEndpointId) async {
    setState(() {
      _isRequesting = true;
    });

    // Fire off the connection request
    await NearbyService.instance.requestConnection(targetEndpointId);

    if (mounted) {
      setState(() {
        _isRequesting =
            false; // Note: Waiting for response happens in background
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Friend request sent! Waiting for response...'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<NearbyPeer>>(
      stream: NearbyService.instance.incomingPeersStream,
      initialData: const [],
      builder: (context, snapshot) {
        final peers = snapshot.data ?? [];
        final activePeer = peers
            .where((p) => p.userId == widget.peerId)
            .firstOrNull;
        final isOnline = activePeer != null;

        // Use updated endpointId if they re-discovered, else fallback to initial
        final currentEndpointId = activePeer?.endpointId ?? widget.endpointId;

        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: AppBar(
            title: const Text('Offline Planet'),
            backgroundColor: Colors.transparent,
            elevation: 0,
          ),
          body: SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 40),
                // Planet visual
                Center(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 220,
                        height: 220,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: _isFriend
                                  ? Colors.greenAccent.withValues(alpha: 0.3)
                                  : Colors.blueAccent.withValues(alpha: 0.3),
                              blurRadius: 100,
                              spreadRadius: 10,
                            ),
                          ],
                        ),
                      ),
                      Container(
                        width: 180,
                        height: 180,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors:
                                Theme.of(context).brightness == Brightness.dark
                                ? (_isFriend
                                      ? [
                                          const Color(0xFF1B3B26),
                                          const Color(0xFF41775A),
                                        ]
                                      : [
                                          const Color(0xFF1B263B),
                                          const Color(0xFF415A77),
                                        ])
                                : (_isFriend
                                      ? [
                                          const Color(0xFFE8F5E9),
                                          const Color(0xFFA5D6A7),
                                        ]
                                      : [
                                          const Color(0xFFE3F2FD),
                                          const Color(0xFF90CAF9),
                                        ]),
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: Icon(
                          _isFriend ? Icons.handshake : Icons.public,
                          size: _isFriend ? 80 : 100,
                          color: Colors.white24,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  widget.displayName,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: isOnline ? Colors.green : Colors.grey,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isOnline ? 'Online via Mesh' : 'Offline / Out of Range',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 40),
                // Action buttons
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      if (_isFriend) ...[
                        // CHAT button - Shown only if friends
                        Builder(
                          builder: (context) {
                            final isConnected = NearbyService
                                .instance
                                .connectedEndpoints
                                .contains(currentEndpointId);

                            return ElevatedButton.icon(
                              onPressed: isOnline && !_isRequesting
                                  ? () async {
                                      if (isConnected) {
                                        context.push(
                                          '/offline/chat',
                                          extra: {
                                            'peerId': widget.peerId,
                                            'peerName': widget.displayName,
                                            'endpointId': currentEndpointId,
                                          },
                                        );
                                      } else {
                                        setState(() => _isRequesting = true);
                                        await NearbyService.instance
                                            .requestConnection(
                                              currentEndpointId,
                                            );
                                        // The listener in initState will handle the transition once accepted
                                      }
                                    }
                                  : null,
                              icon: _isRequesting
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Icon(
                                      isConnected
                                          ? Icons.chat_bubble_outline
                                          : Icons.link,
                                    ),
                              label: Text(
                                _isRequesting
                                    ? 'Connecting...'
                                    : (isConnected
                                          ? 'Send Signal (Chat)'
                                          : 'Connect to Peer'),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isConnected
                                    ? Colors.blueAccent
                                    : Colors.orangeAccent,
                                foregroundColor: Colors.white,
                                disabledBackgroundColor: Colors.grey.withValues(alpha: 
                                  0.3,
                                ),
                                minimumSize: const Size(double.infinity, 50),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            );
                          },
                        ),
                        if (!isOnline) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Peer must be online to connect.',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.4),
                              fontSize: 12,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ] else ...[
                        // REQUEST FRIEND button - Shown if not friends
                        ElevatedButton.icon(
                          onPressed: isOnline && !_isRequesting
                              ? () => _sendFriendRequest(currentEndpointId)
                              : null,
                          icon: _isRequesting
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.person_add),
                          label: Text(
                            _isRequesting
                                ? 'Sending Request...'
                                : 'Add Peer (Handshake)',
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: Colors.green.withValues(alpha: 
                              0.3,
                            ),
                            minimumSize: const Size(double.infinity, 50),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                        if (!isOnline) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Peer must be online to add as friend.',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.4),
                              fontSize: 12,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.all(40.0),
                  child: Text(
                    _isFriend
                        ? 'You are now connected with this peer. You can send explicit signals and chat while in proximity offline.'
                        : 'This planet is discovered through the offline mesh. You must add them as a peer to initiate contact.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.38),
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
