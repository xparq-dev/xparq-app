import 'sync_item.dart';
import 'sync_status.dart';

class SyncQueue {
  final List<SyncItem> _items = [];

  List<SyncItem> get pending =>
      _items.where((e) => e.status == SyncStatus.pending).toList();

  void add(SyncItem item) {
    _items.add(item);
  }

  void markSuccess(String id) {
    final item = _items.firstWhere((e) => e.id == id);
    item.status = SyncStatus.success;
  }

  void markFailed(String id) {
    final item = _items.firstWhere((e) => e.id == id);
    item.status = SyncStatus.failed;
    item.retryCount++;
  }
}