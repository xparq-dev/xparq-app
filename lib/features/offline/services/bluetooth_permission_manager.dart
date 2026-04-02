import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class BluetoothPermissionManager {
  static Future<bool> requestOfflinePermissions(BuildContext context) async {
    // We need Location and Bluetooth
    Map<Permission, PermissionStatus> statuses = await [
      Permission.location,
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothAdvertise,
      Permission.bluetoothConnect,
      Permission.nearbyWifiDevices,
    ].request();

    bool allGranted = true;

    // Check if location is granted
    if (statuses[Permission.location] != PermissionStatus.granted) {
      allGranted = false;
    }

    if (Platform.isAndroid) {
      // Check Android 12+ specific permissions
      final bool hasNewPermissions =
          statuses[Permission.bluetoothScan] == PermissionStatus.granted &&
          statuses[Permission.bluetoothAdvertise] == PermissionStatus.granted &&
          statuses[Permission.bluetoothConnect] == PermissionStatus.granted;

      final bool hasLegacyPermission =
          statuses[Permission.bluetooth] == PermissionStatus.granted;

      // On Android 12+ (API 31+), we MUST have the new permissions.
      // On older versions, the new permissions are ignored and we need the legacy one.
      // However, permission_handler handles version checks, so if they are returned as 'denied' or 'permanentlyDenied', it means they were relevant and rejected.

      // A safe way is to ensure that if we are on Android, we at least have location AND (new permissions OR legacy permission)
      // but to be strict for BLE mesh, we really want the new ones if available.
      if (!hasNewPermissions && !hasLegacyPermission) {
        allGranted = false;
      }

      // To be even safer, if ANY of the new ones were explicitly denied when requested:
      if (statuses[Permission.bluetoothScan]?.isDenied ?? false) {
        allGranted = false;
      }
      if (statuses[Permission.bluetoothAdvertise]?.isDenied ?? false) {
        allGranted = false;
      }
      if (statuses[Permission.bluetoothConnect]?.isDenied ?? false) {
        allGranted = false;
      }
      if (statuses[Permission.nearbyWifiDevices]?.isDenied ?? false) {
        allGranted = false;
      }
    } else if (Platform.isIOS) {
      if (statuses[Permission.bluetooth] != PermissionStatus.granted) {
        allGranted = false;
      }
    }

    return allGranted;
  }
}
