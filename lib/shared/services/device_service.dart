import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

class DeviceService {
  static final DeviceService instance = DeviceService._();
  DeviceService._();

  static const _storage = FlutterSecureStorage();
  static const _deviceIdKey = 'iXPARQ_device_id';

  String? _cachedDeviceId;

  // 🔥 ป้องกัน race condition
  Completer<String>? _completer;

  /// Gets the unique ID for this device installation.
  /// Safe version: no crash, no duplicate generation
  Future<String> getDeviceId() async {
    // 🔹 cache ก่อน
    if (_cachedDeviceId != null) return _cachedDeviceId!;

    // 🔹 ถ้ามี request ซ้อน → รอของเดิม
    if (_completer != null) {
      return _completer!.future;
    }

    _completer = Completer<String>();

    try {
      String? id;

      try {
        id = await _storage.read(key: _deviceIdKey);
      } catch (e) {
        debugPrint('DeviceService: read error → $e');
      }

      if (id == null || id.isEmpty) {
        id = const Uuid().v4();

        try {
          await _storage.write(key: _deviceIdKey, value: id);
        } catch (e) {
          debugPrint('DeviceService: write error → $e');
        }
      }

      _cachedDeviceId = id;

      _completer!.complete(id);
      return id;
    } catch (e) {
      debugPrint('DeviceService: fatal error → $e');

      // 🔥 fallback (ไม่ให้พัง)
      final fallback = const Uuid().v4();
      _cachedDeviceId = fallback;

      _completer!.complete(fallback);
      return fallback;
    } finally {
      _completer = null;
    }
  }

  /// Clears the device ID cache and storage.
  Future<void> clearCache() async {
    _cachedDeviceId = null;

    try {
      await _storage.delete(key: _deviceIdKey);
    } catch (e) {
      debugPrint('DeviceService: delete error → $e');
    }
  }
}