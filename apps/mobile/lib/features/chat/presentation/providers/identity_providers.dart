import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Stores a persistent mapping of [server_uuid] -> [original_pending_id]
/// for the current app session. This is critical to ensure that even after 
/// a pending message is removed from local state, the UI continues to use
/// the same 'Identity Key' (ValueKey) for the message.
class MessageIdentityMapper extends StateNotifier<Map<String, String>> {
  MessageIdentityMapper() : super({});

  void mapIdentity(String dbId, String pendingId) {
    if (state[dbId] == pendingId) return;
    state = {...state, dbId: pendingId};
  }

  String getStableId(String dbId) {
    return state[dbId] ?? dbId;
  }
}

final messageIdentityMapperProvider =
    StateNotifierProvider<MessageIdentityMapper, Map<String, String>>((ref) {
  return MessageIdentityMapper();
});
