import 'package:flutter/foundation.dart';

class OfflineChatDatabase {
  static final OfflineChatDatabase instance = OfflineChatDatabase._init();

  OfflineChatDatabase._init();

  // Stub Database type to avoid importing sqflite
  dynamic get database => null;

  Future<void> initialize() async {
    debugPrint('[OfflineChatDatabase] Web Stub: Database disabled.');
  }

  Future<void> insertMessage({
    required String peerId,
    required String peerName,
    required String message,
    required bool isMe,
    DateTime? expiresAt,
  }) async {}

  Future<List<Map<String, dynamic>>> getMessages(String peerId) async => [];

  Future<int> getUnreadCount() async => 0;

  Future<void> markAsRead(String peerId) async {}

  Future<List<Map<String, dynamic>>> getRecentChats() async => [];

  Future<void> purgeOldMessages() async {}

  Future<void> clearAllHistory() async {}

  Future<void> deleteChatLocally(String chatId) async {}

  Future<void> clearAllData() async {}

  Future<void> clearSignalSessions() async {}

  Future<void> cacheSignalMessage(String messageId, String plaintext) async {}

  Future<Map<String, String>> getSignalMessageCache(
    List<String> messageIds,
  ) async => {};

  Future<void> addFriend(String peerId, String displayName) async {}

  Future<bool> isFriend(String peerId) async => false;

  Future<List<Map<String, dynamic>>> getFriends() async => [];

  Future<void> removeFriend(String peerId) async {}

  Future<void> upsertProfileCache(
    String uid,
    Map<String, dynamic> data,
  ) async {}

  Future<Map<String, dynamic>?> getProfileCache(String uid) async => null;

  Future<void> clearProfileCache({String? uid}) async {}

  Future<void> close() async {}

  Future<Map<String, List<Map<String, dynamic>>>> exportSignalData() async =>
      {};

  Future<void> importSignalData(
    Map<String, List<Map<String, dynamic>>> data,
  ) async {}
}
