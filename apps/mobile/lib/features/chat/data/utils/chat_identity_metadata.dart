import 'package:xparq_app/features/auth/models/planet_model.dart';

Map<String, dynamic> mergeSenderIdentityMetadata(
  Map<String, dynamic>? metadata,
  PlanetModel senderProfile,
) {
  final merged = <String, dynamic>{
    if (metadata != null) ...metadata,
  };

  final displayName = senderProfile.xparqName.trim();
  final handle = senderProfile.handle?.trim();
  final avatarUrl = senderProfile.photoUrl.trim();

  if (displayName.isNotEmpty) {
    merged['sender_name'] = displayName;
  }
  if (handle != null && handle.isNotEmpty) {
    merged['sender_handle'] = handle;
  }
  if (avatarUrl.isNotEmpty) {
    merged['sender_avatar'] = avatarUrl;
  }

  return merged;
}

Map<String, dynamic> mergeParticipantIdentityMetadata(
  Map<String, dynamic>? metadata, {
  required String uid,
  required String? displayName,
  String? handle,
  String? avatarUrl,
}) {
  final normalizedName = displayName?.trim();
  final normalizedHandle = handle?.trim();
  final normalizedAvatar = avatarUrl?.trim();

  if (normalizedName == null || normalizedName.isEmpty) {
    return metadata == null ? <String, dynamic>{} : Map<String, dynamic>.from(metadata);
  }

  final merged = <String, dynamic>{
    if (metadata != null) ...metadata,
  };

  final participantNames = _cloneStringMap(
    merged['participant_names'] ?? merged['participantNames'],
  );
  participantNames[uid] = normalizedName;
  merged['participant_names'] = participantNames;

  final participantHandles = _cloneStringMap(
    merged['participant_handles'] ?? merged['participantHandles'],
  );
  if (normalizedHandle != null && normalizedHandle.isNotEmpty) {
    participantHandles[uid] = normalizedHandle;
  }
  if (participantHandles.isNotEmpty) {
    merged['participant_handles'] = participantHandles;
  }

  final participantPhotos = _cloneStringMap(
    merged['participant_photos'] ?? merged['participantPhotos'],
  );
  if (normalizedAvatar != null && normalizedAvatar.isNotEmpty) {
    participantPhotos[uid] = normalizedAvatar;
  }
  if (participantPhotos.isNotEmpty) {
    merged['participant_photos'] = participantPhotos;
  }

  return merged;
}

Map<String, dynamic> mergeParticipantProfileIntoChatMetadata(
  Map<String, dynamic>? metadata,
  PlanetModel profile,
) {
  return mergeParticipantIdentityMetadata(
    metadata,
    uid: profile.id,
    displayName: profile.xparqName,
    handle: profile.handle,
    avatarUrl: profile.photoUrl,
  );
}

bool chatMetadataHasParticipantName(
  Map<String, dynamic>? metadata,
  String uid,
) {
  if (metadata == null) return false;

  final participantNames = _cloneStringMap(
    metadata['participant_names'] ?? metadata['participantNames'],
  );
  final name = participantNames[uid]?.trim();
  return name != null && name.isNotEmpty && name != 'Explorer';
}

Map<String, String> _cloneStringMap(dynamic value) {
  if (value is! Map) return <String, String>{};

  return value.map(
    (key, entry) => MapEntry(
      key.toString(),
      entry?.toString() ?? '',
    ),
  );
}
