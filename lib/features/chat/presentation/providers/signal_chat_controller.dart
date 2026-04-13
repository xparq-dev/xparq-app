import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:xparq_app/features/chat/domain/models/chat_model.dart';
import 'package:xparq_app/features/auth/models/planet_model.dart';
import 'package:xparq_app/features/chat/data/services/message_encryption_service.dart';
import 'package:xparq_app/features/auth/providers/auth_providers.dart';
import 'chat_providers.dart';

import 'package:xparq_app/features/offline/services/offline_chat_database.dart';

part 'signal_chat_controller.g.dart';

class SignalChatState {
  final MessageModel? replyingTo;
  final bool isSensitive;
  final bool isSilentSend;
  final bool isSidebarCollapsed;
  final bool isKeyboardWarped;
  final double keyboardHeight;
  final bool isUploadingMedia;
  final MessageModel? editingMessage;
  final List<String> mentions;
  final List<PlanetModel> mentionSuggestions;

  SignalChatState({
    this.replyingTo,
    this.isSensitive = false,
    this.isSilentSend = false,
    this.isSidebarCollapsed = false,
    this.isKeyboardWarped = false,
    this.keyboardHeight = 320.0,
    this.isUploadingMedia = false,
    this.editingMessage,
    this.mentions = const [],
    this.mentionSuggestions = const [],
  });

  SignalChatState copyWith({
    MessageModel? replyingTo,
    bool? isSensitive,
    bool? isSilentSend,
    bool? isSidebarCollapsed,
    bool? isKeyboardWarped,
    double? keyboardHeight,
    bool? isUploadingMedia,
    MessageModel? editingMessage,
    List<String>? mentions,
    List<PlanetModel>? mentionSuggestions,
    bool clearReply = false,
    bool clearEditing = false,
  }) {
    return SignalChatState(
      replyingTo: clearReply ? null : (replyingTo ?? this.replyingTo),
      isSensitive: isSensitive ?? this.isSensitive,
      isSilentSend: isSilentSend ?? this.isSilentSend,
      isSidebarCollapsed: isSidebarCollapsed ?? this.isSidebarCollapsed,
      isKeyboardWarped: isKeyboardWarped ?? this.isKeyboardWarped,
      keyboardHeight: keyboardHeight ?? this.keyboardHeight,
      isUploadingMedia: isUploadingMedia ?? this.isUploadingMedia,
      editingMessage: clearEditing ? null : (editingMessage ?? this.editingMessage),
      mentions: mentions ?? this.mentions,
      mentionSuggestions: mentionSuggestions ?? this.mentionSuggestions,
    );
  }
}

@riverpod
class SignalChatController extends _$SignalChatController {
  @override
  SignalChatState build(String chatId) {
    return SignalChatState();
  }

  void toggleSensitive(bool value) {
    state = state.copyWith(isSensitive: value);
  }

  void toggleSilentSend(bool value) {
    state = state.copyWith(isSilentSend: value);
  }

  Future<void> toggleMute({Duration? duration}) async {
    final until = duration != null ? DateTime.now().add(duration) : null;
    try {
      await ref.read(chatRepositoryProvider).silenceChat(chatId, until);
      HapticFeedback.lightImpact();
    } catch (e) {
      debugPrint('Error toggling mute: $e');
    }
  }

  Future<void> sendSticker(String stickerText) async {
    HapticFeedback.mediumImpact();

    final fakeId = 'pending_sticker_${DateTime.now().microsecondsSinceEpoch}';
    final myUid = ref.read(authRepositoryProvider).currentUser?.id;

    // 1. Immediate Optimistic UI
    final optimisticMessage = MessageModel(
      messageId: fakeId,
      senderUid: myUid ?? '',
      content: '', 
      decryptedContent: stickerText,
      timestamp: DateTime.now(),
      isSensitive: state.isSensitive,
      messageType: MessageType.sticker,
    );

    ref.read(pendingMessagesProvider.notifier).addPendingMessage(chatId, optimisticMessage);
    MessageEncryptionService.rememberPendingPlaintext(fakeId, stickerText);

    try {
      final myProfile = ref.read(planetProfileProvider).value;
      if (myProfile == null) return;

      final chatList = ref.read(myChatsProvider).valueOrNull ?? [];
      final chat = chatList.firstWhere(
        (c) => c.chatId == chatId,
        orElse: () => ChatModel(
          chatId: chatId,
          participants: [myProfile.id],
          createdAt: DateTime.now(),
        ),
      );

      final otherParticipant = chat.participants.firstWhere(
        (id) => id != myProfile.id, 
        orElse: () => '',
      );

      unawaited(
        ref.read(chatRepositoryProvider).sendMessage(
          chatId: chatId,
          senderProfile: myProfile,
          plaintext: stickerText,
          isSensitive: state.isSensitive,
          otherUid: otherParticipant,
          messageType: 'sticker',
          clientPendingId: fakeId,
          expiresAt: chat.vanishingDuration != null
              ? DateTime.now().add(Duration(seconds: chat.vanishingDuration!))
              : null,
        ).catchError((e) {
          ref.read(pendingMessagesProvider.notifier).removePendingMessage(chatId, fakeId);
        }),
      );
    } catch (e) {
      debugPrint('Error in sendSticker (Repository): $e');
      ref.read(pendingMessagesProvider.notifier).removePendingMessage(chatId, fakeId);
    }
  }

  Future<void> sendMessage(String text, String otherUid, TextEditingController textController) async {
    final trimmedText = text.trim();
    if (trimmedText.isEmpty) return;

    if (state.editingMessage != null) {
      await _saveEditedMessage(trimmedText, otherUid, textController);
      return;
    }

    HapticFeedback.lightImpact();

    final fakeId = 'pending_${DateTime.now().microsecondsSinceEpoch}';
    final myUid = ref.read(authRepositoryProvider).currentUser?.id;
    final replyMsg = state.replyingTo;
    final mentionUids = List<String>.from(state.mentions);

    // 1. Immediate Input Clear and Optimistic UI
    textController.clear();
    state = state.copyWith(clearReply: true, mentions: []);

    final optimisticMessage = MessageModel(
      messageId: fakeId,
      senderUid: myUid ?? '',
      content: '',
      decryptedContent: trimmedText,
      timestamp: DateTime.now(),
      isSensitive: state.isSensitive,
      metadata: {
        if (replyMsg != null) ...{
          'reply_to_id': replyMsg.messageId,
          'reply_to_sender_id': replyMsg.senderUid,
          'reply_to_preview': replyMsg.decryptedContent ?? (replyMsg.content.length > 50 ? replyMsg.content.substring(0, 50) : replyMsg.content),
        },
        if (mentionUids.isNotEmpty) 'mentions': mentionUids,
      },
    );

    ref.read(pendingMessagesProvider.notifier).addPendingMessage(chatId, optimisticMessage);
    MessageEncryptionService.rememberPendingPlaintext(fakeId, trimmedText);

    try {
      final myProfile = ref.read(planetProfileProvider).value;
      if (myProfile == null) {
        debugPrint('sendMessage: ABORTED — myProfile is null. Auth may not be ready.');
        ref.read(pendingMessagesProvider.notifier).removePendingMessage(chatId, fakeId);
        textController.text = trimmedText;
        return;
      }

      final chatList = ref.read(myChatsProvider).valueOrNull ?? [];
      final chat = chatList.firstWhere(
        (c) => c.chatId == chatId,
        orElse: () => ChatModel(
          chatId: chatId,
          participants: [myProfile.id, otherUid],
          createdAt: DateTime.now(),
        ),
      );
      
      unawaited(
        ref.read(chatRepositoryProvider).sendMessage(
          chatId: chatId,
          senderProfile: myProfile,
          plaintext: trimmedText,
          isSensitive: state.isSensitive,
          otherUid: otherUid,
          clientPendingId: fakeId,
          metadata: {if (state.isSilentSend) 'silent': true},
          expiresAt: chat.vanishingDuration != null
              ? DateTime.now().add(Duration(seconds: chat.vanishingDuration!))
              : null,
          replyTo: replyMsg,
          mentions: mentionUids,
        ).then((_) {
          if (state.isSilentSend) {
            state = state.copyWith(isSilentSend: false);
          }
        }).catchError((e) {
          debugPrint('sendMessage: Repository/RPC Error — $e');
          ref.read(pendingMessagesProvider.notifier).removePendingMessage(chatId, fakeId);
          if (textController.text.isEmpty) {
            textController.text = trimmedText;
          }
        }),
      );
    } catch (e) {
      debugPrint('Error in sendMessage (Repository): $e');
      ref.read(pendingMessagesProvider.notifier).removePendingMessage(chatId, fakeId);
      if (textController.text.isEmpty) {
        textController.text = trimmedText;
      }
    }
  }

  void sparkLastMessage() {
    final messages = ref.read(displayMessagesProvider(chatId)).valueOrNull;
    if (messages == null || messages.isEmpty) return;

    final myUid = ref.read(authRepositoryProvider).currentUser?.id;
    try {
      final lastMsg = messages.lastWhere((m) => m.senderUid != myUid);
      ref.read(chatRepositoryProvider).toggleMessageSpark(lastMsg.messageId, myUid ?? '');
      HapticFeedback.mediumImpact();
    } catch (_) {}
  }

  void echoLastMessage() {
    final messages = ref.read(displayMessagesProvider(chatId)).valueOrNull;
    if (messages == null || messages.isEmpty) return;

    final myUid = ref.read(authRepositoryProvider).currentUser?.id;
    try {
      final lastMsg = messages.lastWhere((m) => m.senderUid != myUid);
      if (state.replyingTo?.messageId == lastMsg.messageId) {
        state = state.copyWith(clearReply: true);
      } else {
        state = state.copyWith(replyingTo: lastMsg);
      }
    } catch (_) {}
  }

  void toggleSidebar() {
    state = state.copyWith(isSidebarCollapsed: !state.isSidebarCollapsed);
  }

  void setKeyboardWarped(bool warped, {double? height}) {
    state = state.copyWith(
      isKeyboardWarped: warped,
      keyboardHeight: height,
    );
  }

  void setReplyingTo(MessageModel? message) {
    state = state.copyWith(replyingTo: message);
  }

  void setEditingMessage(MessageModel? message) {
    if (message == null) {
      state = state.copyWith(clearEditing: true);
    } else {
      state = state.copyWith(editingMessage: message);
    }
  }

  /// Checks if a message is still within the 5-minute "malleability" window.
  /// Beyond this, the signal is stabilized and cannot be altered.
  bool canModifySignal(MessageModel? message) {
    if (message == null) return false;
    final age = DateTime.now().difference(message.timestamp);
    return age.inSeconds < 300; // 5 minutes = 300 seconds
  }

  Future<void> _saveEditedMessage(String newText, String otherUid, TextEditingController textController) async {
    final msg = state.editingMessage;
    if (msg == null) return;

    // Resolve the real ID – prioritize metadata['server_id'] if the current ID is a pending alias.
    // If it's still pending, it means we MIGHT be editing a message that was JUST sent.
    String? realId = msg.messageId.startsWith('pending_') 
        ? msg.metadata['server_id']?.toString() 
        : msg.messageId;

    // REAL-TIME RESOLUTION PHASE: Direct Database Lookup for Pending messages
    if (realId == null || realId.startsWith('pending_')) {
      debugPrint('EDIT: ID pending. Checking Database for CID: ${msg.messageId}');
      
      // 1. Direct fetch from Supabase (much faster than waiting for provider reconciliation)
      final resolved = await ref.read(chatRepositoryProvider).resolveMessageIdFromPending(msg.messageId);
      
      if (resolved != null) {
        realId = resolved;
        debugPrint('EDIT: Resolved real ID via direct lookup: $realId');
      } else {
        // 2. Fallback to polling the provider (as a second layer of defense)
        debugPrint('EDIT: Direct lookup failed. Falling back to poll...');
        for (int i = 0; i < 5; i++) {
          await Future.delayed(const Duration(milliseconds: 200));
          final latestMessages = ref.read(displayMessagesProvider(chatId)).valueOrNull ?? [];
          final latestMsg = latestMessages.firstWhere(
            (m) => m.messageId == msg.messageId || m.metadata['client_pending_id'] == msg.messageId,
            orElse: () => msg,
          );
          
          final resolvedLocal = latestMsg.metadata['server_id']?.toString();
          if (resolvedLocal != null && !resolvedLocal.startsWith('pending_')) {
            realId = resolvedLocal;
            debugPrint('EDIT: Resolved real ID: $realId after ${i + 1} retries.');
            break;
          }
        }
      }
    }

    if (realId == null || realId.startsWith('pending_')) {
      debugPrint('EDIT: Aborting. Server ID never arrived.');
      state = state.copyWith(clearEditing: true);
      textController.clear();
      return;
    }

    final originalContent = msg.decryptedContent ?? msg.content;
    if (newText == originalContent) {
      state = state.copyWith(clearEditing: true);
      textController.clear();
      return;
    }

    HapticFeedback.mediumImpact();
    // Keep a backup of the text in case it fails? 
    // For now, let's just not clear immediately if we're worried about errors,
    // but the request asks for a fix where it currently doesn't work.
    
    try {
      // 1. Perform the edit in the repository
      debugPrint('EDIT: Starting update for $realId (original alias: ${msg.messageId})');
      await ref.read(chatRepositoryProvider).editMessage(
        realId, 
        newText, 
        otherUid, 
        chatId,
      );
      
      // 2. IMPORTANT: Invalidate local DB cache AND memory cache for this message 
      // so the UI is forced to re-decrypt the new ciphertext.
      MessageEncryptionService.forgetMetadata(
        pendingId: msg.messageId.startsWith('pending_') ? msg.messageId : null,
        ciphertext: msg.content,
      );
      await OfflineChatDatabase.instance.removeSignalMessageCache(msg.messageId);
      await OfflineChatDatabase.instance.removeSignalMessageCache(realId);

      // 3. Clear state/UI only after success
      state = state.copyWith(clearEditing: true);
      textController.clear();
      
      debugPrint('EDIT: Success for ${msg.messageId}');
    } catch (e) {
      debugPrint('EDIT: Error saving edit: $e');
      // On error, we keep the editing state so the user can try again or see why it failed.
      // We don't clear the text controller.
      HapticFeedback.heavyImpact();
    }
  }

  Future<void> pickAndSendImage(String otherUid) async {
    final myProfile = ref.read(planetProfileProvider).value;
    if (myProfile == null) return;

    final picker = ImagePicker();
    final chat = ref.read(myChatsProvider).valueOrNull?.firstWhere((c) => c.chatId == chatId);
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile == null) return;

    state = state.copyWith(isUploadingMedia: true);

    try {
      await ref.read(chatRepositoryProvider).sendMediaMessage(
            chatId: chatId,
            senderProfile: myProfile,
            otherUid: otherUid,
            localFilePath: pickedFile.path,
            messageType: 'image',
            isSensitive: state.isSensitive,
            expiresAt: chat?.vanishingDuration != null
                ? DateTime.now().add(Duration(seconds: chat!.vanishingDuration!))
                : null,
          );
    } finally {
      state = state.copyWith(isUploadingMedia: false);
    }
  }

  void setMentionSuggestions(List<PlanetModel> suggestions) {
    state = state.copyWith(mentionSuggestions: suggestions);
  }

  void addMention(String uid) {
    final newMentions = List<String>.from(state.mentions)..add(uid);
    state = state.copyWith(mentions: newMentions);
  }

  void clearMentions() {
    state = state.copyWith(mentions: []);
  }
}
