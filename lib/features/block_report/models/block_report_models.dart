enum ReportReason {
  spam,
  harassment,
  nsfw, // Sharing inappropriate/adult content to underage
  ageMismatch, // Claiming wrong age
  hateSpeech,
  impersonation,
  other,
}

extension ReportReasonX on ReportReason {
  String get displayName => switch (this) {
    ReportReason.spam => '📢 Spam',
    ReportReason.harassment => '😡 Harassment',
    ReportReason.nsfw => '🔞 Inappropriate Content',
    ReportReason.ageMismatch => '🛡️ Age Misrepresentation',
    ReportReason.hateSpeech => '💢 Hate Speech',
    ReportReason.impersonation => '🎭 Impersonation',
    ReportReason.other => '❓ Other',
  };

  String get name => toString().split('.').last;
}

class BlockModel {
  final String blockedUid;
  final DateTime blockedAt;
  final String source; // "online" | "offline"

  const BlockModel({
    required this.blockedUid,
    required this.blockedAt,
    this.source = 'online',
  });

  factory BlockModel.fromMap(Map<String, dynamic> data) {
    return BlockModel(
      blockedUid: data['blocked_id'] as String,
      blockedAt: data['created_at'] != null
          ? DateTime.parse(data['created_at'])
          : DateTime.now(),
      source: data['source'] as String? ?? 'online',
    );
  }

  Map<String, dynamic> toMap() => {
    'blocked_id': blockedUid,
    'created_at': blockedAt.toIso8601String(),
    'source': source,
  };
}

class ReportModel {
  final String reporterId;
  final String reportedId;
  final String? chatId;
  final ReportReason reason;
  final String? detail;
  final DateTime createdAt;
  final String status;
  final String context; // "chat" | "profile" | "radar"

  const ReportModel({
    required this.reporterId,
    required this.reportedId,
    this.chatId,
    required this.reason,
    this.detail,
    required this.createdAt,
    this.status = 'pending',
    this.context = 'chat',
  });

  Map<String, dynamic> toMap() => {
    'reporter_id': reporterId,
    'reported_id': reportedId,
    'chat_id': chatId,
    'reason': reason.name,
    'detail': detail,
    'created_at': createdAt.toIso8601String(),
    'status': status,
    'context': context,
  };

  factory ReportModel.fromMap(Map<String, dynamic> data) {
    return ReportModel(
      reporterId: data['reporter_id'] as String,
      reportedId: data['reported_id'] as String,
      chatId: data['chat_id'] as String?,
      reason: ReportReason.values.firstWhere(
        (e) => e.name == data['reason'],
        orElse: () => ReportReason.other,
      ),
      detail: data['detail'] as String?,
      createdAt: data['created_at'] != null
          ? DateTime.parse(data['created_at'])
          : DateTime.now(),
      status: data['status'] as String? ?? 'pending',
      context: data['context'] as String? ?? 'chat',
    );
  }
}
