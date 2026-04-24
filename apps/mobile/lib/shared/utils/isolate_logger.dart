// ignore_for_file: avoid_print
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class IsolateLogger {
  static String? _manualPath;

  /// Sets a manual path for the log file. Useful for passing the path from the main isolate
  /// to others if needed, though isolates don't share static memory.
  static void setPath(String path) => _manualPath = path;

  static Future<void> log(String message) async {
    final timestamp = DateTime.now().toIso8601String();
    final logLine = '[$timestamp] $message\n';
    
    // Always print to console using standard print() which is more reliable in isolates
    print(logLine);

    try {
      String? path = _manualPath;
      if (path == null) {
        try {
          path = (await getApplicationDocumentsDirectory()).path;
        } catch (e) {
          // Fallback for Android background isolates
          path = '/data/user/0/com.xparq.xparq_app/app_flutter';
        }
      }
      
      final file = File('$path/debug_bg.log');
      await file.writeAsString(logLine, mode: FileMode.append, flush: true);
    } catch (e) {
      // If even fallback fails, just rely on print()
      print('IsolateLogger failed to write: $e');
    }
  }

  static Future<String> readLogs() async {
    try {
      String? path;
      try {
        path = (await getApplicationDocumentsDirectory()).path;
      } catch (_) {
        path = '/data/user/0/com.xparq.xparq_app/app_flutter';
      }
      
      final file = File('$path/debug_bg.log');
      if (await file.exists()) {
        return await file.readAsString();
      }
    } catch (e) {
      return 'Error reading logs: $e';
    }
    return 'No logs found.';
  }

  static Future<void> clearLogs() async {
    try {
      String? path;
      try {
        path = (await getApplicationDocumentsDirectory()).path;
      } catch (_) {
        path = '/data/user/0/com.xparq.xparq_app/app_flutter';
      }
      final file = File('$path/debug_bg.log');
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      print('Error clearing logs: $e');
    }
  }
}
