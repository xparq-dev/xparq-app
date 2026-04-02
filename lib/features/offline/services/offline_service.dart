import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:xparq_app/core/errors/app_exception.dart';
import 'package:xparq_app/features/offline/models/offline_task_model.dart';
import 'package:xparq_app/features/offline/repositories/offline_repository.dart';

class OfflineService {
  OfflineService(this._repository, {Connectivity? connectivity})
    : _connectivity = connectivity ?? Connectivity();

  final OfflineRepository _repository;
  final Connectivity _connectivity;

  Future<List<OfflineTask>> getQueuedTasks() async {
    try {
      return await _repository.getQueuedTasks();
    } on AppException {
      rethrow;
    } catch (error) {
      throw AppException(
        'Unable to load queued offline actions.',
        cause: error,
      );
    }
  }

  Future<OfflineTask> storeAction(String payloadText) async {
    final trimmedPayload = payloadText.trim();
    if (trimmedPayload.isEmpty) {
      throw const ValidationException('Payload is required.', field: 'payload');
    }

    try {
      final decoded = jsonDecode(trimmedPayload);
      if (decoded is! Map) {
        throw const ValidationException(
          'Payload must be a JSON object.',
          field: 'payload',
        );
      }

      final task = OfflineTask(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        payload: Map<String, dynamic>.from(decoded),
      );

      await _repository.storeTask(task);
      return task;
    } on FormatException catch (error) {
      throw ValidationException(
        'Payload must be valid JSON.',
        field: 'payload',
        cause: error,
      );
    } on AppException {
      rethrow;
    } catch (error) {
      throw AppException('Unable to queue offline action.', cause: error);
    }
  }

  Future<bool> isOnline() async {
    try {
      final results = await _connectivity.checkConnectivity();
      return _hasConnection(results);
    } catch (error) {
      throw NetworkException(
        'Unable to determine current connectivity status.',
        cause: error,
      );
    }
  }

  Stream<bool> watchConnection() async* {
    await for (final results in _connectivity.onConnectivityChanged) {
      yield _hasConnection(results);
    }
  }

  Future<int> sync() async {
    final online = await isOnline();
    if (!online) {
      throw const NetworkException(
        'No internet connection. Your queued actions will retry automatically when online.',
      );
    }

    try {
      final queuedTasks = await _repository.getQueuedTasks();
      var syncedCount = 0;

      for (final task in queuedTasks) {
        await _repository.dispatchTask(task);
        await _repository.removeTask(task.id);
        syncedCount++;
      }

      return syncedCount;
    } on AppException {
      rethrow;
    } catch (error) {
      throw AppException('Unable to sync offline actions.', cause: error);
    }
  }

  bool _hasConnection(List<ConnectivityResult> results) {
    return results.any(
      (result) =>
          result == ConnectivityResult.mobile ||
          result == ConnectivityResult.wifi ||
          result == ConnectivityResult.ethernet ||
          result == ConnectivityResult.vpn ||
          result == ConnectivityResult.other,
    );
  }
}
