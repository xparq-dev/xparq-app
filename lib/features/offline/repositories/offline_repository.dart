import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:xparq_app/core/errors/app_exception.dart';
import 'package:xparq_app/features/offline/models/offline_task_model.dart';

class OfflineRepository {
  OfflineRepository({SharedPreferences? preferences})
    : _preferences = preferences;

  static const String _queueStorageKey = 'offline.pending_tasks.queue';
  static const String _syncedStorageKey = 'offline.synced_tasks.history';

  SharedPreferences? _preferences;

  Future<SharedPreferences> _getPreferences() async {
    return _preferences ??= await SharedPreferences.getInstance();
  }

  Future<List<OfflineTask>> getQueuedTasks() async {
    try {
      final preferences = await _getPreferences();
      final rawEntries =
          preferences.getStringList(_queueStorageKey) ?? const <String>[];

      final tasks = <OfflineTask>[];
      var needsCleanup = false;

      for (final rawEntry in rawEntries) {
        try {
          final decoded = jsonDecode(rawEntry);
          if (decoded is! Map) {
            needsCleanup = true;
            continue;
          }

          tasks.add(OfflineTask.fromJson(Map<String, dynamic>.from(decoded)));
        } catch (_) {
          needsCleanup = true;
        }
      }

      if (needsCleanup) {
        await preferences.setStringList(
          _queueStorageKey,
          tasks.map((task) => jsonEncode(task.toJson())).toList(),
        );
      }

      return tasks;
    } catch (error) {
      throw AppException(
        'Failed to read queued offline actions.',
        cause: error,
      );
    }
  }

  Future<void> storeTask(OfflineTask task) async {
    try {
      final preferences = await _getPreferences();
      final tasks = await getQueuedTasks();

      final updatedTasks =
          tasks.where((existingTask) => existingTask.id != task.id).toList()
            ..add(task);

      await preferences.setStringList(
        _queueStorageKey,
        updatedTasks
            .map((queuedTask) => jsonEncode(queuedTask.toJson()))
            .toList(),
      );
    } catch (error) {
      throw AppException('Failed to store offline action.', cause: error);
    }
  }

  Future<void> removeTask(String taskId) async {
    try {
      final preferences = await _getPreferences();
      final tasks = await getQueuedTasks();
      final updatedTasks = tasks
          .where((task) => task.id != taskId)
          .toList(growable: false);

      await preferences.setStringList(
        _queueStorageKey,
        updatedTasks.map((task) => jsonEncode(task.toJson())).toList(),
      );
    } catch (error) {
      throw AppException(
        'Failed to remove synced offline action.',
        cause: error,
      );
    }
  }

  Future<void> dispatchTask(OfflineTask task) async {
    try {
      final preferences = await _getPreferences();
      final syncedEntries =
          preferences.getStringList(_syncedStorageKey) ?? <String>[];

      syncedEntries.add(
        jsonEncode(<String, dynamic>{
          'id': task.id,
          'payload': task.payload,
          'syncedAt': DateTime.now().toUtc().toIso8601String(),
        }),
      );

      await preferences.setStringList(_syncedStorageKey, syncedEntries);
    } catch (error) {
      throw AppException(
        'Failed to dispatch queued offline action.',
        cause: error,
      );
    }
  }
}
