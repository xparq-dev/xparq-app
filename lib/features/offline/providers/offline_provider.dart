import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xparq_app/shared/errors/app_exception.dart';
import 'package:xparq_app/features/offline/models/offline_task_model.dart';
import 'package:xparq_app/features/offline/repositories/offline_repository.dart';
import 'package:xparq_app/features/offline/services/offline_service.dart';

final offlineRepositoryProvider = Provider<OfflineRepository>((ref) {
  return OfflineRepository();
});

final offlineServiceProvider = Provider<OfflineService>((ref) {
  return OfflineService(ref.read(offlineRepositoryProvider));
});

@immutable
class OfflineState {
  final List<OfflineTask> queuedTasks;
  final bool isOnline;
  final bool isChecking;
  final bool isSyncing;
  final bool isStoring;
  final String? errorMessage;
  final String? successMessage;

  const OfflineState({
    this.queuedTasks = const <OfflineTask>[],
    this.isOnline = false,
    this.isChecking = false,
    this.isSyncing = false,
    this.isStoring = false,
    this.errorMessage,
    this.successMessage,
  });

  OfflineState copyWith({
    List<OfflineTask>? queuedTasks,
    bool? isOnline,
    bool? isChecking,
    bool? isSyncing,
    bool? isStoring,
    String? errorMessage,
    bool clearError = false,
    String? successMessage,
    bool clearSuccess = false,
  }) {
    return OfflineState(
      queuedTasks: queuedTasks ?? this.queuedTasks,
      isOnline: isOnline ?? this.isOnline,
      isChecking: isChecking ?? this.isChecking,
      isSyncing: isSyncing ?? this.isSyncing,
      isStoring: isStoring ?? this.isStoring,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      successMessage: clearSuccess
          ? null
          : (successMessage ?? this.successMessage),
    );
  }
}

class OfflineProvider extends StateNotifier<OfflineState> {
  OfflineProvider(this._service) : super(const OfflineState());

  final OfflineService _service;
  StreamSubscription<bool>? _connectivitySubscription;

  void startMonitoring() {
    _connectivitySubscription ??= _service.watchConnection().listen((isOnline) {
      state = state.copyWith(isOnline: isOnline);

      if (isOnline) {
        unawaited(check(triggeredByConnectivity: true));
      }
    });
  }

  Future<void> check({bool triggeredByConnectivity = false}) async {
    state = state.copyWith(
      isChecking: !triggeredByConnectivity,
      clearError: true,
      clearSuccess: true,
    );

    try {
      final online = await _service.isOnline();
      final queuedTasks = await _service.getQueuedTasks();

      if (!online) {
        state = state.copyWith(
          queuedTasks: queuedTasks,
          isOnline: false,
          isChecking: false,
          isSyncing: false,
          successMessage: queuedTasks.isEmpty
              ? 'You are offline. No queued actions yet.'
              : '${queuedTasks.length} queued action(s) will retry when online.',
          clearError: true,
        );
        return;
      }

      state = state.copyWith(
        queuedTasks: queuedTasks,
        isOnline: true,
        isChecking: false,
        isSyncing: true,
      );

      final syncedCount = await _service.sync();
      final remainingTasks = await _service.getQueuedTasks();

      state = state.copyWith(
        queuedTasks: remainingTasks,
        isOnline: true,
        isChecking: false,
        isSyncing: false,
        successMessage: syncedCount == 0
            ? 'Connection is online. No queued actions to sync.'
            : 'Synced $syncedCount queued action${syncedCount == 1 ? '' : 's'}.',
        clearError: true,
      );
    } on AppException catch (error) {
      state = state.copyWith(
        queuedTasks: await _safeLoadQueue(),
        isChecking: false,
        isSyncing: false,
        errorMessage: error.message,
      );
    } catch (_) {
      state = state.copyWith(
        queuedTasks: await _safeLoadQueue(),
        isChecking: false,
        isSyncing: false,
        errorMessage: 'Unable to check offline queue status.',
      );
    }
  }

  Future<void> storeAction({required String payloadText}) async {
    state = state.copyWith(
      isStoring: true,
      clearError: true,
      clearSuccess: true,
    );

    try {
      await _service.storeAction(payloadText);
      final queuedTasks = await _service.getQueuedTasks();

      state = state.copyWith(
        queuedTasks: queuedTasks,
        isStoring: false,
        successMessage: 'Action stored in the offline queue.',
        clearError: true,
      );

      if (state.isOnline) {
        await check();
      }
    } on AppException catch (error) {
      state = state.copyWith(
        queuedTasks: await _safeLoadQueue(),
        isStoring: false,
        errorMessage: error.message,
      );
    } catch (_) {
      state = state.copyWith(
        queuedTasks: await _safeLoadQueue(),
        isStoring: false,
        errorMessage: 'Unable to store the offline action.',
      );
    }
  }

  void clearMessages() {
    state = state.copyWith(clearError: true, clearSuccess: true);
  }

  Future<List<OfflineTask>> _safeLoadQueue() async {
    try {
      return await _service.getQueuedTasks();
    } catch (_) {
      return state.queuedTasks;
    }
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    super.dispose();
  }
}

final offlineProvider =
    StateNotifierProvider.autoDispose<OfflineProvider, OfflineState>((ref) {
      return OfflineProvider(ref.read(offlineServiceProvider));
    });
