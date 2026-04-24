// lib/features/auth/models/quick_account.dart

class QuickAccount {
  final String uid;
  final String email;
  final String xparqName;
  final String photoUrl;
  final DateTime lastUsed;
  final bool isEnabled;

  QuickAccount({
    required this.uid,
    required this.email,
    required this.xparqName,
    required this.photoUrl,
    required this.lastUsed,
    this.isEnabled = true,
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'xparq_name': xparqName,
      'photo_url': photoUrl,
      'last_used': lastUsed.toIso8601String(),
      'is_enabled': isEnabled,
    };
  }

  factory QuickAccount.fromMap(Map<String, dynamic> map) {
    return QuickAccount(
      uid: map['uid'] as String,
      email: map['email'] as String? ?? '',
      xparqName: map['xparq_name'] as String,
      photoUrl: map['photo_url'] as String,
      lastUsed: DateTime.parse(map['last_used'] as String),
      isEnabled: map['is_enabled'] as bool? ?? map['has_pin'] as bool? ?? false,
    );
  }

  QuickAccount copyWith({
    String? email,
    String? xparqName,
    String? photoUrl,
    DateTime? lastUsed,
    bool? isEnabled,
  }) {
    return QuickAccount(
      uid: uid,
      email: email ?? this.email,
      xparqName: xparqName ?? this.xparqName,
      photoUrl: photoUrl ?? this.photoUrl,
      lastUsed: lastUsed ?? this.lastUsed,
      isEnabled: isEnabled ?? this.isEnabled,
    );
  }
}
