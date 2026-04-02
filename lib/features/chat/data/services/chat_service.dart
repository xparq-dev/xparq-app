import 'dart:async';
import 'dart:convert' as dart_convert;
import 'dart:io' as dart_io;
import 'package:path/path.dart' as dart_path;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:xparq_app/core/enums/age_group.dart';
import 'package:xparq_app/features/auth/models/planet_model.dart';
import 'package:xparq_app/features/chat/domain/models/chat_model.dart';
import 'package:xparq_app/features/chat/data/repositories/chat_base_repository.dart';
import 'package:xparq_app/features/chat/data/repositories/message_repository.dart';
import 'package:xparq_app/features/chat/data/repositories/contact_request_repository.dart';
import 'package:xparq_app/features/chat/data/services/message_encryption_service.dart';
import 'package:xparq_app/features/chat/data/services/signal/media_encryption_service.dart';

/// Service responsible for orchestrating high-level chat workflows
/// that span multiple repositories and services.
class ChatService {
  final ChatBaseRepository _chatRepo;
  final MessageRepository _messageRepo;
  final ContactRequestRepository _contactRepo;
  final SupabaseClient _client;

  final Map<String, Future<void>> _sendQueueByChat = {};

  ChatService({
    required ChatBaseRepository chatRepo,
    required MessageRepository messageRepo,
    required ContactRequestRepository contactRepo,
    SupabaseClient? client,
  }) : _chatRepo = chatRepo,
       _messageRepo = messageRepo,
       _contactRepo = contactRepo,
       _client = client ?? Supabase.instance.client;

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
    unawaited(
      next.whenComplete(() {
        if (identical(_sendQueueByChat[chatId], next)) {
          _sendQueueByChat.remove(chatId);
        }
      }),
    );

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
    try {
      final senderUid = senderProfile.id;
      final isHighRisk = senderProfile.isHighRiskCreator;
      final isSpam = isHighRisk && recipientAgeGroup == AgeGroup.cadet;

      final encrypted = await MessageEncryptionService.encrypt(
        plaintext,
        chatId,
        otherUid,
      );

      await _messageRepo.insertMessageRpc(
        chatId: chatId,
        senderId: senderUid,
        content: encrypted,
        isSensitive: isSensitive,
        isOfflineRelay: isOfflineRelay,
        isSpam: isSpam,
        plaintextPreview: 'Encrypted message',
        messageType: messageType,
        metadata: {
          if (metadata != null) ...metadata,
          'client_pending_id': clientPendingId,
          if (clientPendingId != null)
            'client_sent_at': DateTime.now().toIso8601String(),
          if (replyTo != null) ...{
            'reply_to_id': replyTo.messageId,
            'reply_to_name': replyTo.metadata['sender_name'] ?? 'Sparq',
            'reply_to_preview':
                replyTo.decryptedContent ?? replyTo.content.substring(0, 50),
          },
          if (mentions != null && mentions.isNotEmpty) 'mentions': mentions,
        },
        expiresAt: expiresAt,
      );
    } catch (e) {
      throw Exception('Signal transmission failed: $e');
    }
  }

  Future<void> sendMediaMessage({
    required String chatId,
    required PlanetModel senderProfile,
    required String otherUid,
    required String localFilePath,
    required String messageType,
    bool isSensitive = false,
    DateTime? expiresAt,
  }) async {
    final file = dart_io.File(localFilePath);
    if (!await file.exists()) {
      throw Exception('Signal source file missing: $localFilePath');
    }

    final mediaKeyBytes = MediaEncryptionService.instance.generateMediaKey();
    final encryptedFile = await MediaEncryptionService.instance.encryptFile(
      file,
      mediaKeyBytes,
    );

    try {
      final ext = dart_path.extension(localFilePath);
      final storagePath =
          '$chatId/${DateTime.now().millisecondsSinceEpoch}_${senderProfile.id}$ext.enc';

      await _client.storage
          .from('encrypted_chat_media')
          .upload(storagePath, encryptedFile);

      final mediaUrl = _client.storage
          .from('encrypted_chat_media')
          .getPublicUrl(storagePath);

      final payloadJson = dart_convert.jsonEncode({
        'url': mediaUrl,
        'media_key': dart_convert.base64Encode(mediaKeyBytes),
        'storage_path': storagePath,
      });

      await sendMessage(
        chatId: chatId,
        senderProfile: senderProfile,
        plaintext: payloadJson,
        isSensitive: isSensitive,
        otherUid: otherUid,
        messageType: messageType,
        expiresAt: expiresAt,
      );
    } finally {
      if (await encryptedFile.exists()) {
        await encryptedFile.delete();
      }
    }
  }

  Future<void> sendContactRequest({
    required String chatId,
    required PlanetModel senderProfile,
    required String targetUid,
  }) async {
    await _contactRepo.sendContactRequest(
      requesterUid: senderProfile.id,
      targetUid: targetUid,
      senderProfile: senderProfile,
      chatId: chatId,
    );

    await _messageRepo.insertMessageRpc(
      chatId: chatId,
      senderId: senderProfile.id,
      content: '[CONTACT_REQUEST]',
      isSensitive: false,
      isOfflineRelay: false,
      isSpam: false,
      plaintextPreview: 'Request contact info',
    );
  }

  Future<void> respondToContactRequest({
    required String requestId,
    required bool approved,
    required String chatId,
    required PlanetModel ownerProfile,
    required String requesterUid,
  }) async {
    await _contactRepo.updateRequestStatus(
      requestId: requestId,
      approved: approved,
    );

    if (approved) {
      await _messageRepo.insertMessageRpc(
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

  Future<void> deleteSpamChat({
    required String chatId,
    required String minorUid,
    required String highRiskSenderUid,
  }) async {
    await _chatRepo.deleteChat(chatId);

    await _client.from('status_delays').upsert({
      'minor_id': minorUid,
      'sender_id': highRiskSenderUid,
      'expires_at': DateTime.now()
          .add(const Duration(hours: 5))
          .toIso8601String(),
    });
  }
}
