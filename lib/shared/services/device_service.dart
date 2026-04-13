// lib/core/services/device_service.dart

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

class DeviceService {
  static final DeviceService instance = DeviceService._();
  DeviceService._();

  static const _storage = FlutterSecureStorage();
  static const _deviceIdKey = 'iXPARQ_device_id';

  String? _cachedDeviceId;

  /// Gets the unique ID for this device installation.
  /// If it doesn't exist, it generates a new one.
  Future<String> getDeviceId() async {
    if (_cachedDeviceId != null) return _cachedDeviceId!;

    String? id = await _storage.read(key: _deviceIdKey);
    if (id == null) {
      id = const Uuid().v4();
      await _storage.write(key: _deviceIdKey, value: id);
    }

    _cachedDeviceId = id;
    return id;
  }

  /// Clears the device ID cache and storage. Used during fresh install detection
  /// on iOS to prevent KeyChain persistence bugs.
  Future<void> clearCache() async {
    _cachedDeviceId = null;
    await _storage.delete(key: _deviceIdKey);
  }
}
