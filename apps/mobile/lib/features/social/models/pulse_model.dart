// import 'package:cloud_firestore/cloud_firestore.dart'; // Removed for Supabase

class PulseModel {
  final String id;
  final String uid;
  final String authorName;
  final String authorAvatar;
  final String authorPlanetType;
  final String content;
  final String? imageUrl;
  final String? videoUrl;
  final String? moodEmoji;
  final String? moodLabel;
  final String? locationName;
  final String type; // 'post' or 'story'
  final bool isNsfw; // ← NEW: age-gate flag
  final bool authorIsHighRisk; // ← NEW: Guardian Shield flag
  final int sparkCount;
  final int echoCount;
  final int warpCount;
  final DateTime createdAt;
  final String? locationGeohash;
  final String? originId;

  PulseModel({
    required this.id,
    required this.uid,
    required this.authorName,
    required this.authorAvatar,
    required this.authorPlanetType,
    required this.content,
    required this.createdAt,
    this.imageUrl,
    this.videoUrl,
    this.moodEmoji,
    this.moodLabel,
    this.locationName,
    this.type = 'post',
    this.isNsfw = false, // safe default
    this.authorIsHighRisk = false, // Guardian Shield flag
    this.sparkCount = 0,
    this.echoCount = 0,
    this.warpCount = 0,
    this.locationGeohash,
    this.originId,
  });

  factory PulseModel.fromMap(Map<String, dynamic> data) {
    return PulseModel(
      id: data['id']?.toString() ?? '',
      uid: data['uid']?.toString() ?? '',
      authorName:
          data['author_name']?.toString() ??
          (data['author_meta'] as Map?)?['name']?.toString() ??
          'Unknown iXPARQer',
      authorAvatar:
          data['author_avatar']?.toString() ??
          (data['author_meta'] as Map?)?['avatar']?.toString() ??
          '',
      authorPlanetType:
          data['author_planet_type']?.toString() ??
          (data['author_meta'] as Map?)?['planet_type']?.toString() ??
          'Cadet',
      content: data['content']?.toString() ?? '',
      imageUrl: data['imageUrl']?.toString() ?? data['image_url']?.toString(),
      videoUrl: data['videoUrl']?.toString() ?? data['video_url']?.toString(),
      moodEmoji: data['mood_emoji']?.toString(),
      moodLabel: data['mood_label']?.toString(),
      locationName: data['location_name']?.toString(),
      type:
          data['pulse_type']?.toString() ?? data['type']?.toString() ?? 'post',
      isNsfw: (data['is_nsfw'] == true || data['isNsfw'] == true),
      authorIsHighRisk:
          (data['author_is_high_risk'] == true ||
          data['authorIsHighRisk'] == true),
      sparkCount:
          (data['spark_count'] as num?)?.toInt() ??
          (data['sparkCount'] as num?)?.toInt() ??
          0,
      echoCount:
          (data['echo_count'] as num?)?.toInt() ??
          (data['echoCount'] as num?)?.toInt() ??
          0,
      warpCount:
          (data['warp_count'] as num?)?.toInt() ??
          (data['warpCount'] as num?)?.toInt() ??
          0,
      createdAt: data['created_at'] != null
          ? DateTime.tryParse(data['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      locationGeohash: data['location_geohash'],
      originId: data['origin_id']?.toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'author_name': authorName,
      'author_avatar': authorAvatar,
      'author_planet_type': authorPlanetType,
      'content': content,
      'image_url': imageUrl,
      'video_url': videoUrl,
      'mood_emoji': moodEmoji,
      'mood_label': moodLabel,
      'location_name': locationName,
      'pulse_type': type,
      'is_nsfw': isNsfw,
      'author_is_high_risk': authorIsHighRisk,
      'spark_count': sparkCount,
      'echo_count': echoCount,
      'warp_count': warpCount,
      'created_at': createdAt.toIso8601String(),
      'location_geohash': locationGeohash,
      'origin_id': originId,
    };
  }
}
