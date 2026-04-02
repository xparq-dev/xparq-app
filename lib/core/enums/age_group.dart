// lib/core/enums/age_group.dart

enum AgeGroup {
  blocked, // < 13 — registration not allowed
  cadet, // 13–17 — restricted mode
  explorer, // 18+ — full access
}

extension AgeGroupExtension on AgeGroup {
  String get displayName {
    switch (this) {
      case AgeGroup.blocked:
        return 'Blocked';
      case AgeGroup.cadet:
        return 'Cadet';
      case AgeGroup.explorer:
        return 'Explorer';
    }
  }

  bool get canViewSensitive => this == AgeGroup.explorer;
  bool get isRestricted => this == AgeGroup.cadet;
}
