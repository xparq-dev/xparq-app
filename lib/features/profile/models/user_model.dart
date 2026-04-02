import 'package:flutter/foundation.dart';

@immutable
class UserModel {
  final String id;
  final String name;
  final String bio;

  const UserModel({required this.id, required this.name, required this.bio});

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? json['xparq_name']?.toString() ?? '',
      bio: json['bio']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'name': name, 'bio': bio};
  }

  UserModel copyWith({String? id, String? name, String? bio}) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      bio: bio ?? this.bio,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    return other is UserModel &&
        other.id == id &&
        other.name == name &&
        other.bio == bio;
  }

  @override
  int get hashCode => Object.hash(id, name, bio);
}
