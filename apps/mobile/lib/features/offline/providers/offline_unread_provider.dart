import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xparq_app/features/offline/services/offline_chat_database.dart';

final offlineUnreadCountProvider =
    StateNotifierProvider<OfflineUnreadNotifier, int>((ref) {
      return OfflineUnreadNotifier();
    });

class OfflineUnreadNotifier extends StateNotifier<int> {
  OfflineUnreadNotifier() : super(0) {
    refresh();
  }

  Future<void> refresh() async {
    final count = await OfflineChatDatabase.instance.getUnreadCount();
    state = count;
  }

  Future<void> markAsRead(String peerId) async {
    await OfflineChatDatabase.instance.markAsRead(peerId);
    await refresh();
  }
}
