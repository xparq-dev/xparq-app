import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class BluetoothPermissionManager {
  static Future<Map<Permission, PermissionStatus>>
      getOfflinePermissionStatuses() async {
    final statuses = <Permission, PermissionStatus>{
      Permission.location: await Permission.location.status,
      Permission.bluetoothScan: await Permission.bluetoothScan.status,
      Permission.bluetoothAdvertise: await Permission.bluetoothAdvertise.status,
      Permission.bluetoothConnect: await Permission.bluetoothConnect.status,
      Permission.nearbyWifiDevices: await Permission.nearbyWifiDevices.status,
    };

    if (Platform.isIOS) {
      statuses[Permission.bluetooth] = await Permission.bluetooth.status;
    }

    return statuses;
  }

  static bool areOfflinePermissionsGranted(
    Map<Permission, PermissionStatus> statuses,
  ) {
    bool allGranted = true;

    if (statuses[Permission.location] != PermissionStatus.granted) {
      allGranted = false;
    }

    if (Platform.isAndroid) {
      final hasLegacyEntry = statuses.containsKey(Permission.bluetooth);
      final bool hasNewPermissions = statuses[Permission.bluetoothScan] ==
              PermissionStatus.granted &&
          statuses[Permission.bluetoothAdvertise] == PermissionStatus.granted &&
          statuses[Permission.bluetoothConnect] == PermissionStatus.granted;

      final bool hasLegacyPermission = hasLegacyEntry &&
          statuses[Permission.bluetooth] == PermissionStatus.granted;

      if (!hasNewPermissions && !hasLegacyPermission) {
        allGranted = false;
      }

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

  static Future<bool> requestOfflinePermissions(BuildContext context) async {
    final permissions = <Permission>[
      Permission.location,
      Permission.bluetoothScan,
      Permission.bluetoothAdvertise,
      Permission.bluetoothConnect,
      Permission.nearbyWifiDevices,
    ];

    if (Platform.isIOS) {
      permissions.insert(1, Permission.bluetooth);
    }

    final statuses = await permissions.request();
    return areOfflinePermissionsGranted(statuses);
  }
}
