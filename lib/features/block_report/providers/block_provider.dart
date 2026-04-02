import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xparq_app/core/errors/app_exception.dart';
import 'package:xparq_app/features/block_report/repositories/block_repository.dart';
import 'package:xparq_app/features/block_report/services/block_service.dart';

final blockRepositoryProvider = Provider<BlockRepository>((ref) {
  return BlockRepository();
});

final blockServiceProvider = Provider<BlockService>((ref) {
  return BlockService(ref.read(blockRepositoryProvider));
});

@immutable
class BlockState {
  final bool isLoading;
  final String? errorMessage;
  final String? successMessage;

  const BlockState({
    this.isLoading = false,
    this.errorMessage,
    this.successMessage,
  });

  BlockState copyWith({
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
    String? successMessage,
    bool clearSuccess = false,
  }) {
    return BlockState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      successMessage: clearSuccess
          ? null
          : (successMessage ?? this.successMessage),
    );
  }
}

class BlockProvider extends StateNotifier<BlockState> {
  BlockProvider({required BlockService service, required String currentUserId})
    : _service = service,
      _currentUserId = currentUserId,
      super(const BlockState());

  final BlockService _service;
  final String _currentUserId;

  Future<void> blockUser(String targetUserId) async {
    state = state.copyWith(
      isLoading: true,
      clearError: true,
      clearSuccess: true,
    );

    try {
      await _service.block(
        currentUserId: _currentUserId,
        targetUserId: targetUserId,
      );

      state = state.copyWith(
        isLoading: false,
        successMessage: 'Block action saved successfully.',
        clearError: true,
      );
    } on AppException catch (error) {
      state = state.copyWith(isLoading: false, errorMessage: error.message);
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Unable to block the user.',
      );
    }
  }

  void clearMessages() {
    state = state.copyWith(clearError: true, clearSuccess: true);
  }
}

final blockProvider = StateNotifierProvider.autoDispose
    .family<BlockProvider, BlockState, String>((ref, currentUserId) {
      return BlockProvider(
        service: ref.read(blockServiceProvider),
        currentUserId: currentUserId,
      );
    });
