import 'package:flutter/foundation.dart';

@immutable
class UserModel {
  final String id;
  final String email;
  final String token;

  const UserModel({required this.id, required this.email, required this.token});

  factory UserModel.fromJson(Map<String, dynamic> json) {
    final dynamic userData = json['user'];
    final Map<String, dynamic> payload = userData is Map<String, dynamic>
        ? userData
        : userData is Map
        ? Map<String, dynamic>.from(userData)
        : json;

    final id = payload['id']?.toString() ?? '';
    final email = payload['email']?.toString() ?? '';
    final token =
        json['token']?.toString() ??
        json['access_token']?.toString() ??
        json['accessToken']?.toString() ??
        payload['token']?.toString() ??
        '';

    if (id.isEmpty || email.isEmpty || token.isEmpty) {
      throw const FormatException('Invalid user payload.');
    }

    return UserModel(id: id, email: email, token: token);
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'email': email, 'token': token};
  }

  UserModel copyWith({String? id, String? email, String? token}) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      token: token ?? this.token,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    return other is UserModel &&
        other.id == id &&
        other.email == email &&
        other.token == token;
  }

  @override
  int get hashCode => Object.hash(id, email, token);
}
