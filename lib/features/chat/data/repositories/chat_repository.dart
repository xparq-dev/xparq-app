import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:xparq_app/shared/enums/age_group.dart';
import 'package:xparq_app/features/auth/models/planet_model.dart';
import 'package:xparq_app/features/chat/domain/models/chat_model.dart';
import '../../data/services/message_encryption_service.dart';
import '../../data/services/signal/media_encryption_service.dart';
import 'dart:io' as dart_io;
import 'dart:convert' as dart_convert;
import 'package:path/path.dart' as dart_path;

class ChatRepository {
  final SupabaseClient _client;
  static const _sendChatMessagePrimaryRpc = 'send_chat_message_v2';
  static const _sendChatMessageLegacyRpc = 'send_chat_message';
  static const _realtimeMessageWindow = 160;
  final Map<String, Future<void>> _sendQueueByChat = {};

  ChatRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  Future<void> _sendChatMessageRpc({
    required String chatId,
    required String senderId,
    required String content,
    required bool isSensitive,
    required bool isOfflineRelay,
    required bool isSpam,
    required String plaintextPreview,
    String messageType = 'text',
    Map<String, dynamic>? metadata,
    DateTime? expiresAt,
  }) async {
    final params = <String, dynamic>{
      'p_chat_id': chatId,
      'p_sender_id': senderId,
      'p_is_sensitive': isSensitive,
      'p_is_offline_relay': isOfflineRelay,
      'p_is_spam': isSpam,
      'p_plaintext_preview': plaintextPreview,
    };
    final paramsWithOptional = <String, dynamic>{
      ...params,
      'p_message_type': messageType,
      'p_metadata': metadata ?? const <String, dynamic>{},
      'p_expires_at': expiresAt?.toIso8601String(),
    };

    // Use a non-overloaded RPC name first to avoid PostgREST ambiguity.
    try {
      await _client.rpc(
        _sendChatMessagePrimaryRpc,
        params: {...paramsWithOptional, 'p_content': content},
      );
      return;
    } on PostgrestException catch (error) {
      // If optional args are not supported, retry v2 with minimal args.
      if (error.code == 'GRST202') {
        try {
          await _client.rpc(
            _sendChatMessagePrimaryRpc,
            params: {...params, 'p_content': content},
          );
          return;
        } on PostgrestException catch (nestedError) {
          if (nestedError.code != 'GRST202') rethrow;
        }
      } else {
        rethrow;
      }
    }

    try {
      await _client.rpc(
        _sendChatMessageLegacyRpc,
        params: {...params, 'p_content': content},
      );
    } on PostgrestException catch (error) {
      if (error.code == 'GRST203') {
        throw Exception(
          'Ambiguous database RPC: public.send_chat_message is overloaded. '
          'Run supabase/fix_send_chat_message_rpc.sql or create public.send_chat_message_v2.',
        );
      }

      // Retry legacy arg only when error context points to old signature.
      final lowerMessage = error.message.toLowerCase();
      final lowerHint = (error.hint ?? '').toLowerCase();
      final expectsLegacyContentArg =
          lowerMessage.contains('p_content_encrypted') ||
          lowerHint.contains('p_content_encrypted');
      if (error.code != 'GRST202' || !expectsLegacyContentArg) rethrow;
      await _client.rpc(
        _sendChatMessageLegacyRpc,
        params: {...params, 'p_content_encrypted': content},
      );
    }
  }

  // ── Realtime Channels (Typing/Presence) ───────────────────────────────────

  /// Creates a RealtimeChannel for a specific chat room.
  RealtimeChannel getTypingChannel(String chatId) {
    return _client.channel('chat_$chatId');
  }

  /// Sends a typing event.
  /// Uses Presence ('track') for groups and Broadcast ('send') for 1-1 chats.
  Future<void> sendTypingEvent({
    required RealtimeChannel channel,
    required String uid,
    required bool isTyping,
    required bool isGroup,
  }) async {
    if (isGroup) {
      if (isTyping) {
        await channel.track({'uid': uid, 'typing': true});
      } else {
        await channel.untrack();
      }
    } else {
      await channel.sendBroadcastMessage(
        event: 'typing',
        payload: {'uid': uid, 'typing': isTyping},
      );
    }
  }

  // ── Chat Document ─────────────────────────────────────────────────────────

  /// Get or create a chat document between two users.
  Future<ChatModel> getOrCreateChat({
    required String myUid,
    required String otherUid,
  }) async {
    final chatId = ChatModel.buildChatId(myUid, otherUid);
    final existing = await _client
        .from('chats')
        .select()
        .eq('id', chatId)
        .maybeSingle();

    if (existing == null) {
      final chatData = {
        'id': chatId,
        'participants': [myUid, otherUid],
        'created_at': DateTime.now().toIso8601String(),
        'is_spam': false,
      };
      await _client.from('chats').insert(chatData);
      return ChatModel.fromMap(chatData);
    }
    return ChatModel.fromMap(existing);
  }

  /// Create a new group chat.
  Future<ChatModel> createGroupChat({
    required List<String> participantUids,
    required String name,
    String? avatarUrl,
  }) async {
    final chatId = 'group_${DateTime.now().millisecondsSinceEpoch}';
    final chatData = {
      'id': chatId,
      'participants': participantUids,
      'name': name,
      'group_avatar': avatarUrl,
      'is_group': true,
      'created_at': DateTime.now().toIso8601String(),
      'is_spam': false,
      'admins': participantUids.take(1).toList(), // First user is creator/admin
    };
    await _client.from('chats').insert(chatData);
    return ChatModel.fromMap(chatData);
  }

  /// Stream of all chats (non-spam) the user is a participant in.
  Stream<List<ChatModel>> watchMyChats(String uid) {
    debugPrint('WATCH_MY_CHATS: Subscribing for $uid');
    return _client
        .from('chats')
        .stream(primaryKey: ['id'])
        .handleError((e, stack) {
          debugPrint('WATCH_MY_CHATS: Realtime Error: $e');
          debugPrint('WATCH_MY_CHATS: Stack: $stack');
        })
        .map(
          (list) =>
              list
                  .where((data) {
                    final participants = data['participants'] as List;
                    return participants.contains(uid) &&
                        data['is_spam'] == false;
                  })
                  .map((data) => ChatModel.fromMap(data))
                  .toList()
                ..sort(
                  (a, b) => (b.lastAt ?? b.createdAt).compareTo(
                    a.lastAt ?? a.createdAt,
                  ),
                ),
        );
  }

  /// Stream of spam chats for the Signal Spam folder.
  Stream<List<ChatModel>> watchSpamChats(String uid) {
    return _client
        .from('chats')
        .stream(primaryKey: ['id'])
        .map(
          (list) =>
              list
                  .where((data) {
                    final participants = data['participants'] as List;
                    return participants.contains(uid) &&
                        data['is_spam'] == true;
                  })
                  .map((data) => ChatModel.fromMap(data))
                  .toList()
                ..sort(
                  (a, b) => (b.lastAt ?? b.createdAt).compareTo(
                    a.lastAt ?? a.createdAt,
                  ),
                ),
        );
  }

  // ── Messages ──────────────────────────────────────────────────────────────

  /// Real-time stream of messages for a chat.
  Stream<List<MessageModel>> watchMessages({
    required String chatId,
    required AgeGroup callerAgeGroup,
    required String callerUid,
  }) {
    debugPrint('WATCH_MESSAGES: Subscribing to $chatId');
    return _client
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('chat_id', chatId)
        .order('timestamp', ascending: false)
        .limit(_realtimeMessageWindow)
        .handleError((e, stack) {
          debugPrint('WATCH_MESSAGES: Realtime Error for $chatId: $e');
          debugPrint('WATCH_MESSAGES: Stack: $stack');
        })
        .map((list) {
          debugPrint(
            'WATCH_MESSAGES: Received ${list.length} messages for $chatId',
          );
          // DEBUG: Log the raw payload of the most recent message to diagnosing ghost-read bug
          if (list.isNotEmpty) {
            final first = list.first;
            debugPrint(
              'WATCH_MESSAGES: Most recent raw DB row -> read: ${first['read']}, delivered: ${first['delivered']}, sender_id: ${first['sender_id']}',
            );
          }
          final now = DateTime.now();
          final messages = list.map((data) => MessageModel.fromMap(data)).where(
            (m) {
              // Filter out deleted messages for ourselves
              if (m.deletedUids.contains(callerUid)) return false;
              // Filter out expired messages
              if (m.expiresAt != null && m.expiresAt!.isBefore(now)) {
                return false;
              }
              return true;
            },
          ).toList();
          messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
          if (callerAgeGroup == AgeGroup.cadet) {
            return messages.where((m) => !m.isSensitive).toList();
          }
          return messages;
        });
  }

  /// Send a message.
  /// Handles "Guardian Shield" spam routing for high-risk creators messaging Cadets.
  Future<void> sendMessage({
    required String chatId,
    required PlanetModel senderProfile,
    required String plaintext,
    required bool isSensitive,
    required String otherUid,
    String? clientPendingId,
    AgeGroup? recipientAgeGroup,
    bool isOfflineRelay = false,
    String messageType = 'text',
    Map<String, dynamic>? metadata,
    DateTime? expiresAt,
    MessageModel? replyTo,
    List<String>? mentions,
  }) {
    final previous = _sendQueueByChat[chatId] ?? Future<void>.value();
    final next = previous
        .catchError((_) {})
        .then(
          (_) => _sendMessageInternal(
            chatId: chatId,
            senderProfile: senderProfile,
            plaintext: plaintext,
            isSensitive: isSensitive,
            otherUid: otherUid,
            clientPendingId: clientPendingId,
            recipientAgeGroup: recipientAgeGroup,
            isOfflineRelay: isOfflineRelay,
            messageType: messageType,
            metadata: metadata,
            expiresAt: expiresAt,
            replyTo: replyTo,
            mentions: mentions,
          ),
        );

    _sendQueueByChat[chatId] = next;
    next.whenComplete(() {
      if (identical(_sendQueueByChat[chatId], next)) {
        _sendQueueByChat.remove(chatId);
      }
    });

    return next;
  }

  Future<void> _sendMessageInternal({
    required String chatId,
    required PlanetModel senderProfile,
    required String plaintext,
    required bool isSensitive,
    required String otherUid,
    String? clientPendingId,
    AgeGroup? recipientAgeGroup,
    required bool isOfflineRelay,
    String messageType = 'text',
    Map<String, dynamic>? metadata,
    DateTime? expiresAt,
    MessageModel? replyTo,
    List<String>? mentions,
  }) async {
    final senderUid = senderProfile.id;
    final isHighRisk = senderProfile.isHighRiskCreator;
    final isSpam = isHighRisk && recipientAgeGroup == AgeGroup.cadet;

    // 1. Encrypt message (Phase 2: passes otherUid for Signal Protocol)
    final encrypted = await MessageEncryptionService.encrypt(
      plaintext,
      chatId,
      otherUid,
    );

    // We use an RPC for chat metadata + message insertion to ensure atomicity
    await _sendChatMessageRpc(
      chatId: chatId,
      senderId: senderUid,
      content: encrypted,
      isSensitive: isSensitive,
      isOfflineRelay: isOfflineRelay,
      isSpam: isSpam,
      plaintextPreview: 'Encrypted message',
      messageType: messageType,
      metadata: {
        'client_pending_id': clientPendingId,
        if (clientPendingId != null)
          'client_sent_at': DateTime.now().toIso8601String(),
        if (replyTo != null) ...{
          'reply_to_id': replyTo.messageId,
          'reply_to_sender_id': replyTo.senderUid,
          'reply_to_name':
              replyTo.replyToName ?? replyTo.metadata['sender_name'] ?? 'User',
          'reply_to_preview':
              replyTo.decryptedContent ??
              (replyTo.content.length > 50
                  ? replyTo.content.substring(0, 50)
                  : replyTo.content),
        },
        if (mentions != null && mentions.isNotEmpty) 'mentions': mentions,
        if (metadata != null)
          ...metadata, // Moved to end to allow overrides if ever needed, but specifically to NOT be overridden by defaults
      },
      expiresAt: expiresAt,
    );
  }

  /// Send an encrypted media file (image/video).
  Future<void> sendMediaMessage({
    required String chatId,
    required PlanetModel senderProfile,
    required String otherUid,
    required String localFilePath,
    required String messageType, // 'image' or 'video'
    bool isSensitive = false,
    DateTime? expiresAt,
  }) async {
    final senderUid = senderProfile.id;
    final file = dart_io.File(localFilePath);
    if (!await file.exists()) {
      throw Exception('File not found: $localFilePath');
    }

    // 1. Generate media key and encrypt file
    final mediaKeyBytes = MediaEncryptionService.instance.generateMediaKey();
    final encryptedFile = await MediaEncryptionService.instance.encryptFile(
      file,
      mediaKeyBytes,
    );

    try {
      // 2. Upload to Supabase Storage Bucket
      final ext = dart_path.extension(localFilePath);
      final storagePath =
          '$chatId/${DateTime.now().millisecondsSinceEpoch}_$senderUid$ext.enc';

      await _client.storage
          .from('encrypted_chat_media')
          .upload(storagePath, encryptedFile);

      final String mediaUrl = _client.storage
          .from('encrypted_chat_media')
          .getPublicUrl(storagePath);

      // 3. Encrypt the mediaKey with the chat session key (so only the receiver can decrypt it)
      // We pass the mediaKey and URL as part of the JSON metadata payload
      // Alternatively, we encode it directly into the plaintext message string as JSON, which gets Double-Ratchet encrypted.
      final payloadJson = dart_convert.jsonEncode({
        'url': mediaUrl,
        'media_key': dart_convert.base64Encode(mediaKeyBytes),
        'storage_path': storagePath, // important for deletion later
      });

      // 4. Send the chat message containing the encrypted JSON payload
      await sendMessage(
        chatId: chatId,
        senderProfile: senderProfile,
        plaintext:
            payloadJson, // This JSON string will be AES-GCM encrypted and put into Double Ratchet
        isSensitive: isSensitive,
        otherUid: otherUid,
        messageType: messageType,
        expiresAt: expiresAt,
      );
    } finally {
      // Clean up the temporary encrypted file to save space
      if (await encryptedFile.exists()) {
        await encryptedFile.delete();
      }
    }
  }

  /// Accept a spam chat (moves it to main folder).
  Future<void> acceptChat(String chatId) async {
    await _client
        .from('chats')
        .update({
          'is_spam': false,
          'accepted_at': DateTime.now().toIso8601String(),
        })
        .eq('id', chatId);
  }

  /// Delete a spam message (or the entire chat) and trigger the 5-hour anti-stalking delay.
  Future<void> deleteSpamChat({
    required String chatId,
    required String minorUid,
    required String highRiskSenderUid,
  }) async {
    // 1. Delete the chat document
    await _client.from('chats').delete().eq('id', chatId);

    // 2. Trigger 5-hour status delay (stored in a separate table)
    await _client.from('status_delays').upsert({
      'minor_id': minorUid,
      'sender_id': highRiskSenderUid,
      'expires_at': DateTime.now()
          .add(const Duration(hours: 5))
          .toIso8601String(),
    });
  }

  /// Mark messages as read.
  Future<void> markAsRead(String chatId, String readerUid) async {
    try {
      debugPrint('MARK_AS_READ: Starting for $chatId by $readerUid');
      final response = await _client
          .from('messages')
          .update({'read': true, 'delivered': true})
          .eq('chat_id', chatId)
          .neq('sender_id', readerUid)
          .eq('read', false)
          .select();
      debugPrint(
        'MARK_AS_READ: Updated ${response.length} messages in $chatId',
      );
    } catch (e) {
      debugPrint('MARK_AS_READ: ERROR for $chatId: $e');
    }
  }

  /// Update an existing message with new content.
  Future<void> editMessage(String messageId, String newContent, String otherUid, String chatId) async {
    try {
      debugPrint('EDIT: Starting update for $messageId');
      
      // 1. Encrypt new content
      final encrypted = await MessageEncryptionService.encrypt(
        newContent,
        chatId,
        otherUid,
      );

      // 2. Fetch current metadata and merge 'is_edited'
      // We must preserve existing metadata like 'sparks' or reactions
      final currentResponse = await _client
          .from('messages')
          .select('metadata')
          .eq('id', messageId)
          .maybeSingle();

      Map<String, dynamic> metadata = {};
      if (currentResponse != null && currentResponse['metadata'] != null) {
        metadata = Map<String, dynamic>.from(currentResponse['metadata']);
      }
      
      metadata['is_edited'] = true;
      metadata['edited_at'] = DateTime.now().toIso8601String();

      // 3. Update Supabase
      final updateResponse = await _client
          .from('messages')
          .update({
            'content': encrypted,
            'metadata': metadata,
          })
          .eq('id', messageId)
          .select();
          
      if (updateResponse.isEmpty) {
         throw Exception('Message not found or not updated');
      }
          
      debugPrint('EDIT: Message $messageId updated successfully');
    } catch (e) {
      debugPrint('EDIT: Error updating message $messageId: $e');
      rethrow;
    }
  }

  /// Direct lookup of a server-side BIGINT ID using a client-side pending ID.
  /// This is used for real-time edit/recall resolution.
  Future<String?> resolveMessageIdFromPending(String pendingId) async {
    try {
      // Query for the numeric ID where the metadata contains our pending CID
      final response = await _client
          .from('messages')
          .select('id')
          .eq('metadata->>client_pending_id', pendingId)
          .maybeSingle();
      
      return response?['id']?.toString();
    } catch (e) {
      debugPrint('RESOLVE: Error resolving ID from $pendingId: $e');
      return null;
    }
  }

  /// Delete a single message for everyone
  Future<void> deleteMessageForEveryone(String messageId) async {
    await _client
        .from('messages')
        .update({
          'message_type': 'deleted',
          'content': null,
          'content_encrypted': null,
          'metadata': const {},
          'is_sensitive': false,
        })
        .eq('id', messageId);
  }

  /// Delete a single message for myself only
  Future<void> deleteMessageForMe(String messageId) async {
    await _client.rpc(
      'delete_message_for_me',
      params: {'p_message_id': int.parse(messageId)},
    );
  }

  /// Delete a chat conversation and all its messages.
  Future<void> deleteChat(String chatId) async {
    // 1. Delete all messages for this chat on the server
    await _client.from('messages').delete().eq('chat_id', chatId);

    // 2. Delete the chat record itself
    await _client.from('chats').delete().eq('id', chatId);
  }

  /// Updates the vanishing message duration for a chat.
  Future<void> updateVanishingDuration({
    required String chatId,
    required List<String> participants,
    required int? durationSeconds,
  }) async {
    await _client.from('chats').upsert({
      'id': chatId,
      'participants': participants,
      'vanishing_duration': durationSeconds,
    });
  }

  /// Leave a group chat.
  Future<void> leaveGroup(String chatId, String uid) async {
    final response = await _client
        .from('chats')
        .select('participants')
        .eq('id', chatId)
        .single();

    final List<String> participants = List<String>.from(
      response['participants'],
    );
    participants.remove(uid);

    if (participants.isEmpty) {
      await _client.from('chats').delete().eq('id', chatId);
    } else {
      await _client
          .from('chats')
          .update({'participants': participants})
          .eq('id', chatId);
    }
  }

  /// Update group information.
  Future<void> updateGroupInfo(
    String chatId, {
    String? name,
    String? avatarUrl,
  }) async {
    final updates = <String, dynamic>{};
    if (name != null) updates['name'] = name;
    if (avatarUrl != null) updates['group_avatar'] = avatarUrl;

    if (updates.isNotEmpty) {
      await _client.from('chats').update(updates).eq('id', chatId);
    }
  }

  /// Promote a member to admin.
  Future<void> promoteToAdmin(String chatId, String uid) async {
    final response = await _client
        .from('chats')
        .select('admins')
        .eq('id', chatId)
        .single();

    final List<String> admins = List<String>.from(response['admins'] ?? []);
    if (!admins.contains(uid)) {
      admins.add(uid);
      await _client.from('chats').update({'admins': admins}).eq('id', chatId);
    }
  }

  /// Remove a member from a group (Black Hole Member).
  Future<void> removeMember(String chatId, String uid) async {
    final response = await _client
        .from('chats')
        .select('participants, admins')
        .eq('id', chatId)
        .single();

    final List<String> participants = List<String>.from(
      response['participants'] ?? [],
    );
    final List<String> admins = List<String>.from(response['admins'] ?? []);

    participants.remove(uid);
    admins.remove(uid);

    await _client
        .from('chats')
        .update({'participants': participants, 'admins': admins})
        .eq('id', chatId);
  }

  /// Add a member to a group chat.
  Future<void> addMember(String chatId, String uid) async {
    final response = await _client
        .from('chats')
        .select('participants')
        .eq('id', chatId)
        .single();

    final List<String> participants = List<String>.from(
      response['participants'] ?? [],
    );
    if (!participants.contains(uid)) {
      participants.add(uid);
      await _client
          .from('chats')
          .update({'participants': participants})
          .eq('id', chatId);
    }
  }

  /// Update pinned messages for a chat (Anchor Stars).
  Future<void> updatePinnedMessages(
    String chatId,
    List<String> messageIds,
  ) async {
    await _client
        .from('chats')
        .update({'pinned_messages': messageIds})
        .eq('id', chatId);
  }

  /// Watch pinned messages for a chat.
  Stream<List<MessageModel>> watchPinnedMessages(String chatId) {
    return _client
        .from('chats')
        .stream(primaryKey: ['id'])
        .eq('id', chatId)
        .asyncMap((list) async {
          if (list.isEmpty) return [];
          final List<String> pinnedIds = List<String>.from(
            list.first['pinned_messages'] ?? [],
          );
          if (pinnedIds.isEmpty) return [];

          final response = await _client
              .from('messages')
              .select()
              .inFilter('id', pinnedIds);

          return (response as List)
              .map((m) => MessageModel.fromMap(m))
              .toList();
        });
  }

  /// Search for users by xparq_name or handle.
  Future<List<PlanetModel>> searchUsers(String query) async {
    if (query.isEmpty) return [];

    final response = await _client
        .from('profiles')
        .select()
        .or('xparq_name.ilike.%$query%,handle.ilike.%$query%')
        .limit(10);

    return (response as List)
        .map((data) => PlanetModel.fromMap(data, data['id']))
        .toList();
  }

  // ── Contact Requests ─────────────────────────────────────────────────────

  /// Send a contact info request.
  /// Creates a `contact_requests` record + sends a special message in the chat.
  Future<void> sendContactRequest({
    required String chatId,
    required PlanetModel senderProfile,
    required String targetUid,
  }) async {
    // 1. Upsert request record (idempotent — no duplicate pending requests)
    final requestRecord = {
      'requester_uid': senderProfile.id,
      'target_uid': targetUid,
      'status': 'pending',
      'created_at': DateTime.now().toIso8601String(),
      'responded_at': null,
      'chat_id': chatId,
    };
    await _client
        .from('contact_requests')
        .upsert(requestRecord, onConflict: 'requester_uid,target_uid');

    // 2. Send a special message so the target sees a request card in their chat
    await _sendChatMessageRpc(
      chatId: chatId,
      senderId: senderProfile.id,
      content: '[CONTACT_REQUEST]',
      isSensitive: false,
      isOfflineRelay: false,
      isSpam: false,
      plaintextPreview: 'Request contact info',
    );
  }

  /// Approve or reject a contact request.
  /// If approved, sends a contactCard message with the contact info.
  Future<void> respondToContactRequest({
    required String requestId,
    required bool approved,
    required String chatId,
    required PlanetModel ownerProfile,
    required String requesterUid,
  }) async {
    final now = DateTime.now().toIso8601String();

    await _client
        .from('contact_requests')
        .update({
          'status': approved ? 'approved' : 'rejected',
          'responded_at': now,
        })
        .eq('id', requestId);

    if (approved) {
      // Send contact card back to requester
      await _sendChatMessageRpc(
        chatId: chatId,
        senderId: ownerProfile.id,
        content: '[CONTACT_CARD]',
        isSensitive: false,
        isOfflineRelay: false,
        isSpam: false,
        plaintextPreview: 'Shared contact info',
      );
    }
  }

  /// Stream of per-user chat settings (pins, archives, silences).
  Stream<Map<String, Map<String, dynamic>>> watchChatSettings(String uid) {
    return _client
        .from('chat_settings')
        .stream(primaryKey: ['uid', 'chat_id'])
        .eq('uid', uid)
        .map((list) {
          final settings = <String, Map<String, dynamic>>{};
          for (final data in list) {
            final chatId = data['chat_id'] as String;
            settings[chatId] = data;
          }
          return settings;
        });
  }

  Future<void> toggleChatPin(String chatId, bool isPinned) async {
    await _client.rpc(
      'toggle_chat_pin',
      params: {'p_chat_id': chatId, 'p_is_pinned': isPinned},
    );
  }

  Future<void> toggleChatArchive(String chatId, bool isArchived) async {
    await _client.rpc(
      'toggle_chat_archive',
      params: {'p_chat_id': chatId, 'p_is_archived': isArchived},
    );
  }

  Future<void> silenceChat(
    String chatId,
    DateTime? until, {
    String? uid,
  }) async {
    await _client.rpc(
      'silence_chat',
      params: {
        'p_chat_id': chatId,
        'p_until': until?.toIso8601String(),
        'p_user_id': uid,
      },
    );
  }

  /// Toggle Spark (Like) for a specific message.
  /// Stores/Removes the user's UID in the 'sparks' list within the message metadata.
  /// Toggle Spark (Like) or Emoji Reaction for a specific message.
  /// Stores/Removes the user's UID in the 'sparks' list and the specific emoji in 'reactions' map.
  Future<void> toggleMessageSpark(
    String messageId,
    String uid, {
    String? reaction,
  }) async {
    try {
      // Use RPC to bypass RLS and ensure atomic update
      await _client.rpc(
        'toggle_message_reaction',
        params: {
          'p_message_id': messageId,
          'p_user_id': uid,
          'p_reaction': reaction ?? '❤️',
        },
      );
      debugPrint('SPARK: Toggled reaction for message $messageId by $uid via RPC');
    } catch (e) {
      debugPrint('SPARK: Error toggling spark for message $messageId: $e');
      rethrow;
    }
  }

  /// Get a minimal PlanetModel for a user (needed for quick replies).
  Future<PlanetModel?> getMinimalProfile(String uid) async {
    try {
      final doc = await _client
          .from('profiles')
          .select()
          .eq('id', uid)
          .single();
      return PlanetModel.fromMap(doc, uid);
    } catch (e) {
      debugPrint('ChatRepository: getMinimalProfile error: $e');
      return null;
    }
  }

  /// Mark messages as delivered.
  Future<void> markAsDelivered(String chatId, String readerUid) async {
    await _client
        .from('messages')
        .update({'delivered': true})
        .eq('chat_id', chatId)
        .neq('sender_id', readerUid)
        .eq('delivered', false);
  }

  /// Stream of unread counts for all chats the user is in.
  Stream<Map<String, int>> watchUnreadCounts(String uid) {
    return _client
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('read', false)
        .map((list) {
          debugPrint(
            'WATCH_UNREAD_COUNTS: Received ${list.length} raw unread rows',
          );
          final counts = <String, int>{};
          for (final data in list) {
            final senderId = data['sender_id'] as String;
            if (senderId == uid) continue; // Skip my own unread messages
            final chatId = data['chat_id'] as String;
            counts[chatId] = (counts[chatId] ?? 0) + 1;
          }
          debugPrint('WATCH_UNREAD_COUNTS: Final Map -> $counts');
          return counts;
        });
  }

  Future<Map<String, int>> getUnreadCounts(String uid) async {
    final response = await _client
        .from('messages')
        .select('chat_id')
        .eq('read', false)
        .neq('sender_id', uid);

    final counts = <String, int>{};
    for (final data in response) {
      final chatId = data['chat_id'] as String;
      counts[chatId] = (counts[chatId] ?? 0) + 1;
    }
    return counts;
  }

}
