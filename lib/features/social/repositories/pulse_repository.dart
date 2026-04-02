// lib/features/social/repositories/pulse_repository.dart

import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:xparq_app/core/enums/age_group.dart';
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
      'pulse_type': pulseType,
      'is_nsfw': isNsfwActual,
      'created_at': DateTime.now().toIso8601String(),
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
    int limit = 50,
    int offset = 0,
    bool safeOnly = true,
    AgeGroup? callerAgeGroup,
    DateTime? since,
    String pulseType = 'post',
  }) async {
    var query = _client.from('pulses').select().eq('pulse_type', pulseType);

    if (since != null) {
      query = query.gte('created_at', since.toIso8601String());
    }

    // Protection logic
    if (callerAgeGroup == AgeGroup.cadet) {
      query = query.eq('is_nsfw', false).eq('author_is_high_risk', false);
    } else if (safeOnly) {
      query = query.eq('is_nsfw', false);
    }

    final List<dynamic> response = await query
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);
    return response.map((data) => PulseModel.fromMap(data)).toList();
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

  Future<void> toggleWarp(String pulseId, String uid) async {
    final existing = await _client
        .from('pulse_interactions')
        .select()
        .eq('pulse_id', pulseId)
        .eq('uid', uid)
        .eq('type', 'warp')
        .maybeSingle();

    if (existing != null) {
      // Unwarp
      await _client
          .from('pulse_interactions')
          .delete()
          .eq('id', existing['id']);
      await _client.rpc('decrement_warp_count', params: {'p_id': pulseId});
    } else {
      // Warp
      await _client.from('pulse_interactions').insert({
        'pulse_id': pulseId,
        'uid': uid,
        'type': 'warp',
      });
      await _client.rpc('increment_warp_count', params: {'p_id': pulseId});
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
    await _client.from('pulses').delete().eq('id', pulse.id);

    // Update user's pulse metrics (ideally handled via DB triggers for consistency)
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
            'total_pulse_count': max(0, total - 1),
            if (pulse.isNsfw) 'nsfw_pulse_count': max(0, nsfw - 1),
          })
          .eq('id', pulse.uid);
    }
  }
}
