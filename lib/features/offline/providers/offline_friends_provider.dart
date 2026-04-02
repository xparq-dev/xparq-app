import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xparq_app/features/offline/services/offline_chat_database.dart';

class OfflineFriend {
  final String peerId;
  final String displayName;
  final int addedAt;

  OfflineFriend({
    required this.peerId,
    required this.displayName,
    required this.addedAt,
  });

  factory OfflineFriend.fromMap(Map<String, dynamic> map) {
    return OfflineFriend(
      peerId: map['peerId'] as String,
      displayName: map['displayName'] as String,
      addedAt: map['addedAt'] as int,
    );
  }
}

class OfflineFriendsNotifier extends StateNotifier<List<OfflineFriend>> {
  OfflineFriendsNotifier() : super([]) {
    refreshFriends();
  }

  Future<void> refreshFriends() async {
    final friendsData = await OfflineChatDatabase.instance.getFriends();
    state = friendsData.map((m) => OfflineFriend.fromMap(m)).toList();
  }

  Future<void> removeFriend(String peerId) async {
    await OfflineChatDatabase.instance.removeFriend(peerId);
    await refreshFriends();
  }

  Future<void> addFriend(String peerId, String name) async {
    await OfflineChatDatabase.instance.addFriend(peerId, name);
    await refreshFriends();
  }
}

final offlineFriendsProvider =
    StateNotifierProvider<OfflineFriendsNotifier, List<OfflineFriend>>((ref) {
      return OfflineFriendsNotifier();
    });
