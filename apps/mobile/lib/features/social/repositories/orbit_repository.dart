import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class OrbitRepository {
  final SupabaseClient _client;

  OrbitRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  // ── Send Request ──────────────────────────────────────────────────────────

  Future<void> sendOrbitRequest(String currentUid, String targetUid) async {
    // In Supabase, we just insert one row into the orbits table.
    // follower_id: currentUid, followed_id: targetUid
    await _client.from('orbits').insert({
      'follower_id': currentUid,
      'followed_id': targetUid,
      'status': 'pending',
    });
  }

  // ── Incoming Requests ─────────────────────────────────────────────────────

  /// Stream of users who want to orbit me (status == 'pending')
  Stream<List<String>> watchIncomingRequests(String currentUid) {
    return _client
        .from('orbits')
        .stream(primaryKey: ['id'])
        .map(
          (list) => list
              .where(
                (data) =>
                    data['followed_id'] == currentUid &&
                    data['status'] == 'pending',
              )
              .map((data) => data['follower_id'] as String)
              .toList(),
        );
  }

  // ── Accept Request ────────────────────────────────────────────────────────

  Future<void> acceptRequest(String currentUid, String senderUid) async {
    // 1. Update the record where senderUid is following currentUid
    await _client
        .from('orbits')
        .update({'status': 'accepted'})
        .eq('follower_id', senderUid)
        .eq('followed_id', currentUid);

    // 2. Create or update a reciprocal orbit (mutual friendship)
    // Accept = Follow Back
    await _client.from('orbits').upsert({
      'follower_id': currentUid,
      'followed_id': senderUid,
      'status': 'accepted',
    }, onConflict: 'follower_id,followed_id');
  }

  // ── Reject/Cancel Request ─────────────────────────────────────────────────

  Future<void> rejectRequest(String currentUid, String senderUid) async {
    // Delete the record where senderUid followed currentUid
    await _client
        .from('orbits')
        .delete()
        .eq('follower_id', senderUid)
        .eq('followed_id', currentUid);
  }

  /// Remove/Cancel orbit. For mutual connections, this should remove both directions.
  Future<void> removeOrbit(String currentUid, String targetUid) async {
    try {
      debugPrint(
        'ORBIT_REPO: Starting Nuclear Reset for $currentUid and $targetUid',
      );

      // 1. Delete My follow of them (A -> B)
      final res1 = await _client.from('orbits').delete().match({
        'follower_id': currentUid,
        'followed_id': targetUid,
      }).select();
      debugPrint('ORBIT_REPO: Deleted A->B count: ${res1.length}');

      // 2. Delete Their follow of me (B -> A)
      final res2 = await _client.from('orbits').delete().match({
        'follower_id': targetUid,
        'followed_id': currentUid,
      }).select();
      debugPrint('ORBIT_REPO: Deleted B->A count: ${res2.length}');

      debugPrint(
        'ORBIT_REPO: Reset Complete. Total rows removed: ${res1.length + res2.length}',
      );
    } catch (e) {
      debugPrint('ORBIT_REPO: ERROR in removeOrbit: $e');
      rethrow;
    }
  }

  /// Watch map of UIDs -> Status (e.g. 'pending', 'accepted').
  /// currentUid is the FOLLOWER.
  Stream<Map<String, String>> watchOrbitingStatus(String currentUid) {
    return _client.from('orbits').stream(primaryKey: ['id']).map((list) {
      final map = <String, String>{};
      for (var data in list) {
        if (data['follower_id'] == currentUid) {
          map[data['followed_id'] as String] = data['status'] as String;
        }
      }
      return map;
    });
  }

  /// Watch subcollection equivalents (followers or following list).
  Stream<List<String>> watchOrbitSubcollection(String uid, String collection) {
    if (collection == 'orbiting') {
      // Users I am following
      return _client
          .from('orbits')
          .stream(primaryKey: ['id'])
          .map(
            (list) => list
                .where(
                  (data) =>
                      data['follower_id'] == uid &&
                      data['status'] == 'accepted',
                )
                .map((data) => data['followed_id'] as String)
                .toList(),
          );
    } else {
      // Users following me
      return _client
          .from('orbits')
          .stream(primaryKey: ['id'])
          .map(
            (list) => list
                .where(
                  (data) =>
                      data['followed_id'] == uid &&
                      data['status'] == 'accepted',
                )
                .map((data) => data['follower_id'] as String)
                .toList(),
          );
    }
  }
}
