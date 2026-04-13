import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart';
import 'package:xparq_app/shared/enums/age_group.dart';
import 'package:xparq_app/l10n/app_localizations.dart';
import 'package:xparq_app/features/auth/providers/auth_providers.dart';
import 'package:xparq_app/features/chat/domain/models/chat_model.dart';
import 'package:xparq_app/features/chat/presentation/providers/chat_providers.dart';
import 'package:xparq_app/features/chat/presentation/providers/reaction_controller.dart';
import 'package:xparq_app/features/chat/data/services/signal/encrypted_image_widget.dart';
import 'mini_profile_popup.dart';

class MessageBubble extends ConsumerStatefulWidget {
  final MessageModel message;
  final bool isMe;
  final String chatId;
  final AgeGroup callerAgeGroup;
  final String otherUid;
  final bool isPinned;
  final void Function(MessageModel)? onReply;
  final VoidCallback? onPlanetTap;
  final void Function(Offset globalPosition, MessageModel message)? onLongPress;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isMe,
    required this.chatId,
    required this.callerAgeGroup,
    required this.otherUid,
    this.isPinned = false,
    this.onReply,
    this.onPlanetTap,
    this.onLongPress,
  });

  @override
  ConsumerState<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends ConsumerState<MessageBubble>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  bool _isRevealed = false; // For NSFW blur toggle
  static final DateFormat _timeFormatter = DateFormat('HH:mm');
  Timer? _longPressTimer;
  Offset? _lastTapDownPosition;
  
  // Interaction state
  int _tapCount = 0;
  Timer? _tapResetTimer;
  bool _isRushing = false;
  Timer? _stopRushTimer;
  Timer? _rushPeriodicTimer;

  @override
  void didUpdateWidget(covariant MessageBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Listen for reaction changes (Real-time sync)
    final hasChanges = !mapEquals(widget.message.reactions, oldWidget.message.reactions);
    
    if (hasChanges) {
      debugPrint('[REACTION_DEBUG] Reactions changed for message ${widget.message.messageId}');
      debugPrint('[REACTION_DEBUG] Old: ${oldWidget.message.reactions}');
      debugPrint('[REACTION_DEBUG] New: ${widget.message.reactions}');
      _checkForRemoteReactions(oldWidget.message.reactions);
    }
  }

  void _checkForRemoteReactions(Map<String, String> oldReactions) {
    final myUid = ref.read(authRepositoryProvider).currentUser?.id;
    final currentReactions = widget.message.reactions;

    debugPrint('[REACTION_DEBUG] Checking for remote reactions. MyUID: $myUid');

    for (var entry in currentReactions.entries) {
      final userId = entry.key;
      final emoji = entry.value;

      if (userId != myUid && (!oldReactions.containsKey(userId) || oldReactions[userId] != emoji)) {
        _triggerRemoteAnimation(emoji);
      }
    }
  }

  void _triggerRemoteAnimation(String emoji) {
    if (!mounted) return;
    
    // Use addPostFrameCallback to ensure the build phase is completely finished.
    // This is the safest way to trigger animations and update overlay state.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      
      final RenderBox? box = context.findRenderObject() as RenderBox?;
      if (box == null || !box.hasSize) return;

      final center = box.localToGlobal(Offset(box.size.width / 2, box.size.height / 2));
      final type = emoji == '❤️' ? ReactionType.heart : ReactionType.spark;
      
      ref.read(reactionControllerProvider.notifier).addReaction(center, type);
    });
  }

  Future<void> _togglePin() async {
    try {
      final repo = ref.read(chatRepositoryProvider);
      final chats = ref.read(myChatsProvider).valueOrNull ?? [];
      final chat = chats.firstWhere((c) => c.chatId == widget.chatId);
      final newPins = List<String>.from(chat.pinnedMessages);

      if (widget.isPinned) {
        newPins.remove(widget.message.messageId);
      } else {
        newPins.add(widget.message.messageId);
      }

      await repo.updatePinnedMessages(widget.chatId, newPins);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to update pin: $e')));
      }
    }
  }

  Future<void> _toggleSpark({String? emoji}) async {
    try {
      final repo = ref.read(chatRepositoryProvider);
      final myUid = ref.read(authRepositoryProvider).currentUser?.id;
      if (myUid != null) {
        debugPrint('[REACTION_DEBUG] Toggling spark for message ${widget.message.messageId} by $myUid');
        await repo.toggleMessageSpark(
          widget.message.messageId, 
          myUid, 
          reaction: emoji
        );
        HapticFeedback.lightImpact();
      } else {
        debugPrint('[REACTION_DEBUG] UID is NULL! Cannot toggle spark.');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Auth Error: Please re-login to react.')));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to spark: $e')));
      }
    }
  }

  void _handleTap(TapDownDetails details) {
    _lastTapDownPosition = details.globalPosition;
    
    setState(() {
      _tapCount++;
    });
    
    debugPrint('[MessageBubble] Tap count: $_tapCount');
    // Reset tap count after 500ms of inactivity
    _tapResetTimer?.cancel();
    _tapResetTimer = Timer(const Duration(milliseconds: 500), () {
      if (mounted) {
        _tapCount = 0;
        _isRushing = false;
      }
    });

    // 1. Double Tap -> Heart Reaction (Moved to native onDoubleTap)
    if (_tapCount == 2) {
      // Logic handled by native onDoubleTap
    }

    // 2. Multi-Tap (>5) -> Spark Rush
    if (_tapCount >= 5) {
      if (!_isRushing) {
        _startRushLoop();
      }
      
      _isRushing = true;
      HapticFeedback.selectionClick();
      
      // Keep rushing for 2.5 seconds after last tap
      _stopRushTimer?.cancel();
      _stopRushTimer = Timer(const Duration(milliseconds: 2500), () {
        if (mounted) {
          _isRushing = false;
          _rushPeriodicTimer?.cancel();
          _rushPeriodicTimer = null;
        }
      });
    }

    // Standard Long Press logic (original)
    _cancelLongPress();
    _longPressTimer = Timer(const Duration(milliseconds: 400), _triggerLongPress);
  }

  void _startRushLoop() {
    _rushPeriodicTimer?.cancel();
    _rushPeriodicTimer = Timer.periodic(const Duration(milliseconds: 150), (timer) {
      if (mounted && _isRushing && _lastTapDownPosition != null) {
        ref.read(reactionControllerProvider.notifier).addReaction(_lastTapDownPosition!, ReactionType.spark);
      } else {
        timer.cancel();
      }
    });
  }

  void _triggerLongPress() {
    if (_lastTapDownPosition != null && mounted) {
      HapticFeedback.mediumImpact();
      if (widget.onLongPress != null) {
        widget.onLongPress!(_lastTapDownPosition!, widget.message);
      } else {
        _showMessageOptions(context);
      }
    }
  }

  void _cancelLongPress() {
    _longPressTimer?.cancel();
    _longPressTimer = null;
  }

  @override
  void dispose() {
    _cancelLongPress();
    _tapResetTimer?.cancel();
    _stopRushTimer?.cancel();
    _rushPeriodicTimer?.cancel();
    super.dispose();
  }

  Widget _buildReplyHeader(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 4, left: 4, right: 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: (widget.isMe ? Colors.white10 : Colors.black12).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border(
          left: BorderSide(
            color: const Color(0xFF4FC3F7).withValues(alpha: 0.7),
            width: 3,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Consumer(
            builder: (context, ref, _) {
              final replySenderId = widget.message.replyToSenderId;
              final profile = replySenderId != null ? ref.watch(chatProfileProvider(replySenderId)).valueOrNull : null;
              
              return Text(
                profile?.xparqName ?? widget.message.replyToName ?? 'User',
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF4FC3F7),
                ),
              );
            },
          ),
          const SizedBox(height: 2),
          Text(
            widget.message.replyToPreview ?? '',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              color: (isDark ? Colors.white60 : Colors.black54),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final displayContent = widget.message.decryptedContent ?? widget.message.content;
    final isSensitiveBlurred = widget.message.isSensitive && widget.callerAgeGroup == AgeGroup.cadet;

    if (isSensitiveBlurred) {
      return Align(
        alignment: AlignmentDirectional.centerStart,
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1040),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            AppLocalizations.of(context)!.sensitiveContentCadet,
            style: const TextStyle(
              color: Color(0xFF7C4DFF),
              fontSize: 13,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      );
    }

    if (widget.message.messageType == MessageType.deleted) {
      return _buildRecalledMessage(context);
    }

    final isNsfwBlurred = widget.message.isSensitive && !_isRevealed && !widget.isMe;

    return Align(
      alignment: widget.isMe ? AlignmentDirectional.centerEnd : AlignmentDirectional.centerStart,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!widget.isMe) 
            Padding(
              padding: const EdgeInsets.only(bottom: 8, right: 8),
              child: ref.watch(chatProfileProvider(widget.message.senderUid)).when(
                data: (profile) {
                  if (profile == null) return const CircleAvatar(radius: 14, child: Icon(Icons.person, size: 16));
                  return GestureDetector(
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (context) => MiniProfilePopup(profile: profile, chatId: widget.chatId),
                      );
                    },
                    child: CircleAvatar(
                      radius: 14,
                      backgroundImage: profile.photoUrl.isNotEmpty
                          ? NetworkImage(profile.photoUrl)
                          : null,
                      backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                      child: profile.photoUrl.isEmpty
                          ? Icon(Icons.person, size: 16, color: Theme.of(context).colorScheme.primary)
                          : null,
                    ),
                  );
                },
                loading: () => const CircleAvatar(radius: 14, child: SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2))),
                error: (__, _) => const CircleAvatar(radius: 14, child: Icon(Icons.person, size: 16)),
              ),
            ),
          Flexible(
            child: Column(
              crossAxisAlignment: widget.isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (widget.message.replyToId != null) _buildReplyHeader(context),
                if (widget.message.isSensitive && !widget.isMe)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4, left: 4),
                    child: GestureDetector(
                      onTap: () => setState(() => _isRevealed = !_isRevealed),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.warning_amber_rounded, color: Color(0xFFFF6B6B), size: 12),
                          const SizedBox(width: 4),
                          Text(
                            _isRevealed
                                ? AppLocalizations.of(context)!.sensitiveTapToHide
                                : AppLocalizations.of(context)!.sensitiveTapToReveal,
                            style: const TextStyle(color: Color(0xFFFF6B6B), fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: _handleTap,
                  onTap: () {}, 
                  onDoubleTap: () {
                    debugPrint('[REACTION_DEBUG] Native Double Tap detected');
                    if (_lastTapDownPosition != null) {
                      ref.read(reactionControllerProvider.notifier).addReaction(_lastTapDownPosition!, ReactionType.heart);
                      _toggleSpark(emoji: '❤️');
                      HapticFeedback.mediumImpact();
                    }
                  },
                  onTapUp: (_) => _cancelLongPress(),
                  onTapCancel: () => _cancelLongPress(),
                  onVerticalDragStart: (_) => _cancelLongPress(),
                  onHorizontalDragStart: (_) => _cancelLongPress(),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 4),
                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
                    decoration: BoxDecoration(
                      color: widget.isMe
                          ? (widget.message.isSensitive
                              ? const Color(0xFF3D1A7A)
                              : (Theme.of(context).brightness == Brightness.dark
                                  ? const Color(0xFF1E3A5F)
                                  : Colors.grey[200]))
                          : (Theme.of(context).brightness == Brightness.dark
                              ? const Color(0xFF0D1B2A)
                              : Colors.grey[100]),
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(18),
                        topRight: const Radius.circular(18),
                        bottomLeft: Radius.circular(widget.isMe ? 18 : 4),
                        bottomRight: Radius.circular(widget.isMe ? 4 : 18),
                      ),
                      border: widget.message.isSensitive
                          ? Border.all(color: const Color(0xFFFF6B6B).withValues(alpha: 0.3))
                          : null,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: Stack(
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (widget.otherUid == 'group' && !widget.isMe)
                                  _buildSenderName(context),
                                if (widget.message.messageType == MessageType.image)
                                  _buildImagePayload(displayContent)
                                else if (widget.message.messageType == MessageType.sticker)
                                  Text(
                                    displayContent,
                                    style: const TextStyle(
                                      fontSize: 40,
                                    ),
                                  )
                                else if (widget.message.messageType == MessageType.deleted)
                                  Text(
                                    AppLocalizations.of(context)!.messageDeleted,
                                    style: TextStyle(
                                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                                      fontSize: 14,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  )
                                else
                                  Text(
                                    displayContent,
                                    style: TextStyle(
                                      color: Theme.of(context).colorScheme.onSurface,
                                      fontSize: 15,
                                      height: 1.4,
                                    ),
                                  ),
                                const SizedBox(height: 4),
                                _buildTimestampAndStatus(context),
                                if (widget.otherUid == 'group' &&
                                    widget.message.metadata['sparks'] != null &&
                                    _getSparkCount(widget.message.metadata['sparks']) > 0)
                                  _buildSparkIndicator(),
                              ],
                            ),
                          ),
                          if (isNsfwBlurred) _buildBlurOverlay(context),
                        ],
                      ),
                    ),
                  ),
                ),
                if (widget.message.reactions.isNotEmpty)
                  _buildEmojiReactions(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSenderName(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: ref.watch(chatProfileProvider(widget.message.senderUid)).when(
            data: (p) => GestureDetector(
              onTap: () {
                if (p != null) {
                  showDialog(
                    context: context,
                    builder: (context) => MiniProfilePopup(profile: p, chatId: widget.chatId),
                  );
                }
              },
              child: Text(
                (p != null
                    ? (p.handle != null && p.handle!.isNotEmpty
                        ? '${p.xparqName} (@${p.handle})'
                        : p.xparqName)
                    : 'Explorer'),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
            loading: () => const SizedBox.shrink(),
            error: (__, _) => const SizedBox.shrink(),
          ),
    );
  }

  Widget _buildImagePayload(String displayContent) {
    try {
      final payload = jsonDecode(displayContent);
      return Padding(
        padding: const EdgeInsets.only(bottom: 8.0),
        child: EncryptedImageWidget(
          url: payload['url'] ?? '',
          storagePath: payload['storage_path'] ?? '',
          mediaKeyBase64: payload['media_key'] ?? '',
        ),
      );
    } catch (e) {
      return const Text(
        'ðŸ”’ [Encrypted Media Error]',
        style: TextStyle(fontStyle: FontStyle.italic),
      );
    }
  }

  Widget _buildTimestampAndStatus(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          _timeFormatter.format(widget.message.timestamp),
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38),
            fontSize: 10,
          ),
        ),
        if (widget.message.metadata['is_edited'] == true) ...[
          const SizedBox(width: 4),
          Text(
            'Edited',
            style: TextStyle(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
              fontSize: 9,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
        if (widget.isMe) ...[
          const SizedBox(width: 4),
          Icon(
            widget.message.read
                ? Icons.done_all
                : widget.message.delivered
                    ? Icons.done_all
                    : Icons.done,
            size: 12,
            color: widget.message.read
                ? const Color(0xFF4FC3F7)
                : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38),
          ),
        ],
        if (widget.message.isOfflineRelay)
          const Padding(
            padding: EdgeInsetsDirectional.only(start: 4),
            child: Icon(Icons.bluetooth, size: 10, color: Color(0xFF7C4DFF)),
          ),
      ],
    );
  }

  Widget _buildSparkIndicator() {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: GestureDetector(
        onTap: _toggleSpark,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.amber.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Colors.amber.withValues(alpha: 0.3),
              width: 0.5,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.bolt, size: 10, color: Colors.amber),
              const SizedBox(width: 2),
              Text(
                '${_getSparkCount(widget.message.metadata['sparks'])}',
                style: const TextStyle(
                  color: Colors.amber,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmojiReactions() {
    final reactions = widget.message.reactions;
    final Map<String, int> reactionCounts = {};
    for (var e in reactions.values) {
      reactionCounts[e] = (reactionCounts[e] ?? 0) + 1;
    }

    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 4),
      child: Column(
        crossAxisAlignment: widget.isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: reactionCounts.entries.map((entry) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.1),
                    width: 0.5,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      entry.key,
                      style: const TextStyle(fontSize: 12),
                    ),
                    if (entry.value > 1) ...[
                      const SizedBox(width: 4),
                      Text(
                        '${entry.value}',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildBlurOverlay(BuildContext context) {
    return Positioned.fill(
      child: GestureDetector(
        onTap: () => setState(() => _isRevealed = true),
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(18),
          ),
          alignment: Alignment.center,
          child: Icon(
            Icons.visibility_off,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54),
            size: 28,
          ),
        ),
      ),
    );
  }

  void _showMessageOptions(BuildContext context) {
    final myUid = ref.read(authRepositoryProvider).currentUser?.id;
    final isMyMessage = widget.message.senderUid == myUid;
    final canDeleteForEveryone = isMyMessage &&
        DateTime.now().difference(widget.message.timestamp).inHours < 2;

    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.reply_rounded),
              title: const Text('Echo (Reply)'),
              onTap: () {
                Navigator.pop(ctx);
                widget.onReply?.call(widget.message);
              },
            ),
            ListTile(
              leading: const Icon(Icons.bolt, color: Colors.amber),
              title: const Text('âš¡ Spark (Like)'),
              onTap: () {
                Navigator.pop(ctx);
                _toggleSpark();
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('Delete for me'),
              onTap: () {
                Navigator.pop(ctx);
                ref.read(chatRepositoryProvider).deleteMessageForMe(widget.message.messageId);
              },
            ),
            ListTile(
              leading: Icon(
                widget.isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                color: widget.isPinned ? const Color(0xFF4FC3F7) : null,
              ),
              title: Text(widget.isPinned ? 'Unpin from Cluster' : 'Pin to Cluster'),
              onTap: () {
                Navigator.pop(ctx);
                _togglePin();
              },
            ),
            if (canDeleteForEveryone)
              ListTile(
                leading: const Icon(Icons.delete_forever, color: Color(0xFFFF4444)),
                title: const Text('Delete for everyone', style: TextStyle(color: Color(0xFFFF4444))),
                onTap: () {
                  Navigator.pop(ctx);
                  ref.read(chatRepositoryProvider).deleteMessageForEveryone(widget.message.messageId);
                },
              ),
          ],
        ),
      ),
    );
  }

  int _getSparkCount(dynamic sparks) {
    if (sparks == null) return 0;
    if (sparks is List) return sparks.length;
    if (sparks is Map) return sparks.length;
    return 0;
  }

  Widget _buildRecalledMessage(BuildContext context) {
    if (!widget.isMe) {
      // Recipient side: Signal Revoked Mission Card
      return Align(
        alignment: Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12, left: 16, right: 48),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.satellite_alt_outlined,
                size: 16,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
              ),
              const SizedBox(width: 8),
              Text(
                'ðŸ›°ï¸ à¸ªà¸±à¸à¸à¸²à¸“à¸–à¸¹à¸à¸¢à¸à¹€à¸¥à¸´à¸à¹‚à¸”à¸¢à¸œà¸¹à¹‰à¸ªà¹ˆà¸‡',
                style: TextStyle(
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.35),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Sender side: Faded Original content + "Revoked" Badge
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final displayContent = widget.message.decryptedContent ?? widget.message.content;

    return Opacity(
      opacity: 0.45,
      child: Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12, right: 12),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF2C1A3F) : const Color(0xFFF3E5F5),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                displayContent,
                style: TextStyle(
                  fontSize: 15,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                   Icon(Icons.undo_rounded, size: 10, color: isDark ? Colors.white30 : Colors.black26),
                   const SizedBox(width: 4),
                   Text(
                    'à¸¢à¸à¹€à¸¥à¸´à¸à¹à¸¥à¹‰à¸§',
                    style: TextStyle(
                      fontSize: 9, 
                      color: isDark ? Colors.white30 : Colors.black26, 
                      fontWeight: FontWeight.bold
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}


