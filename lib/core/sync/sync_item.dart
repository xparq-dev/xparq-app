class SyncItem {
  final String id;
  final String type;
  final Map<String, dynamic> payload;
  final DateTime createdAt;
  SyncStatus status;
  int retryCount;

  SyncItem({
    required this.id,
    required this.type,
    required this.payload,
    required this.createdAt,
    this.status = SyncStatus.pending,
    this.retryCount = 0,
  });
}