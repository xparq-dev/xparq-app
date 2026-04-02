import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import '../services/nearby_service.dart';
import '../services/offline_chat_database.dart';
import '../providers/offline_unread_provider.dart';
import '../../../l10n/app_localizations.dart';

class OfflineChatScreen extends ConsumerStatefulWidget {
  final String peerId;
  final String peerName;
  final String endpointId;

  const OfflineChatScreen({
    super.key,
    required this.peerId,
    required this.peerName,
    required this.endpointId,
  });

  @override
  ConsumerState<OfflineChatScreen> createState() => _OfflineChatScreenState();
}

class _OfflineChatScreenState extends ConsumerState<OfflineChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<Map<String, dynamic>> _messages = [];
  bool _isSending = false;
  late StreamSubscription _messageSubscription;
  late StreamSubscription _handshakeSubscription;
  late StreamSubscription _disconnectSubscription;
  String? _effectiveEndpointId;

  @override
  void initState() {
    super.initState();
    _effectiveEndpointId = widget.endpointId;
    _markRead();
    _loadMessages();

    // 1. New Messages
    _messageSubscription = NearbyService.instance.incomingMessageStream.listen((
      data,
    ) {
      if (data['senderId'] == widget.peerId) {
        _markRead();
        _loadMessages();
      }
    });

    // 2. Handshake Successful
    _handshakeSubscription = NearbyService.instance.onHandshakeAccept.listen((
      eid,
    ) {
      // Check if this belongs to our peer
      final activePeer = NearbyService.instance.peers
          .where((p) => p.userId == widget.peerId)
          .firstOrNull;
      if (activePeer != null && activePeer.endpointId == eid) {
        if (mounted) {
          setState(() {
            _effectiveEndpointId = eid;
            _isSending = false;
          });
        }
      }
    });

    // 3. Disconnected
    _disconnectSubscription = NearbyService.instance.onDisconnected.listen((
      eid,
    ) {
      if (eid == _effectiveEndpointId) {
        if (mounted) setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _messageSubscription.cancel();
    _handshakeSubscription.cancel();
    _disconnectSubscription.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isSending) return;

    final isConnected = NearbyService.instance.connectedEndpoints.contains(
      _effectiveEndpointId,
    );

    if (!isConnected) {
      // Try to find them on Radar to re-connect
      final activePeer = NearbyService.instance.peers
          .where((p) => p.userId == widget.peerId)
          .firstOrNull;
      if (activePeer != null) {
        setState(() => _isSending = true);
        debugPrint(
          "Chat: Attempting to re-connect to ${activePeer.displayName}",
        );
        _effectiveEndpointId = activePeer.endpointId;
        await NearbyService.instance.requestConnection(activePeer.endpointId);
        // Handshake subscription in initState will clear _isSending and allow retry
        return;
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context)!.offlinePeerOffline),
            ),
          );
        }
        return;
      }
    }

    setState(() => _isSending = true);

    try {
      await NearbyService.instance.sendMessage(_effectiveEndpointId!, text);

      // Optimistically save to DB and UI
      await OfflineChatDatabase.instance.insertMessage(
        peerId: widget.peerId,
        peerName: widget.peerName,
        message: text,
        isMe: true,
      );

      if (mounted) {
        _messageController.clear();
        _loadMessages();
        setState(() => _isSending = false);
      }
    } catch (e) {
      debugPrint("Chat: Failed to send: $e");
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isConnected = NearbyService.instance.connectedEndpoints.contains(
      _effectiveEndpointId,
    );

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.peerName),
            Text(
              isConnected
                  ? AppLocalizations.of(context)!.offlineConnectedMesh
                  : AppLocalizations.of(context)!.offlineDisconnected,
              style: TextStyle(
                fontSize: 10,
                color: isConnected ? Colors.greenAccent : Colors.orangeAccent,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                final isMe = msg['isMe'] == 1;

                return Align(
                  alignment: isMe
                      ? AlignmentDirectional.centerEnd
                      : AlignmentDirectional.centerStart,
                  child: Container(
                    margin: EdgeInsetsDirectional.only(
                      bottom: 8,
                      end: isMe ? 0 : 20,
                      start: isMe ? 20 : 0,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: isMe
                          ? Colors.blueAccent
                          : Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(20).copyWith(
                        bottomRight: isMe
                            ? const Radius.circular(0)
                            : const Radius.circular(20),
                        bottomLeft: isMe
                            ? const Radius.circular(20)
                            : const Radius.circular(0),
                      ),
                    ),
                    child: Text(
                      msg['message'],
                      style: TextStyle(
                        color: isMe
                            ? Colors.white
                            : Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          SafeArea(
            bottom: true,
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      decoration: InputDecoration(
                        hintText: AppLocalizations.of(
                          context,
                        )!.offlineTypeMessage,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(25),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Theme.of(context).cardColor,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 10,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _isSending ? null : _sendMessage,
                    icon: _isSending
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.send),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _loadMessages() async {
    final messages = await OfflineChatDatabase.instance.getMessages(
      widget.peerId,
    );
    if (mounted) {
      setState(() {
        _messages = messages;
      });
      _scrollToBottom();
    }
  }

  void _markRead() {
    ref.read(offlineUnreadCountProvider.notifier).markAsRead(widget.peerId);
  }
}
