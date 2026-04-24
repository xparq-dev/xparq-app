import 'package:supabase_flutter/supabase_flutter.dart';

/// Repository responsible for the lifecycle of contact information requests
/// between planetary residents.
class ContactRequestRepository {
  final SupabaseClient _client;

  ContactRequestRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  Future<void> sendContactRequest({
    required String requesterUid,
    required String targetUid,
    required dynamic
    senderProfile, // Keep dynamic if we don't want to import PlanetModel here, or just ignore for now
    required String chatId, // Added chatId to match expected signature
  }) async {
    try {
      final requestRecord = {
        'requester_uid': requesterUid,
        'target_uid': targetUid,
        'status': 'pending',
        'created_at': DateTime.now().toIso8601String(),
        'responded_at': null,
        'chat_id': chatId,
      };
      await _client
          .from('contact_requests')
          .upsert(requestRecord, onConflict: 'requester_uid,target_uid');
    } catch (e) {
      throw Exception('Failed to transmit contact request: $e');
    }
  }

  /// Updates the status of an existing contact request.
  Future<void> updateRequestStatus({
    required String requestId,
    required bool approved,
  }) async {
    try {
      await _client
          .from('contact_requests')
          .update({
            'status': approved ? 'approved' : 'rejected',
            'responded_at': DateTime.now().toIso8601String(),
          })
          .eq('id', requestId);
    } catch (e) {
      throw Exception('Failed to update request authorization: $e');
    }
  }
}
