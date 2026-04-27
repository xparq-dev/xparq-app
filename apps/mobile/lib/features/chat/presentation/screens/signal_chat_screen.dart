import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:xparq_app/l10n/app_localizations.dart';
import 'package:xparq_app/features/chat/presentation/providers/active_chat_provider.dart';
import 'package:xparq_app/features/auth/providers/auth_providers.dart';
import 'package:xparq_app/features/chat/domain/models/chat_model.dart';
import 'package:xparq_app/features/chat/presentation/providers/chat_providers.dart';
import 'package:xparq_app/features/chat/presentation/providers/signal_chat_controller.dart';
import 'package:xparq_app/features/chat/presentation/widgets/signal_chat_app_bar.dart';
import 'package:xparq_app/features/chat/presentation/widgets/chat_input_bar.dart';
import 'package:xparq_app/features/chat/presentation/widgets/message_list_view.dart';
import 'package:xparq_app/features/chat/presentation/widgets/typing_indicator.dart';
import 'package:xparq_app/features/chat/presentation/widgets/pinned_messages_bar.dart';
import 'package:xparq_app/features/chat/presentation/widgets/conversation_mention_overlay.dart';
import 'package:xparq_app/features/chat/presentation/widgets/conversation_reply_preview.dart';
import 'package:xparq_app/features/chat/presentation/widgets/signal_sidebar.dart';
import 'package:xparq_app/features/chat/data/services/signal/signal_session_manager.dart';
import 'package:xparq_app/features/chat/presentation/widgets/group_info_popup.dart';
import 'package:xparq_app/features/chat/presentation/widgets/focused_message_overlay.dart';
import 'package:xparq_app/features/chat/presentation/widgets/silence_cluster_dialog.dart';
import 'package:xparq_app/features/chat/presentation/widgets/message_bubble.dart';
import 'package:xparq_app/features/chat/presentation/widgets/reaction_overlay_layer.dart';
import 'package:xparq_app/features/offline/services/offline_chat_database.dart';

class SignalChatScreen extends ConsumerStatefulWidget {
  final String chatId;
  final String otherUid;
  final bool isSpamMode;

  const SignalChatScreen({
    super.key,
    required this.chatId,
    required this.otherUid,
    this.isSpamMode = false,
  });

  @override
  ConsumerState<SignalChatScreen> createState() => _SignalChatScreenState();
}

class _SignalChatScreenState extends ConsumerState<SignalChatScreen> {
  late final TextEditingController _textController;
  late final ScrollController _scrollController;
  Timer? _vanishingTicker;

  // Focused Message State
  MessageModel? _focusedMessage;
  Offset? _focusedPosition;
  Size? _focusedSize;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController();
    _scrollController = ScrollController();

    // Initial setup
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeChat();
    });

    _vanishingTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  void _listenForNewMessages() {
    // Watch for new messages and mark as read if the screen is focused
    ref.listen(messagesProvider(widget.chatId), (previous, next) {
      if (!mounted) return;

      if (next.hasValue && next.value!.isNotEmpty) {
        final lastMsg = next.value!.last;
        final myUid = ref.read(authRepositoryProvider).currentUser?.id ?? '';

        // Only mark as read if it's from the other peer and currently unread
        if (lastMsg.senderUid != myUid && !lastMsg.read) {
          _markAsRead();
        }
      }
    });
  }

  Future<void> _markAsRead() async {
    if (!mounted) return;

    final myUid = ref.read(authRepositoryProvider).currentUser?.id ?? '';
    if (myUid.isNotEmpty) {
      try {
        await ref.read(chatRepositoryProvider).markAsRead(widget.chatId, myUid);
        if (mounted) {
          ref.invalidate(unreadCountsProvider);
        }
      } catch (e) {
        debugPrint('SIGNAL_CHAT: Failed to mark as read: $e');
      }
    }
  }

  void _initializeChat() {
    final myUid = ref.read(authRepositoryProvider).currentUser?.id ?? '';
    if (myUid.isNotEmpty) {
      _markAsRead();
    }
    ref.read(activeChatIdProvider.notifier).state = widget.chatId;
  }

  @override
  void dispose() {
    _vanishingTicker?.cancel();
    _textController.dispose();
    _scrollController.dispose();
    ref.read(activeChatIdProvider.notifier).state = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final myUid = ref.watch(authRepositoryProvider).currentUser?.id ?? '';
    final ageGroupValue = ref.watch(currentAgeGroupProvider);
    final ageGroup =
        ageGroupValue; // Remove ?? AgeGroup.cadet as Provider already provides a default (Safe)
    final isGroup = widget.otherUid == 'group';

    final chatsAsync = ref.watch(myChatsProvider);
    final chat = chatsAsync.whenOrNull(
        data: (list) => list.any((c) => c.chatId == widget.chatId)
            ? list.firstWhere((c) => c.chatId == widget.chatId)
            : null);

    _listenForNewMessages();

    final isLandscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      extendBody: true,
      extendBodyBehindAppBar: true,
      appBar: SignalChatAppBar(
        chatId: widget.chatId,
        otherUid: widget.otherUid,
        chat: chat,
        isGroup: isGroup,
        onVanishingDialog: () => _showVanishingDialog(context, chat),
        onDeleteChat: () => _confirmDeleteChat(context, chat),
        onRepairSession: () => _repairSignalSession(),
        onGroupAction: (action, chatObj) =>
            _handleGroupAction(context, action, chatObj),
      ),
      body: ReactionOverlayLayer(
        child: Stack(
          children: [
            Row(
              children: [
                if (isLandscape)
                  SignalSidebar(
                    myUid: myUid,
                  ),
                Expanded(
                  child: AnimatedPadding(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOutCubic,
                    padding: EdgeInsets.only(bottom: keyboardInset),
                    child: Column(
                      children: [
                        if (isGroup) PinnedMessagesBar(chatId: widget.chatId),
                        Expanded(
                          child: Stack(
                            children: [
                              MessageListView(
                                chatId: widget.chatId,
                                myUid: myUid,
                                otherUid: widget.otherUid,
                                ageGroup: ageGroup,
                                chat: chat,
                                scrollController: _scrollController,
                                onReply: (msg) => ref
                                    .read(signalChatControllerProvider(
                                            widget.chatId)
                                        .notifier)
                                    .setReplyingTo(msg),
                                onLongPress: (pos, msg) =>
                                    _showFocusedOverlay(pos, msg),
                                onTap: () {
                                  final controller = ref.read(
                                      signalChatControllerProvider(
                                              widget.chatId)
                                          .notifier);
                                  if (ref
                                          .read(signalChatControllerProvider(
                                              widget.chatId))
                                          .replyingTo !=
                                      null) {
                                    controller.setReplyingTo(null);
                                  }
                                },
                              ),
                              MentionOverlay(
                                chatId: widget.chatId,
                                textController: _textController,
                              ),
                            ],
                          ),
                        ),
                        ConversationReplyPreview(chatId: widget.chatId),
                        TypingIndicator(
                            chatId: widget.chatId, otherUid: widget.otherUid),
                        ChatInputBar(
                          chatId: widget.chatId,
                          otherUid: widget.otherUid,
                          ageGroup: ageGroup,
                          isSpamMode: widget.isSpamMode,
                          textController: _textController,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            if (_focusedMessage != null &&
                _focusedPosition != null &&
                _focusedSize != null)
              FocusedMessageOverlay(
                message: _focusedMessage!,
                messageGlobalPosition: _focusedPosition!,
                messageSize: _focusedSize!,
                messageWidget: MessageBubble(
                  message: _focusedMessage!,
                  isMe: _focusedMessage!.senderUid == myUid,
                  chatId: widget.chatId,
                  callerAgeGroup: ageGroup,
                  otherUid: widget.otherUid,
                  isPinned: chat?.pinnedMessages
                          .contains(_focusedMessage!.messageId) ??
                      false,
                ),
                onDismiss: () => setState(() {
                  _focusedMessage = null;
                  _focusedPosition = null;
                  _focusedSize = null;
                }),
                onReply: (msg) => ref
                    .read(signalChatControllerProvider(widget.chatId).notifier)
                    .setReplyingTo(msg),
                onPin: (msg) => _handlePin(msg),
                onDelete: (msg) => _handleDelete(msg),
                onRecall: (msg) => _handleRecall(msg),
                onEdit: (msg) => _handleEdit(msg),
                onReaction: (code) =>
                    ref.read(chatRepositoryProvider).toggleMessageSpark(
                          _focusedMessage!.messageId,
                          myUid,
                          reaction: code,
                        ),
              ),
          ],
        ),
      ),
    );
  }

  void _showFocusedOverlay(Offset position, MessageModel message) {
    setState(() {
      _focusedMessage = message;
      _focusedPosition = position;
      _focusedSize = const Size(300, 100); // Placeholder size
    });
    HapticFeedback.mediumImpact();
  }

  Future<void> _handlePin(MessageModel message) async {
    final chats = ref.read(myChatsProvider).valueOrNull ?? [];
    final chat = chats.firstWhere((c) => c.chatId == widget.chatId);
    final isPinned = chat.pinnedMessages.contains(message.messageId);
    final newPins = List<String>.from(chat.pinnedMessages);
    if (isPinned) {
      newPins.remove(message.messageId);
    } else {
      newPins.add(message.messageId);
    }
    await ref
        .read(chatRepositoryProvider)
        .updatePinnedMessages(widget.chatId, newPins);
  }

  Future<void> _handleDelete(MessageModel message) async {
    await ref
        .read(chatRepositoryProvider)
        .deleteMessageForMe(message.messageId);
  }

  Future<void> _handleRecall(MessageModel message) async {
    final notifier =
        ref.read(signalChatControllerProvider(widget.chatId).notifier);
    if (!notifier.canModifySignal(message)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('สัญญาณเสถียรแล้ว ไม่สามารถเรียกคืนได้ (เกิน 5 นาที)'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    HapticFeedback.mediumImpact();
    await ref
        .read(chatRepositoryProvider)
        .deleteMessageForEveryone(message.messageId);
  }

  void _handleEdit(MessageModel message) {
    final notifier =
        ref.read(signalChatControllerProvider(widget.chatId).notifier);
    if (!notifier.canModifySignal(message)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('สัญญาณเสถียรแล้ว ไม่สามารถแก้ไขได้'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    HapticFeedback.lightImpact();
    notifier.setEditingMessage(message);
    _textController.text = message.decryptedContent ?? message.content;

    // Focus the text field
    FocusScope.of(context).requestFocus();
  }

  void _showVanishingDialog(BuildContext context, ChatModel? chat) {
    final l10n = AppLocalizations.of(context);
    if (l10n == null) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.vanishingMessagesTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildVanishingOption(context, l10n.vanishingOff, null, chat),
            _buildVanishingOption(context, l10n.vanishing30Sec, 30, chat),
            _buildVanishingOption(context, l10n.vanishing5Min, 300, chat),
            _buildVanishingOption(context, l10n.vanishing1Hour, 3600, chat),
            _buildVanishingOption(context, l10n.vanishing1Day, 86400, chat),
            _buildVanishingOption(context, l10n.vanishing1Week, 604800, chat),
          ],
        ),
      ),
    );
  }

  Widget _buildVanishingOption(
      BuildContext context, String label, int? seconds, ChatModel? chat) {
    final isSelected = chat?.vanishingDuration == seconds;
    return ListTile(
      title: Text(label),
      trailing:
          isSelected ? const Icon(Icons.check, color: Color(0xFF4FC3F7)) : null,
      onTap: () async {
        Navigator.pop(context);
        try {
          final myUid = ref.read(authRepositoryProvider).currentUser?.id ?? '';
          final members = chat?.participants ??
              (widget.otherUid == 'group' ? [myUid] : [myUid, widget.otherUid]);
          await ref.read(chatRepositoryProvider).updateVanishingDuration(
                chatId: widget.chatId,
                participants: members,
                durationSeconds: seconds,
              );
        } catch (e) {
          if (context.mounted) {
            final l10n = AppLocalizations.of(context);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content:
                      Text(l10n?.failedPrefix(e.toString()) ?? 'Failed: $e')),
            );
          }
        }
      },
    );
  }

  void _confirmDeleteChat(BuildContext context, ChatModel? chat) async {
    final l10n = AppLocalizations.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(l10n?.chatDeleteSignal ?? 'Delete Signal?'),
        content: const Text('This will permanently erase this conversation.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Delete',
              style: TextStyle(
                color: Color(0xFFFF4444),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm == true && context.mounted) {
      try {
        // 1. Delete on server (Supabase Messages + Chat row)
        await ref.read(chatRepositoryProvider).deleteChat(widget.chatId);

        // 2. Delete locally (SQLite Messages + Signal Sessions)
        await OfflineChatDatabase.instance.deleteChatLocally(widget.chatId);

        if (context.mounted) {
          context.pop();
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete: $e')),
          );
        }
      }
    }
  }

  Future<void> _repairSignalSession() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Repair Discussion?'),
        content: const Text(
            'This will reset your secure encryption keys for this specific chat. Use this if you see "Decryption Failed" errors.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Repair',
                  style: TextStyle(fontWeight: FontWeight.bold))),
        ],
      ),
    );
    if (confirm == true && mounted) {
      await SignalSessionManager.instance.reSyncSession(widget.chatId);
      // Invalidate the message cache so every message is re-attempted for decryption.
      ref.invalidate(messagesProvider(widget.chatId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Discussion repaired. Please send a new signal.')));
      }
    }
  }

  void _handleGroupAction(BuildContext context, String action, ChatModel chat) {
    if (action == 'silence') {
      showDialog(
          context: context,
          builder: (ctx) => SilenceClusterDialog(chatId: chat.chatId));
    } else if (action == 'info') {
      showDialog(
          context: context, builder: (ctx) => ClusterCorePopup(chat: chat));
    }
  }
}
