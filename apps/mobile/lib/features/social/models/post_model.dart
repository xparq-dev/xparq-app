import 'package:flutter/foundation.dart';

@immutable
class Post {
  final String id;
  final String content;
  final String userId;

  const Post({required this.id, required this.content, required this.userId});

  factory Post.fromJson(Map<String, dynamic> json) {
    return Post(
      id: json['id']?.toString() ?? '',
      content: json['content']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? json['uid']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'content': content, 'user_id': userId};
  }

  Post copyWith({String? id, String? content, String? userId}) {
    return Post(
      id: id ?? this.id,
      content: content ?? this.content,
      userId: userId ?? this.userId,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    return other is Post &&
        other.id == id &&
        other.content == content &&
        other.userId == userId;
  }

  @override
  int get hashCode => Object.hash(id, content, userId);
}
