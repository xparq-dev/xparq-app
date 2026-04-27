import 'package:xparq_app/features/auth/models/planet_model.dart';
import 'package:xparq_app/features/chat/domain/models/chat_identity.dart';
import 'package:xparq_app/features/chat/domain/models/chat_model.dart';

bool isPlaceholderProfile(PlanetModel? profile) {
  if (profile == null) return true;

  final name = profile.xparqName.trim();
  final handle = profile.handle?.trim() ?? '';
  final photoUrl = profile.photoUrl.trim();

  return name.isEmpty ||
      (name == 'Explorer' && handle.isEmpty && photoUrl.isEmpty);
}

String formatChatProfileName(PlanetModel profile) {
  final name = profile.xparqName.trim();
  final handle = profile.handle?.trim();

  if (handle != null && handle.isNotEmpty) {
    return '$name (@$handle)';
  }
  return name;
}

String resolveDirectChatDisplayName({
  required ChatModel? chat,
  required String myUid,
  required String otherUid,
  required String savedMeLabel,
  PlanetModel? profile,
  ChatFallbackIdentity? fallbackIdentity,
}) {
  final participants = chat?.participants ?? const <String>[];
  final isSelfChat = participants.isNotEmpty && participants.every((p) => p == myUid);
  if (isSelfChat) return savedMeLabel;

  if (!isPlaceholderProfile(profile) && profile != null) {
    return formatChatProfileName(profile);
  }

  final metadataName = _resolveNameFromChatMetadata(chat, otherUid);
  if (metadataName != null) return metadataName;

  final fallbackDisplayName = fallbackIdentity?.displayName?.trim();
  if (fallbackDisplayName != null &&
      fallbackDisplayName.isNotEmpty &&
      fallbackDisplayName != 'Explorer') {
    return fallbackDisplayName;
  }

  final directChatName = chat?.name?.trim();
  if (directChatName != null &&
      directChatName.isNotEmpty &&
      directChatName != 'Explorer') {
    return directChatName;
  }

  return 'Explorer';
}

String? resolveDirectChatAvatarUrl({
  required ChatModel? chat,
  required String otherUid,
  PlanetModel? profile,
  ChatFallbackIdentity? fallbackIdentity,
}) {
  if (profile != null && profile.photoUrl.trim().isNotEmpty) {
    return profile.photoUrl.trim();
  }

  final metadata = chat?.metadata ?? const <String, dynamic>{};
  final participantPhotos = _asStringMap(
    metadata['participant_photos'] ?? metadata['participantPhotos'],
  );
  final mappedPhoto = participantPhotos[otherUid]?.trim();
  if (mappedPhoto != null && mappedPhoto.isNotEmpty) {
    return mappedPhoto;
  }

  final candidate = _firstNonBlankString([
    fallbackIdentity?.avatarUrl,
    metadata['other_participant_photo'],
    metadata['otherParticipantPhoto'],
    metadata['owner_photo'],
    metadata['ownerPhoto'],
    metadata['photo_url'],
    metadata['photoUrl'],
    metadata['sender_avatar'],
    metadata['senderAvatar'],
  ]);

  return candidate;
}

String? _resolveNameFromChatMetadata(ChatModel? chat, String otherUid) {
  final metadata = chat?.metadata ?? const <String, dynamic>{};

  final participantNames = _asStringMap(
    metadata['participant_names'] ?? metadata['participantNames'],
  );
  final participantHandles = _asStringMap(
    metadata['participant_handles'] ?? metadata['participantHandles'],
  );

  final mappedName = participantNames[otherUid]?.trim();
  final mappedHandle = participantHandles[otherUid]?.trim();
  if (mappedName != null && mappedName.isNotEmpty && mappedName != 'Explorer') {
    if (mappedHandle != null && mappedHandle.isNotEmpty) {
      return '$mappedName (@$mappedHandle)';
    }
    return mappedName;
  }

  final fallbackName = _firstNonBlankString([
    metadata['other_participant_name'],
    metadata['otherParticipantName'],
    metadata['owner_name'],
    metadata['ownerName'],
    metadata['display_name'],
    metadata['displayName'],
    metadata['sender_name'],
    metadata['senderName'],
  ]);

  if (fallbackName == null || fallbackName == 'Explorer') {
    return null;
  }

  final fallbackHandle = _firstNonBlankString([
    metadata['other_participant_handle'],
    metadata['otherParticipantHandle'],
    metadata['owner_handle'],
    metadata['ownerHandle'],
    metadata['handle'],
    metadata['sender_handle'],
    metadata['senderHandle'],
  ]);

  if (fallbackHandle != null && fallbackHandle.isNotEmpty) {
    return '$fallbackName (@$fallbackHandle)';
  }

  return fallbackName;
}

Map<String, String> _asStringMap(dynamic value) {
  if (value is! Map) return const <String, String>{};

  return value.map(
    (key, entry) => MapEntry(
      key.toString(),
      entry?.toString() ?? '',
    ),
  );
}

String? _firstNonBlankString(List<dynamic> values) {
  for (final value in values) {
    final text = value?.toString().trim();
    if (text != null && text.isNotEmpty) return text;
  }
  return null;
}
