// lib/features/social/repositories/pulse_repository.dart

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:xparq_app/shared/enums/age_group.dart';
import 'package:xparq_app/features/auth/models/planet_model.dart';
import 'package:xparq_app/features/social/models/echo_model.dart';
import 'package:xparq_app/features/social/models/pulse_model.dart';

class PulseRepository {
  final SupabaseClient _client;

  PulseRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  // ── Create ─────────────────────────────────────────────────────────────────

  Future<void> createPulse({
    required String uid,
    required String content,
    String? imageUrl,
    String? videoUrl,
    String? moodEmoji,
    String? moodLabel,
    String? locationName,
    required PlanetModel authorProfile,
    bool isNsfw = false,
    String pulseType = 'post',
  }) async {
    final isNsfwActual = isNsfw && authorProfile.isExplorer;

    final pulseData = {
      'uid': uid,
      'author_name': authorProfile.xparqName,
      'author_avatar': authorProfile.photoUrl,
      'author_planet_type': authorProfile.ageGroup.name,
      'author_is_high_risk': authorProfile.isHighRiskCreator,
      'content': content,
      'image_url': imageUrl,
      'video_url': videoUrl,
      'mood_emoji': moodEmoji,
      'mood_label': moodLabel,
      'location_name': locationName,
      'pulse_type': pulseType,
      'is_nsfw': isNsfwActual,
      'created_at': DateTime.now().toUtc().toIso8601String(),
    };

    // Transactional-like update in Supabase (Postgres)
    // We update both in one go if possible, or use a RPC if atomicity is critical.
    // For now, simple sequential updates.
    await _client.from('pulses').insert(pulseData);

    // Update user's pulse metrics
    final updates = {
      'total_pulse_count': authorProfile.totalPulseCount + 1,
      if (isNsfwActual) 'nsfw_pulse_count': authorProfile.nsfwPulseCount + 1,
    };
    await _client.from('profiles').update(updates).eq('id', uid);
  }

  // ── Read ──────────────────────────────────────────────────────────────────

  Future<List<PulseModel>> getGlobalOrbit({
    int limit = 20,
    int offset = 0,
    bool safeOnly = true,
    AgeGroup? callerAgeGroup,
    DateTime? since,
    String? pulseType,
  }) async {
    // We now fetch both 'post' and 'warp' to have a unified activity feed by default
    var query = _client.from('pulses').select();
    
    if (pulseType != null) {
      query = query.eq('pulse_type', pulseType);
    } else {
      query = query.inFilter('pulse_type', ['post', 'warp']);
    }

    if (since != null) {
      query = query.gte('created_at', since.toIso8601String());
    }

    // Protection logic
    if (callerAgeGroup == AgeGroup.cadet) {
      query = query.eq('is_nsfw', false).eq('author_is_high_risk', false);
    } else if (safeOnly) {
      query = query.eq('is_nsfw', false);
    }

    // STRICT SORTING: Always use created_at descending
    final List<dynamic> response = await query
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);

    return response.map((data) => PulseModel.fromMap(data)).toList();
  }

  /// REALTIME: Watch the global orbit for changes
  Stream<List<PulseModel>> watchGlobalOrbit({
    bool safeOnly = true,
    AgeGroup? callerAgeGroup,
  }) {
    var streamQuery = _client
        .from('pulses')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false);

    // Note: Supabase client-side streaming filtering is basic.
    // For complex filters, we filter the stream results in the map.
    return streamQuery.map((list) {
      return list
          .where((data) {
            final isWarpOrPost = data['pulse_type'] == 'post' || data['pulse_type'] == 'warp';
            if (!isWarpOrPost) return false;

            if (callerAgeGroup == AgeGroup.cadet) {
              return data['is_nsfw'] == false && data['author_is_high_risk'] == false;
            } else if (safeOnly) {
              return data['is_nsfw'] == false;
            }
            return true;
          })
          .map((data) => PulseModel.fromMap(data))
          .toList();
    });
  }

  Future<List<PulseModel>> getActiveSupernovas({
    bool safeOnly = true,
    AgeGroup? callerAgeGroup,
  }) async {
    // Supernovas are stories from the last 24 hours
    final cutoff = DateTime.now().subtract(const Duration(hours: 24));

    var query = _client
        .from('pulses')
        .select()
        .eq('pulse_type', 'story')
        .gte('created_at', cutoff.toIso8601String());

    // Protection logic
    if (callerAgeGroup == AgeGroup.cadet) {
      query = query.eq('is_nsfw', false).eq('author_is_high_risk', false);
    } else if (safeOnly) {
      query = query.eq('is_nsfw', false);
    }

    final List<dynamic> response = await query.order(
      'created_at',
      ascending: false,
    );
    return response.map((data) => PulseModel.fromMap(data)).toList();
  }

  Future<List<PulseModel>> getUserPulses(
    String uid, {
    int limit = 50,
    int offset = 0,
    bool safeOnly = true,
  }) async {
    var query = _client.from('pulses').select().eq('uid', uid);
    if (safeOnly) query = query.eq('is_nsfw', false);

    final List<dynamic> response = await query
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);
    return response.map((data) => PulseModel.fromMap(data)).toList();
  }

  Future<List<PulseModel>> getUserWarps(
    String uid, {
    bool safeOnly = true,
  }) async {
    if (uid.isEmpty) return [];

    try {
      final List<dynamic> warps = await _client
          .from('pulse_interactions')
          .select('pulse_id, pulses(*)')
          .eq('uid', uid)
          .eq('type', 'warp')
          .limit(50);

      final pulses = <PulseModel>[];
      for (var warp in warps) {
        final pulseData = warp['pulses'];
        if (pulseData != null) {
          final p = PulseModel.fromMap(pulseData);
          if (!safeOnly || !p.isNsfw) {
            pulses.add(p);
          }
        }
      }
      return pulses;
    } catch (e) {
      debugPrint('getUserWarps error: $e');
      rethrow;
    }
  }

  Stream<PulseModel?> watchPulse(String pulseId) {
    return _client.from('pulses').stream(primaryKey: ['id']).map((list) {
      final items = list.where((data) => data['id'].toString() == pulseId);
      return items.isNotEmpty ? PulseModel.fromMap(items.first) : null;
    });
  }

  // ── Spark (Like) ──────────────────────────────────────────────────────────

  Future<void> toggleSpark(String pulseId, String uid) async {
    // Check if interaction exists
    final existing = await _client
        .from('pulse_interactions')
        .select()
        .eq('pulse_id', pulseId)
        .eq('uid', uid)
        .eq('type', 'spark')
        .maybeSingle();

    if (existing != null) {
      // Unspark
      await _client
          .from('pulse_interactions')
          .delete()
          .eq('id', existing['id']);
      // Decrement count (normally handled by triggers in Supabase for sanity, but here manually)
      await _client.rpc('decrement_spark_count', params: {'p_id': pulseId});
    } else {
      // Spark
      await _client.from('pulse_interactions').insert({
        'pulse_id': pulseId,
        'uid': uid,
        'type': 'spark',
      });
      await _client.rpc('increment_spark_count', params: {'p_id': pulseId});
    }
  }

  Future<bool> hasSparked(String pulseId, String uid) async {
    final response = await _client
        .from('pulse_interactions')
        .select()
        .eq('pulse_id', pulseId)
        .eq('uid', uid)
        .eq('type', 'spark')
        .maybeSingle();
    return response != null;
  }

  Future<int> getTotalUserSparks(String uid) async {
    try {
      final List<dynamic> response = await _client
          .from('pulses')
          .select('spark_count')
          .eq('uid', uid);
      
      int total = 0;
      for (var row in response) {
        total += (row['spark_count'] as num?)?.toInt() ?? 0;
      }
      return total;
    } catch (e) {
      debugPrint('getTotalUserSparks error: $e');
      return 0; // Return 0 on error to avoid breaking UI
    }
  }

  Future<int> getTotalUserPulses(String uid) async {
    try {
      // Fetching only 'id' and getting the length is a safe way to count 
      // in the current SDK version if 'count' getter is not direct.
      final response = await _client
          .from('pulses')
          .select('id')
          .eq('uid', uid);
      
      if (response is List) {
        return response.length;
      }
      return 0;
    } catch (e) {
      debugPrint('getTotalUserPulses error: $e');
      return 0;
    }
  }

  // ── Echo (Comment) ────────────────────────────────────────────────────────

  Stream<List<EchoModel>> watchEchoes(String pulseId) {
    return _client
        .from('echoes')
        .stream(primaryKey: ['id'])
        .eq('pulse_id', pulseId)
        .order('created_at', ascending: true)
        .map((list) => list.map((data) => EchoModel.fromMap(data)).toList());
  }

  Future<void> addEcho({
    required String pulseId,
    required String uid,
    required String content,
    required PlanetModel authorProfile,
  }) async {
    await _client.from('echoes').insert({
      'pulse_id': pulseId,
      'uid': uid,
      'content': content,
      'author_name': authorProfile.xparqName,
      'author_avatar': authorProfile.photoUrl,
    });
    await _client.rpc('increment_echo_count', params: {'p_id': pulseId});
  }

  Future<void> deleteEcho({
    required String pulseId,
    required String echoId,
  }) async {
    await _client.from('echoes').delete().eq('id', echoId);
    await _client.rpc('decrement_echo_count', params: {'p_id': pulseId});
  }

  // ── Warp (Repost) ─────────────────────────────────────────────────────────

  Future<void> toggleWarp({
    required String pulseId,
    required String uid,
    required PlanetModel authorProfile,
    required PulseModel originalPulse,
  }) async {
    final existing = await _client
        .from('pulse_interactions')
        .select()
        .eq('pulse_id', pulseId)
        .eq('uid', uid)
        .eq('type', 'warp')
        .maybeSingle();

    if (existing != null) {
      // 1. Unwarp interaction
      await _client
          .from('pulse_interactions')
          .delete()
          .eq('id', existing['id']);
      await _client.rpc('decrement_warp_count', params: {'p_id': pulseId});

      // 2. Remove from Feed (Delete the 'warp' type pulse)
      await _client
          .from('pulses')
          .delete()
          .eq('uid', uid)
          .eq('pulse_type', 'warp')
          .eq('origin_id', pulseId);

      // 3. Decrement user pulse count
      await _client.from('profiles').update({
        'total_pulse_count': (authorProfile.totalPulseCount - 1).clamp(0, 999999)
      }).eq('id', uid);
    } else {
      // 1. Add Warp interaction
      await _client.from('pulse_interactions').insert({
        'pulse_id': pulseId,
        'uid': uid,
        'type': 'warp',
      });
      await _client.rpc('increment_warp_count', params: {'p_id': pulseId});

      // 2. Add to Feed (Create a 'warp' type pulse)
      final warpPulseData = {
        'uid': uid,
        'author_name': authorProfile.xparqName,
        'author_avatar': authorProfile.photoUrl,
        'author_planet_type': authorProfile.ageGroup.name,
        'author_is_high_risk': authorProfile.isHighRiskCreator,
        'content': originalPulse.content, // Keep original content for preview
        'image_url': originalPulse.imageUrl,
        'video_url': originalPulse.videoUrl,
        'pulse_type': 'warp',
        'origin_id': pulseId,
        'is_nsfw': originalPulse.isNsfw,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      };
      await _client.from('pulses').insert(warpPulseData);

      // 3. Increment user pulse count
      await _client.from('profiles').update({
        'total_pulse_count': authorProfile.totalPulseCount + 1
      }).eq('id', uid);
    }
  }

  Future<bool> hasWarped(String pulseId, String uid) async {
    final response = await _client
        .from('pulse_interactions')
        .select()
        .eq('pulse_id', pulseId)
        .eq('uid', uid)
        .eq('type', 'warp')
        .maybeSingle();
    return response != null;
  }

  // ── Edit & Delete ─────────────────────────────────────────────────────────

  Future<void> updatePulse({
    required String pulseId,
    required String newContent,
  }) async {
    await _client
        .from('pulses')
        .update({
          'content': newContent,
          'edited_at': DateTime.now().toIso8601String(),
        })
        .eq('id', pulseId);
  }

  Future<void> deletePulse(PulseModel pulse) async {
    // 1. Clear related interactions and echoes
    await _client.from('pulse_interactions').delete().eq('pulse_id', pulse.id);
    await _client.from('echoes').delete().eq('pulse_id', pulse.id);
    
    // 2. Identify the target for deep cleaning
    // 3. AGGRESSIVE CLEANUP: 
    // This is the "Wise" part to clear legacy buggy duplicates
    await _client.from('pulses').delete().match({
      'uid': pulse.uid,
      'content': pulse.content,
    });

    // Also specifically target the origin/id to be sure
    await _client.from('pulses').delete().eq('id', pulse.id);
    await _client.from('pulses').delete().eq('origin_id', pulse.id);
    if (pulse.originId != null) {
      await _client.from('pulses').delete().eq('id', pulse.originId!);
    }

    // Update user's pulse metrics
    final profileData = await _client
        .from('profiles')
        .select('total_pulse_count, nsfw_pulse_count')
        .eq('id', pulse.uid)
        .maybeSingle();

    if (profileData != null) {
      final total = profileData['total_pulse_count'] as int? ?? 0;
      final nsfw = profileData['nsfw_pulse_count'] as int? ?? 0;

      await _client
          .from('profiles')
          .update({
            'total_pulse_count': (total - 1).clamp(0, 999999),
            if (pulse.isNsfw) 'nsfw_pulse_count': (nsfw - 1).clamp(0, 999999),
          })
          .eq('id', pulse.uid);
    }
  }
}
