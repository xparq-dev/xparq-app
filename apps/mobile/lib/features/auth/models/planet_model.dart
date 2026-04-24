// lib/features/auth/models/planet_model.dart

import '../../../shared/enums/age_group.dart';

class PlanetModel {
  final String id;
  final String xparqName;
  final String bio;
  final String photoUrl;
  final String coverPhotoUrl;
  final String? handle;
  final DateTime? handleUpdatedAt;
  final String? gender;
  final String? locationName;
  final String? occupation;
  final List<String> links;
  final String? extendedBio;
  final String birthDateEncrypted;
  final AgeGroup ageGroup;
  final bool blueOrbit;
  final bool isAdultVerified;
  final bool nsfwOptIn;
  final String? mbti;
  final String? enneagram;
  final String? zodiac;
  final String? bloodType;
  final String? locationGeohash;
  final DateTime? locationUpdatedAt;
  final List<String> constellations;
  final bool isOnline;
  final DateTime? lastSeen;
  final DateTime createdAt;
  final bool ghostMode;
  final String accountStatus;
  final int nsfwPulseCount;
  final int totalPulseCount;
  final DateTime? nextBanCheckInAt;
  final DateTime? deletionRequestedAt;
  final double coverPhotoYPercent;
  final double photoYPercent;
  final String photoAlignment;
  final bool isExpandedHeader;
  final String? contactEmail;
  final String? contactPhone;
  final bool isContactPublic;
  final String? backupCid;
  final DateTime? backupAt;
  final String? work;
  final String? education;
  final String? experience;
  final List<String> skills;

  const PlanetModel({
    required this.id,
    required this.xparqName,
    required this.bio,
    this.mbti,
    this.enneagram,
    this.zodiac,
    this.bloodType,
    required this.photoUrl,
    required this.coverPhotoUrl,
    this.handle,
    this.handleUpdatedAt,
    this.gender,
    this.locationName,
    this.occupation,
    this.links = const [],
    this.extendedBio,
    required this.birthDateEncrypted,
    required this.ageGroup,
    required this.blueOrbit,
    required this.isAdultVerified,
    required this.nsfwOptIn,
    this.locationGeohash,
    this.locationUpdatedAt,
    required this.constellations,
    required this.isOnline,
    this.lastSeen,
    required this.createdAt,
    required this.ghostMode,
    required this.accountStatus,
    this.nsfwPulseCount = 0,
    this.totalPulseCount = 0,
    this.nextBanCheckInAt,
    this.deletionRequestedAt,
    this.coverPhotoYPercent = 0.5,
    this.photoYPercent = 0.5,
    this.photoAlignment = 'center',
    this.isExpandedHeader = false,
    this.contactEmail,
    this.contactPhone,
    this.isContactPublic = false,
    this.backupCid,
    this.backupAt,
    this.work,
    this.education,
    this.experience,
    this.skills = const [],
  });

  // ── Derived helpers ──────────────────────────────────────────────────────
  bool get isCadet => ageGroup == AgeGroup.cadet;
  bool get isExplorer => ageGroup == AgeGroup.explorer;
  bool get canViewSensitive => isExplorer && nsfwOptIn;
  double get nsfwPercentage =>
      totalPulseCount > 0 ? nsfwPulseCount / totalPulseCount : 0.0;
  bool get isHighRiskCreator => nsfwPercentage > 0.7;
  bool get isPendingDeletion => deletionRequestedAt != null;

  bool get isActuallyOnline {
    if (!isOnline || lastSeen == null) return false;
    final diff = DateTime.now().toUtc().difference(lastSeen!);
    return diff.inMinutes < 5;
  }

  factory PlanetModel.placeholder(String id) {
    return PlanetModel(
      id: id,
      xparqName: 'Explorer',
      bio: 'Searching the galaxy...',
      photoUrl: '',
      coverPhotoUrl: '',
      birthDateEncrypted: '',
      ageGroup: AgeGroup.explorer,
      blueOrbit: false,
      isAdultVerified: false,
      nsfwOptIn: false,
      constellations: [],
      isOnline: false,
      createdAt: DateTime.now(),
      ghostMode: false,
      accountStatus: 'unknown',
    );
  }

  factory PlanetModel.fromMap(Map<String, dynamic> data, String id) {
    return PlanetModel(
      id: id,
      xparqName:
          data['xparq_name']?.toString() ??
          data['sparq_name']?.toString() ??
          '',
      bio: data['bio']?.toString() ?? '',
      mbti: data['mbti']?.toString(),
      enneagram: data['enneagram']?.toString(),
      zodiac: data['zodiac']?.toString(),
      bloodType: data['blood_type']?.toString(),
      photoUrl: data['photo_url']?.toString() ?? '',
      coverPhotoUrl: data['cover_photo_url']?.toString() ?? '',
      handle: data['handle']?.toString(),
      handleUpdatedAt: data['handle_updated_at'] != null
          ? DateTime.tryParse(data['handle_updated_at'].toString())
          : null,
      gender: data['gender']?.toString(),
      locationName: data['location_name']?.toString(),
      occupation: data['occupation']?.toString(),
      links: List<String>.from(data['links'] as List? ?? []),
      extendedBio: data['extended_bio']?.toString(),
      birthDateEncrypted: data['birth_date_encrypted']?.toString() ?? '',
      ageGroup: _parseAgeGroup(data['age_group'] as String?),
      blueOrbit: data['blue_orbit'] as bool? ?? false,
      isAdultVerified: data['is_adult_verified'] as bool? ?? false,
      nsfwOptIn: data['nsfw_opt_in'] as bool? ?? false,
      locationGeohash: data['location_geohash'] as String?,
      locationUpdatedAt: data['location_updated_at'] != null
          ? DateTime.tryParse(data['location_updated_at'] as String)
          : null,
      constellations: List<String>.from(data['constellations'] as List? ?? []),
      isOnline: data['is_online'] as bool? ?? false,
      lastSeen: data['last_seen'] != null
          ? DateTime.tryParse(data['last_seen'] as String)
          : null,
      createdAt: data['created_at'] != null
          ? DateTime.tryParse(data['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
      ghostMode: data['ghost_mode'] as bool? ?? false,
      accountStatus: data['account_status'] as String? ?? 'active',
      nsfwPulseCount: data['nsfw_pulse_count'] as int? ?? 0,
      totalPulseCount: data['total_pulse_count'] as int? ?? 0,
      nextBanCheckInAt: data['next_ban_check_in_at'] != null
          ? DateTime.tryParse(data['next_ban_check_in_at'] as String)
          : null,
      deletionRequestedAt: data['deletion_requested_at'] != null
          ? DateTime.tryParse(data['deletion_requested_at'] as String)
          : null,
      coverPhotoYPercent:
          (data['cover_photo_y_percent'] as num?)?.toDouble() ?? 0.5,
      photoYPercent: (data['photo_y_percent'] as num?)?.toDouble() ?? 0.5,
      photoAlignment: data['photo_alignment'] as String? ?? 'center',
      isExpandedHeader: data['is_expanded_header'] as bool? ?? false,
      contactPhone: data['contact_phone'] as String?,
      isContactPublic: data['is_contact_public'] as bool? ?? false,
      work: data['work'] as String?,
      education: data['education'] as String?,
      experience: data['experience'] as String?,
      skills: List<String>.from(data['skills'] as List? ?? []),
      backupCid: data['backup_cid'] as String?,
      backupAt: data['backup_at'] != null
          ? DateTime.tryParse(data['backup_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'xparq_name': xparqName,
      'bio': bio,
      'mbti': mbti,
      'enneagram': enneagram,
      'zodiac': zodiac,
      'blood_type': bloodType,
      'photo_url': photoUrl,
      'cover_photo_url': coverPhotoUrl,
      'handle': handle,
      'handle_updated_at': handleUpdatedAt?.toIso8601String(),
      'gender': gender,
      'location_name': locationName,
      'occupation': occupation,
      'links': links,
      'extended_bio': extendedBio,
      'birth_date_encrypted': birthDateEncrypted,
      'age_group': ageGroup.name,
      'blue_orbit': blueOrbit,
      'is_adult_verified': isAdultVerified,
      'nsfw_opt_in': nsfwOptIn,
      'location_geohash': locationGeohash,
      'location_updated_at': locationUpdatedAt?.toIso8601String(),
      'constellations': constellations,
      'is_online': isOnline,
      'last_seen': lastSeen?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'ghost_mode': ghostMode,
      'account_status': accountStatus,
      'nsfw_pulse_count': nsfwPulseCount,
      'total_pulse_count': totalPulseCount,
      'next_ban_check_in_at': nextBanCheckInAt?.toIso8601String(),
      'deletion_requested_at': deletionRequestedAt?.toIso8601String(),
      'cover_photo_y_percent': coverPhotoYPercent,
      'photo_y_percent': photoYPercent,
      'photo_alignment': photoAlignment,
      'is_expanded_header': isExpandedHeader,
      'contact_phone': contactPhone,
      'is_contact_public': isContactPublic,
      'work': work,
      'education': education,
      'experience': experience,
      'skills': skills,
      'backup_cid': backupCid,
      'backup_at': backupAt?.toIso8601String(),
    };
  }

  static AgeGroup _parseAgeGroup(String? value) {
    if (value == 'cadet') return AgeGroup.cadet;
    return AgeGroup.explorer;
  }

  PlanetModel copyWith({
    String? xparqName,
    String? bio,
    String? photoUrl,
    String? coverPhotoUrl,
    String? handle,
    DateTime? handleUpdatedAt,
    String? gender,
    String? locationName,
    String? occupation,
    List<String>? links,
    String? extendedBio,
    bool? blueOrbit,
    bool? nsfwOptIn,
    String? mbti,
    String? enneagram,
    String? zodiac,
    String? bloodType,
    String? locationGeohash,
    DateTime? locationUpdatedAt,
    List<String>? constellations,
    bool? isOnline,
    DateTime? lastSeen,
    bool? ghostMode,
    String? accountStatus,
    double? coverPhotoYPercent,
    double? photoYPercent,
    String? photoAlignment,
    bool? isExpandedHeader,
    String? contactEmail,
    String? contactPhone,
    bool? isContactPublic,
    String? work,
    String? education,
    String? experience,
    List<String>? skills,
  }) {
    return PlanetModel(
      id: id,
      xparqName: xparqName ?? this.xparqName,
      bio: bio ?? this.bio,
      photoUrl: photoUrl ?? this.photoUrl,
      coverPhotoUrl: coverPhotoUrl ?? this.coverPhotoUrl,
      handle: handle ?? this.handle,
      handleUpdatedAt: handleUpdatedAt ?? this.handleUpdatedAt,
      gender: gender ?? this.gender,
      locationName: locationName ?? this.locationName,
      occupation: occupation ?? this.occupation,
      links: links ?? this.links,
      extendedBio: extendedBio ?? this.extendedBio,
      birthDateEncrypted: birthDateEncrypted,
      ageGroup: ageGroup,
      blueOrbit: blueOrbit ?? this.blueOrbit,
      isAdultVerified: isAdultVerified,
      nsfwOptIn: nsfwOptIn ?? this.nsfwOptIn,
      mbti: mbti ?? this.mbti,
      enneagram: enneagram ?? this.enneagram,
      zodiac: zodiac ?? this.zodiac,
      bloodType: bloodType ?? this.bloodType,
      locationGeohash: locationGeohash ?? this.locationGeohash,
      locationUpdatedAt: locationUpdatedAt ?? this.locationUpdatedAt,
      constellations: constellations ?? this.constellations,
      isOnline: isOnline ?? this.isOnline,
      lastSeen: lastSeen ?? this.lastSeen,
      createdAt: createdAt,
      ghostMode: ghostMode ?? this.ghostMode,
      accountStatus: accountStatus ?? this.accountStatus,
      coverPhotoYPercent: coverPhotoYPercent ?? this.coverPhotoYPercent,
      photoYPercent: photoYPercent ?? this.photoYPercent,
      photoAlignment: photoAlignment ?? this.photoAlignment,
      isExpandedHeader: isExpandedHeader ?? this.isExpandedHeader,
      contactEmail: contactEmail ?? this.contactEmail,
      contactPhone: contactPhone ?? this.contactPhone,
      isContactPublic: isContactPublic ?? this.isContactPublic,
      work: work ?? this.work,
      education: education ?? this.education,
      experience: experience ?? this.experience,
      skills: skills ?? this.skills,
    );
  }
}
