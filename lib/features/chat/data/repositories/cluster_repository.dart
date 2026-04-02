import 'package:supabase_flutter/supabase_flutter.dart';

/// Repository responsible for cluster (group chat) administrative operations,
/// such as membership management and metadata updates.
class ClusterRepository {
  final SupabaseClient _client;

  ClusterRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  /// Removes the specified [uid] from the cluster's participant and admin lists.
  Future<void> leaveGroup(String chatId, String uid) async {
    try {
      final response = await _client
          .from('chats')
          .select('participants')
          .eq('id', chatId)
          .single();

      final participants = List<String>.from(
        response['participants'] as Iterable? ?? [],
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
    } catch (e) {
      throw Exception('Failed to leave cluster: $e');
    }
  }

  /// Updates cluster-wide metadata such as [name] and [avatarUrl].
  Future<void> updateGroupInfo(
    String chatId, {
    String? name,
    String? avatarUrl,
  }) async {
    try {
      final updates = <String, dynamic>{};
      if (name != null) updates['name'] = name;
      if (avatarUrl != null) updates['group_avatar'] = avatarUrl;

      if (updates.isNotEmpty) {
        await _client.from('chats').update(updates).eq('id', chatId);
      }
    } catch (e) {
      throw Exception('Failed to update cluster info: $e');
    }
  }

  /// Grants administrative privileges to a specific [uid] within a cluster.
  Future<void> promoteToAdmin(String chatId, String uid) async {
    try {
      final response = await _client
          .from('chats')
          .select('admins')
          .eq('id', chatId)
          .single();

      final admins = List<String>.from((response['admins'] as Iterable?) ?? []);
      if (!admins.contains(uid)) {
        admins.add(uid);
        await _client.from('chats').update({'admins': admins}).eq('id', chatId);
      }
    } catch (e) {
      throw Exception('Failed to promote participant to admin: $e');
    }
  }

  /// Removes a member from the cluster and revokes any admin privileges.
  Future<void> removeMember(String chatId, String uid) async {
    try {
      final response = await _client
          .from('chats')
          .select('participants, admins')
          .eq('id', chatId)
          .single();

      final participants = List<String>.from(
        (response['participants'] as Iterable?) ?? [],
      );
      final admins = List<String>.from((response['admins'] as Iterable?) ?? []);

      participants.remove(uid);
      admins.remove(uid);

      await _client
          .from('chats')
          .update({'participants': participants, 'admins': admins})
          .eq('id', chatId);
    } catch (e) {
      throw Exception('Failed to remove participant from cluster: $e');
    }
  }

  /// Adds a new [uid] to the cluster's participant list.
  Future<void> addMember(String chatId, String uid) async {
    try {
      final response = await _client
          .from('chats')
          .select('participants')
          .eq('id', chatId)
          .single();

      final participants = List<String>.from(
        (response['participants'] as Iterable?) ?? [],
      );
      if (!participants.contains(uid)) {
        participants.add(uid);
        await _client
            .from('chats')
            .update({'participants': participants})
            .eq('id', chatId);
      }
    } catch (e) {
      throw Exception('Failed to add participant to cluster: $e');
    }
  }
}
