import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import '../services/nearby_service.dart';
import '../services/offline_chat_database.dart';
import '../providers/offline_unread_provider.dart';
import '../screens/offline_dashboard_screen.dart';
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
  bool _isConnecting = false;
  late StreamSubscription _messageSubscription;
  late StreamSubscription _handshakeSubscription;
  late StreamSubscription _disconnectSubscription;
  String? _effectiveEndpointId;
  Completer<void>? _pendingConnectionCompleter;

  @override
  void initState() {
    super.initState();
    _effectiveEndpointId = widget.endpointId;
    _markRead();
    _loadMessages();

    // Update shell with current chat peer ID to prevent notifications
    WidgetsBinding.instance.addPostFrameCallback((_) {
      OfflineAppShell.setCurrentChatPeerId(context, widget.peerId);
      _attemptAutoConnect();
    });

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
        _pendingConnectionCompleter?.complete();
        _pendingConnectionCompleter = null;
        if (mounted) {
          setState(() {
            _effectiveEndpointId = eid;
            _isConnecting = false;
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
        _pendingConnectionCompleter?.complete();
        _pendingConnectionCompleter = null;
        if (mounted) {
          setState(() {
            _isConnecting = false;
            _isSending = false;
          });
        }
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

    // Clear current chat peer ID to allow notifications again
    WidgetsBinding.instance.addPostFrameCallback((_) {
      OfflineAppShell.setCurrentChatPeerId(context, null);
    });

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
    if (text.isEmpty || _isSending || _isConnecting) return;

    final isConnected = await _ensureConnected(showOfflineNotice: true);
    if (!isConnected) {
      if (mounted) setState(() => _isSending = false);
      return;
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

  Future<void> _attemptAutoConnect() async {
    await _ensureConnected(showOfflineNotice: false);
  }

  Future<bool> _ensureConnected({required bool showOfflineNotice}) async {
    if (_effectiveEndpointId != null &&
        NearbyService.instance.connectedEndpoints.contains(
          _effectiveEndpointId,
        )) {
      return true;
    }

    final activePeer = NearbyService.instance.peers
        .where((p) => p.userId == widget.peerId)
        .firstOrNull;

    if (activePeer == null) {
      if (showOfflineNotice && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.offlinePeerOffline),
          ),
        );
      }
      return false;
    }

    _effectiveEndpointId = activePeer.endpointId;

    if (_pendingConnectionCompleter != null) {
      try {
        await _pendingConnectionCompleter!.future.timeout(
          const Duration(seconds: 4),
        );
      } catch (_) {}
      return NearbyService.instance.connectedEndpoints.contains(
        _effectiveEndpointId,
      );
    }

    _pendingConnectionCompleter = Completer<void>();
    if (mounted) {
      setState(() {
        _isConnecting = true;
      });
    }

    debugPrint("Chat: Attempting to connect to ${activePeer.displayName}");
    await NearbyService.instance.requestConnection(activePeer.endpointId);

    try {
      await _pendingConnectionCompleter!.future.timeout(
        const Duration(seconds: 4),
      );
    } catch (_) {
      _pendingConnectionCompleter = null;
    }

    final connected = NearbyService.instance.connectedEndpoints.contains(
      _effectiveEndpointId,
    );

    if (mounted) {
      setState(() {
        _isConnecting = false;
      });
    }

    return connected;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isConnected = NearbyService.instance.connectedEndpoints.contains(
      _effectiveEndpointId,
    );
    final statusColor = isConnected
        ? (Theme.of(context).brightness == Brightness.dark
            ? Colors.greenAccent
            : Colors.green.shade700)
        : (Theme.of(context).brightness == Brightness.dark
            ? Colors.orangeAccent
            : Colors.orange.shade800);

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
                color: statusColor,
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
                      style: TextStyle(
                        color: scheme.onSurface,
                      ),
                      cursorColor: scheme.primary,
                      decoration: InputDecoration(
                        hintText: AppLocalizations.of(
                          context,
                        )!
                            .offlineTypeMessage,
                        hintStyle: TextStyle(
                          color: scheme.onSurface.withValues(alpha: 0.55),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(25),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: scheme.surfaceContainerHighest,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 10,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed:
                        (_isSending || _isConnecting) ? null : _sendMessage,
                    icon: (_isSending || _isConnecting)
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
