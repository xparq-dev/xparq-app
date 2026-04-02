import 'dart:async';
import 'package:uuid/uuid.dart';

class SyncManager {
  static final SyncManager instance = SyncManager._();
  SyncManager._();

  final _queue = SyncQueue();

  bool _isOnline = true;
  bool _isSyncing = false;

  /// 🔥 เพิ่ม event เข้า queue
  void addEvent({
    required String type,
    required Map<String, dynamic> payload,
  }) {
    final item = SyncItem(
      id: const Uuid().v4(),
      type: type,
      payload: payload,
      createdAt: DateTime.now(),
    );

    _queue.add(item);

    if (_isOnline) {
      _processQueue();
    }
  }

  /// 🔥 ตั้งค่า online/offline
  void setOnline(bool value) {
    _isOnline = value;

    if (_isOnline) {
      _processQueue();
    }
  }

  /// 🔥 sync queue
  Future<void> _processQueue() async {
    if (_isSyncing) return;

    _isSyncing = true;

    for (final item in _queue.pending) {
      try {
        await _sendToServer(item);
        _queue.markSuccess(item.id);
      } catch (_) {
        _queue.markFailed(item.id);
      }
    }

    _isSyncing = false;
  }

  /// 🔥 mock server call (คุณจะเปลี่ยนเป็น repository)
  Future<void> _sendToServer(SyncItem item) async {
    await Future.delayed(const Duration(milliseconds: 300));

    // TODO: call API จริง
  }
}